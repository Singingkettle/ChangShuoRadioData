function test_no_dead_code_phase4()
    %TEST_NO_DEAD_CODE_PHASE4 Phase 4 §6 C3 / §4.3 schema-cleanup gate.
    %
    %   Phase 4 §3.4 (decision A_full_replace) deleted the v1 SignalSource
    %   top-level keys (`Realized` / `Planned` / `Temporal` / `Spatial` /
    %   `LinkBudget` / `Channel`) in favour of the unified
    %   `Truth.{Design, Execution, Measured}` hierarchy. This regression
    %   is the static-analysis gate: it scans the production source tree
    %   for any leftover assignment that would re-introduce the v1
    %   top-level keys onto a SignalSources entry, and it scans a fresh
    %   smoke annotation to make sure no v1 key survived to the JSON.
    %
    %   The test is intentionally syntactic (regex over `+csrd/` source)
    %   plus a single smoke-driven semantic check; it makes no attempt to
    %   parse MATLAB AST. Two-pronged coverage:
    %
    %     A) static  - reject `<lhs>.<v1Key> = ...` patterns where <lhs>
    %                  is one of {sourceInfo, source, src, sourceStruct}.
    %                  These are the variable names the v1 builder used.
    %                  `comp.Planned` / `comp.Realized` (modulator/channel
    %                  internal records) are explicitly tolerated because
    %                  Phase 4 §3.4 reuses them as Execution / Design
    %                  feedstock; the deletion contract only forbids the
    %                  v1 keys from appearing in the SignalSources struct.
    %
    %     B) dynamic - drive one smoke scenario through the full pipeline
    %                  and assert no SignalSources entry carries any of
    %                  the six banned top-level keys. This catches indirect
    %                  field-passthrough bugs (struct copy, dynamic field
    %                  set) that the static scan can't see.
    %
    %   Exit: regression PASS / FAIL printed; raises an error on any
    %   violation so `runtests` / `run_all_tests` fails the suite.

    fprintf('=== Phase 4 dead-code v1 schema gate ===\n');

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRoot);
    addpath(fileparts(mfilename('fullpath')));

    % --- A) static scan -----------------------------------------------
    csrdRoot = fullfile(projectRoot, '+csrd');
    bannedKeys = {'Realized', 'Planned', 'Temporal', 'Spatial', 'LinkBudget', 'Channel'};
    bannedLhs  = {'sourceInfo', 'source', 'src', 'sourceStruct', 'sourceAnnotation'};

    violations = struct('File', {}, 'LineNo', {}, 'Pattern', {}, 'Line', {});

    files = localFindMatlabSources(csrdRoot);
    for fIdx = 1:numel(files)
        path = files{fIdx};
        text = fileread(path);
        lines = regexp(text, '\r?\n', 'split');
        for keyIdx = 1:numel(bannedKeys)
            for lhsIdx = 1:numel(bannedLhs)
                pat = sprintf('(?<![\\w.])%s\\.%s\\s*=', ...
                    bannedLhs{lhsIdx}, bannedKeys{keyIdx});
                for lineIdx = 1:numel(lines)
                    if ~isempty(regexp(lines{lineIdx}, pat, 'once'))
                        violations(end + 1) = struct( ...
                            'File',    path, ...
                            'LineNo',  lineIdx, ...
                            'Pattern', pat, ...
                            'Line',    strtrim(lines{lineIdx})); %#ok<AGROW>
                    end
                end
            end
        end
    end

    if ~isempty(violations)
        fprintf(2, 'Phase 4 dead-code: %d static violations:\n', ...
            numel(violations));
        for k = 1:numel(violations)
            v = violations(k);
            relPath = strrep(v.File, projectRoot, '');
            fprintf(2, '  %s:%d  >> %s\n', relPath, v.LineNo, v.Line);
        end
        error('CSRD:Phase4:DeadCodeDetected', ...
            ['Phase 4 §6 C3 violated: %d v1 SignalSources top-level field ' ...
             'assignments survived in `+csrd/`. The unified Truth.{Design, ' ...
             'Execution, Measured} hierarchy must be the sole carrier.'], ...
            numel(violations));
    end
    fprintf('  Static scan: %d files scanned, 0 v1 top-level violations.\n', ...
        numel(files));

    % --- B) smoke-driven dynamic scan ---------------------------------
    csrd.utils.logger.GlobalLogManager.reset();
    csrd.utils.toolbox.validateRequiredToolboxes('minimal');

    runRoot = fullfile(projectRoot, 'artifacts', 'tests', 'runs', ...
        'phase4_no_dead_code');
    if ~exist(runRoot, 'dir'); mkdir(runRoot); end

    sweepLogDir = fullfile(runRoot, 'logs');
    if ~exist(sweepLogDir, 'dir'); mkdir(sweepLogDir); end

    bootstrapLog = struct( ...
        'Name', 'CSRD-Phase4-DeadCode', ...
        'Level', 'WARNING', ...
        'SaveToFile', true, ...
        'DisplayInConsole', false);
    csrd.utils.logger.GlobalLogManager.initialize(bootstrapLog, sweepLogDir);
    policy = csrd.utils.logger.policy.LogPolicy('Standard');
    policy.apply();

    rng(20260426, 'twister');
    fullRecipe = baseline_recipe_v0();
    cohort = fullRecipe.Cohorts(1);
    cohort.RxRange = [1, 1];

    masterCfg = csrd.utils.config_loader('csrd2025/csrd2025.m');
    sid = 1;
    scenarioCfg = localApplyCohort(masterCfg, cohort, runRoot, sid);

    annotationPath = localRunOneScenario(scenarioCfg, sid);
    assert(~isempty(annotationPath) && exist(annotationPath, 'file') == 2, ...
        'Phase 4 dead-code: smoke annotation file not written: %s', ...
        annotationPath);

    annotation = jsondecode(fileread(annotationPath));
    sources = localCollectSources(annotation);
    assert(~isempty(sources), ...
        'Phase 4 dead-code: smoke annotation contained no SignalSources.');

    badFields = strings(0, 1);
    for k = 1:numel(sources)
        src = sources{k};
        if ~isstruct(src); continue; end
        for keyIdx = 1:numel(bannedKeys)
            if isfield(src, bannedKeys{keyIdx})
                badFields(end + 1) = sprintf('source[%d].%s', k, bannedKeys{keyIdx}); %#ok<AGROW>
            end
        end
    end

    if ~isempty(badFields)
        for k = 1:numel(badFields)
            fprintf(2, '  v1-leak: %s\n', badFields(k));
        end
        error('CSRD:Phase4:V1SchemaLeakedToJson', ...
            ['Phase 4 §6 C3 violated: %d v1 SignalSources top-level keys ' ...
             'survived into the annotation JSON (e.g. Realized / Planned / ' ...
             'Temporal / Spatial / LinkBudget / Channel).'], ...
            numel(badFields));
    end
    fprintf('  Dynamic scan: %d sources, 0 v1 top-level keys.\n', ...
        numel(sources));

    fprintf('=== Phase 4 dead-code v1 schema gate PASSED ===\n');
