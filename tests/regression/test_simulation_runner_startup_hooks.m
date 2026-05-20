function test_simulation_runner_startup_hooks()
    %TEST_SIMULATION_RUNNER_STARTUP_HOOKS Phase 0 regression test for the
    %three startup hooks newly wired into SimulationRunner.setupImpl
    %(audit §17.2 / phase-0-baseline.md §6).
    %
    %   Hook coverage:
    %     1. validateRequiredToolboxes('minimal') runs without throwing
    %        on the host MATLAB.
    %     2. LogPolicy('Standard') is applied; logger thresholds match
    %        the documented (INFO console, DEBUG file) pair.
    %     3. saveScenarioData round-trips an annotation containing
    %        NaN/Inf/complex through sanitizeForJson and decorates it
    %        with Header.Runtime.{LogPolicy,ToolboxLevel,SanitizeManifest}.
    %
    %   The test stubs out the heavy ChangShuo engine: it monkey-patches
    %   the runner's engine handle to a tiny local fake that returns one
    %   frame with a deliberately-poisoned annotation. This keeps Phase 0
    %   from depending on the full simulation chain (which Phase 1+ will
    %   stabilise).

    fprintf('=== Phase 0: SimulationRunner startup hooks ===\n');

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRoot);

    csrd.runtime.logger.GlobalLogManager.reset();

    tempRoot = tempname;
    mkdir(tempRoot);
    cleanup = onCleanup(@() localCleanup(tempRoot));

    % --- Build the smallest legal RunnerConfig ----------------------------
    runnerCfg = struct();
    runnerCfg.NumScenarios     = 1;
    runnerCfg.RandomSeed       = 42;
    runnerCfg.Data.OutputDirectory = fullfile(tempRoot, 'phase0_startup_out');
    runnerCfg.Data.CompressData    = false;
    runnerCfg.Engine.Handle = ...
        'Phase0FakeEngine'; % function handle resolved via feval below
    runnerCfg.Toolbox.Level = 'minimal';
    runnerCfg.Log = struct( ...
        'Name', 'CSRD-Phase0-Startup', ...
        'Level', 'DEBUG', ...
        'SaveToFile', true, ...
        'DisplayInConsole', true, ...
        'Policy', 'Standard');

    % Initialise the global logger BEFORE constructing the runner so
    % LogPolicy.apply() has a concrete singleton to mutate.
    csrd.runtime.logger.GlobalLogManager.initialize( ...
        runnerCfg.Log, fullfile(tempRoot, 'phase0_startup_logs'));

    masterCfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
    masterCfg.Runner = runnerCfg;
    masterCfg = csrd.pipeline.runtime.buildRuntimePlan(masterCfg);
    runner = csrd.SimulationRunner( ...
        'RunnerConfig', runnerCfg, ...
        'FactoryConfigs', masterCfg.Factories, ...
        'RuntimePlan', masterCfg.RuntimePlan);

    % --- Hook 1+2: setup() should not throw ------------------------------
    setup(runner);

    % --- Hook 2 verification: thresholds match Standard ------------------
    import csrd.runtime.logger.mlog.Level
    logger = csrd.runtime.logger.GlobalLogManager.getLogger();
    assert(logger.CommandWindowThreshold == Level.INFO, ...
        ['Standard policy must set CommandWindow threshold to INFO; ', ...
        'got %s'], char(logger.CommandWindowThreshold));
    assert(logger.FileThreshold == Level.DEBUG, ...
        'Standard policy must set File threshold to DEBUG; got %s', ...
        char(logger.FileThreshold));
    fprintf('  [OK] Hook 2: LogPolicy thresholds = INFO/DEBUG.\n');

    % --- Hook 3+4: drive saveScenarioData via the public API -------------
    % We can't easily invoke saveScenarioData directly because it's
    % protected. Instead we hand-roll a minimal annotation, write it
    % through the public path step()->executeScenario()->saveScenarioData()
    % using the fake engine.
    step(runner, 1, 1);

    annotationDir = fullfile(runner_actualOutputDirectory(runner), ...
        'annotations');
    files = dir(fullfile(annotationDir, '*.json'));
    assert(~isempty(files), ['No annotation JSON file written; ', ...
        'startup hook test cannot verify Header.Runtime stamping.']);

    annPath = fullfile(annotationDir, files(1).name);
    raw = fileread(annPath);
    decoded = jsondecode(raw);

    assert(isfield(decoded, 'Header'), ...
        'Annotation missing Header.');
    assert(isfield(decoded.Header, 'Runtime'), ...
        'Annotation missing Header.Runtime.');
    rt = decoded.Header.Runtime;

    requiredKeys = {'LogPolicy', 'ToolboxLevel', 'ScenarioId', ...
        'WorkerId', 'SanitizeManifest'};
    for k = 1:numel(requiredKeys)
        assert(isfield(rt, requiredKeys{k}), ...
            'Header.Runtime missing key "%s".', requiredKeys{k});
    end
    fprintf('  [OK] Hook 4: Header.Runtime carries %d mandatory keys.\n', ...
        numel(requiredKeys));

    % LogPolicy description should report the applied tier.
    assert(strcmp(rt.LogPolicy.Level, 'Standard'), ...
        'Header.Runtime.LogPolicy.Level expected "Standard", got "%s".', ...
        rt.LogPolicy.Level);
    assert(strcmp(rt.ToolboxLevel, 'minimal'), ...
        'Header.Runtime.ToolboxLevel expected "minimal", got "%s".', ...
        rt.ToolboxLevel);

    % SanitizeManifest must contain the entries for the poisoned values
    % that Phase0FakeEngine deliberately injected.
    sm = rt.SanitizeManifest;
    assert(strcmp(sm.Schema, 'csrd.sanitize-manifest.v1'), ...
        'Sanitize manifest schema mismatch: %s', sm.Schema);
    assert(~isempty(sm.Entries), ...
        ['Sanitize manifest is empty; expected the fake engine''s ', ...
        'NaN/Inf/complex poison to be coerced.']);
    fprintf('  [OK] Hook 3: sanitize manifest captured %d coercions.\n', ...
        numel(sm.Entries));

    % Round-trip: the JSON must be parseable AND must NOT contain
    % bare NaN/Infinity tokens (i.e. NaN/Infinity appearing in a number
    % position, not inside a quoted string). The sanitize manifest
    % naturally records reason strings like "NaN->null", so a naive
    % contains(raw, 'NaN') would always trip; we use a regex that
    % requires the token to be flanked by JSON value-position punctuation
    % (:, [, , or whitespace).
    bareNaN = regexp(raw, ...
        '(?<=[:,\[\s])NaN(?=[\s,\]\}])', 'once');
    assert(isempty(bareNaN), ...
        ['Annotation JSON still contains a bare NaN token; sanitize ', ...
        'hook is not effective.']);
    bareInf = regexp(raw, ...
        '(?<=[:,\[\s])-?Infinity(?=[\s,\]\}])', 'once');
    assert(isempty(bareInf), ...
        ['Annotation JSON contains a bare Infinity token; sanitize ', ...
        'hook is not effective.']);
    fprintf('  [OK] No bare NaN/Infinity tokens leaked into JSON.\n');

    fprintf('=== Phase 0 startup hooks: ALL PASSED ===\n');
end


function dir = runner_actualOutputDirectory(runner)
%RUNNER_ACTUALOUTPUTDIRECTORY Reach into the runner's protected state.
%
%   We use struct(runner) once, in this single helper, rather than
%   sprinkling reflection across the test body. The protected field is
%   stable across Phase 0; if it ever moves, only this helper breaks.
warnState = warning('off', 'MATLAB:structOnObject');
cleanup = onCleanup(@() warning(warnState));
s = struct(runner);
dir = s.actualOutputDirectory;
end


function localCleanup(p)
if isfolder(p)
    try
        rmdir(p, 's');
    catch
        % best-effort cleanup; do not fail the test on rmdir error
    end
end
csrd.runtime.logger.GlobalLogManager.reset();
end