end


function out = localFindMatlabSources(rootDir)
    %LOCALFINDMATLABSOURCES Recursively gather *.m files under rootDir.
    out = {};
    if exist(rootDir, 'dir') ~= 7
        return;
    end
    listing = dir(fullfile(rootDir, '**', '*.m'));
    for k = 1:numel(listing)
        if listing(k).isdir
            continue;
        end
        out{end + 1} = fullfile(listing(k).folder, listing(k).name); %#ok<AGROW>
    end
end


function cfg = localApplyCohort(masterCfg, cohort, runRoot, sid)
    cfg = masterCfg;
    cfg.Runner.NumScenarios     = 1;
    cfg.Runner.RandomSeed       = 20260426 + sid;
    cfg.Runner.Toolbox.Level    = 'minimal';
    cfg.Runner.Log.Policy       = 'Standard';
    cfg.Runner.Data.OutputDirectory = fullfile(runRoot, ...
        sprintf('scenario_%06d', sid));
    cfg.Runner.Data.CompressData = false;

    cfg.Factories.Scenario.Global.NumFramesPerScenario = ...
        cohort.NumFramesPerScenario;
    cfg.Factories.Scenario.Global.ObservationDuration = ...
        cohort.ObservationDuration;

    cfg.Factories.Scenario.PhysicalEnvironment.Map.Types = cohort.MapTypes;
    cfg.Factories.Scenario.PhysicalEnvironment.Map.Ratio = cohort.MapRatio;
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min ...
        = cohort.TxRange(1);
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max ...
        = cohort.TxRange(2);
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min ...
        = cohort.RxRange(1);
    cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max ...
        = cohort.RxRange(2);

    if ~isfield(cfg.Factories.Scenario, 'CommunicationBehavior')
        cfg.Factories.Scenario.CommunicationBehavior = struct();
    end
    if ~isfield(cfg.Factories.Scenario.CommunicationBehavior, 'TemporalBehavior')
        cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior = struct();
    end
    cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternTypes = ...
        cohort.PatternTypes;
    cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternDistribution = ...
        cohort.PatternDistribution;
end


function annotationPath = localRunOneScenario(cfg, ~)
    runner = csrd.SimulationRunner( ...
        'RunnerConfig', cfg.Runner, 'FactoryConfigs', cfg.Factories);
    setup(runner);
    step(runner, 1, 1);

    warnState = warning('off', 'MATLAB:structOnObject');
    cleanup = onCleanup(@() warning(warnState)); %#ok<NASGU>
    s = struct(runner); %#ok<NOPRT>
    outDir = s.actualOutputDirectory;
    annotationPath = fullfile(outDir, 'annotations', ...
        sprintf('scenario_%06d_annotation.json', 1));
end


function sources = localCollectSources(annotation)
    sources = {};
    if ~isstruct(annotation); return; end
    candidates = {annotation};
    for fn = {'Frames', 'Annotation', 'Annotations'}
        if isfield(annotation, fn{1})
            candidates{end + 1} = annotation.(fn{1}); %#ok<AGROW>
        end
    end
    for c = 1:numel(candidates)
        sources = [sources; localScanSources(candidates{c})]; %#ok<AGROW>
    end
end


function out = localScanSources(payload)
    out = {};
    if iscell(payload)
        for k = 1:numel(payload)
            out = [out; localScanSources(payload{k})]; %#ok<AGROW>
        end
        return;
    end
    if isstruct(payload)
        if isfield(payload, 'SignalSources')
            ss = payload.SignalSources;
            if iscell(ss)
                for k = 1:numel(ss)
                    if isstruct(ss{k})
                        out{end + 1} = ss{k}; %#ok<AGROW>
                    end
                end
            else
                for k = 1:numel(ss)
                    out{end + 1} = ss(k); %#ok<AGROW>
                end
            end
        end
        if numel(payload) > 1
            for k = 1:numel(payload)
                out = [out; localScanSources(payload(k))]; %#ok<AGROW>
            end
        end
        if isscalar(payload)
            f = fieldnames(payload);
            for i = 1:numel(f)
                child = payload.(f{i});
                if isstruct(child) || iscell(child)
                    out = [out; localScanSources(child)]; %#ok<AGROW>
                end
            end
        end
    end
end
