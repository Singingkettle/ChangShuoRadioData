function test_baseline_sweep_200(varargin)
    %TEST_BASELINE_SWEEP_200 Phase 0 baseline sweep & metric capture.
    %
    %   test_baseline_sweep_200()                  % default smoke run, N=12
    %   test_baseline_sweep_200(N)                 % N >= 1 scenarios
    %   test_baseline_sweep_200(N, 'Mode', 'full') % write canonical baseline
    %   test_baseline_sweep_200(..., 'BaselineFilename', 'custom.json')
    %   test_baseline_sweep_200(..., 'RunLabel', 'baseline_custom')
    %
    %   Implements phase-0-baseline.md §3 (sweep program) and §4
    %   (metric definitions). The function operates in two modes:
    %
    %     'smoke' (default, N=12)
    %       - intended for CI / `run_all_tests('regression')`
    %       - writes docs/baselines/2026-04-baseline-v0.smoke.json
    %       - skips the no-regression assertion against the canonical
    %         baseline (smoke runs are too noisy)
    %
    %     'full' (N must be >= 200 to count as canonical)
    %       - operator-driven; writes docs/baselines/2026-04-baseline-v0.json
    %       - if a prior canonical baseline exists, asserts that none of
    %         the seven exit-condition metrics have drifted by >10%
    %
    %   Source-of-truth metric definitions: phase-0-baseline.md §4.

    p = inputParser;
    addOptional(p, 'numScenarios', 12, ...
        @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'Mode', 'auto', ...
        @(x) any(strcmpi(x, {'auto', 'smoke', 'full'})));
    addParameter(p, 'BaselineFilename', '', ...
        @(x) ischar(x) || isstring(x));
    addParameter(p, 'RunLabel', 'baseline_v0', ...
        @(x) ischar(x) || isstring(x));
    addParameter(p, 'SchemaVersion', 'baseline-v0', ...
        @(x) ischar(x) || isstring(x));
    addParameter(p, 'Resume', false, @islogical);
    addParameter(p, 'CheckpointFilename', 'per_scenario_checkpoint.mat', ...
        @(x) ischar(x) || isstring(x));
    parse(p, varargin{:});
    numScenarios = double(p.Results.numScenarios);
    mode = lower(p.Results.Mode);
    baselineFilename = char(string(p.Results.BaselineFilename));
    runLabel = char(string(p.Results.RunLabel));
    schemaVersion = char(string(p.Results.SchemaVersion));
    resumeRun = p.Results.Resume;
    checkpointFilename = char(string(p.Results.CheckpointFilename));
    if strcmp(mode, 'auto')
        if numScenarios >= 200
            mode = 'full';
        else
            mode = 'smoke';
        end
    end

    fprintf('=== Phase 0 baseline sweep (%s mode, N=%d) ===\n', ...
        mode, numScenarios);

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRoot);
    addpath(fileparts(mfilename('fullpath')));

    % --- 1. setupBaseline ------------------------------------------------
    csrd.runtime.logger.GlobalLogManager.reset();

    runRoot = fullfile(projectRoot, 'artifacts', 'tests', 'runs', ...
        runLabel);
    if ~exist(runRoot, 'dir')
        mkdir(runRoot);
    end
    checkpointPath = fullfile(runRoot, checkpointFilename);

    csrd.runtime.toolbox.validateRequiredToolboxes('minimal');

    sweepLogDir = fullfile(runRoot, 'sweep_logs');
    if ~exist(sweepLogDir, 'dir')
        mkdir(sweepLogDir);
    end
    bootstrapLog = struct( ...
        'Name', 'CSRD-Phase0-Baseline', ...
        'Level', 'DEBUG', ...
        'SaveToFile', true, ...
        'DisplayInConsole', false);
    csrd.runtime.logger.GlobalLogManager.initialize(bootstrapLog, sweepLogDir);
    policy = csrd.runtime.logger.policy.LogPolicy('Standard');
    policy.apply();

    rng(20260424, 'twister');

    % --- 2. recipe selection --------------------------------------------
    fullRecipe = baseline_recipe_v0();
    plan = localExpandRecipe(fullRecipe, numScenarios);
    fprintf('  Recipe: %d cohorts -> %d scenarios assigned.\n', ...
        numel(fullRecipe.Cohorts), numel(plan));

    % --- 3. master config baseline --------------------------------------
    masterCfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');

    % --- 4. per-scenario sweep ------------------------------------------
    perScenario = repmat(struct( ...
        'ScenarioId', 0, ...
        'Cohort', '', ...
        'Wallclock', NaN, ...
        'AnnotationBytes', NaN, ...
        'LogLines', NaN, ...
        'Skipped', false, ...
        'SkipReason', '', ...
        'ChannelFailed', false, ...
        'NumSourcesTotal', 0, ...
        'NumEmptySources', 0, ...
        'NumLowSnrExcluded', 0, ...
        'BwAbsRelDiffs', [], ...
        'BwAbsRelDiffsLowSnr', [], ...
        'JsonNanCount', 0, ...
        'JsonInfinityCount', 0, ...
        'SanitizeManifestEntryCount', 0, ...
        'BlueprintResamples', NaN, ...
        'BlueprintHash', '', ...
        'ValidatorVersion', ''), 0, 1);
    checkpointRecords = repmat(struct( ...
        'ScenarioId', 0, ...
        'Cohort', '', ...
        'Wallclock', NaN, ...
        'AnnotationBytes', NaN, ...
        'LogLines', NaN, ...
        'Skipped', false, ...
        'SkipReason', '', ...
        'ChannelFailed', false, ...
        'NumSourcesTotal', 0, ...
        'NumEmptySources', 0, ...
        'NumLowSnrExcluded', 0, ...
        'BwAbsRelDiffs', [], ...
        'BwAbsRelDiffsLowSnr', [], ...
        'JsonNanCount', 0, ...
        'JsonInfinityCount', 0, ...
        'SanitizeManifestEntryCount', 0, ...
        'BlueprintResamples', NaN, ...
        'BlueprintHash', '', ...
        'ValidatorVersion', ''), 0, 1);
    if resumeRun
        checkpointRecords = localLoadCheckpointRecords(checkpointPath);
        fprintf('  Resume enabled: checkpoint records=%d, runRoot=%s\n', ...
            numel(checkpointRecords), runRoot);
    end

    sweepStart = tic;
    numRecovered = 0;
    for k = 1:numel(plan)
        sid = plan(k).ScenarioId;
        cohort = plan(k).Cohort;
        rec = localEmptyScenarioRecord(sid, cohort.Name);

        scenarioCfg = localCohortToRunnerCfg(masterCfg, cohort, runRoot, sid);
        if resumeRun
            [recovered, rec] = localTryRecoverScenarioRecord( ...
                scenarioCfg.Runner.Data.OutputDirectory, sid, cohort.Name, ...
                checkpointRecords);
            if recovered
                numRecovered = numRecovered + 1;
                perScenario(end + 1) = rec; %#ok<AGROW>
                if mod(numRecovered, 50) == 0
                    fprintf('  ...resume recovered %d scenarios (latest sid=%d)\n', ...
                        numRecovered, sid);
                end
                localSaveCheckpoint(checkpointPath, perScenario, k, ...
                    mode, numScenarios, runLabel, schemaVersion);
                if mod(k, max(1, floor(numel(plan) / 10))) == 0
                    fprintf('  ...progress %d / %d (elapsed %.1fs)\n', ...
                        k, numel(plan), toc(sweepStart));
                end
                continue;
            end
        end

        try
            t0 = tic;
            [annotationPath, annotationStruct] = localRunOneScenario( ...
                scenarioCfg, sid);
            rec.Wallclock = toc(t0);
            rec = localPopulateRecordFromAnnotation(rec, annotationPath, ...
                annotationStruct, scenarioCfg.Runner.Data.OutputDirectory);
        catch sweepErr
            if csrd.pipeline.scenario.isScenarioSkipException(sweepErr)
                rec.Skipped = true;
                rec.SkipReason = localShortSkipReason(sweepErr);
            elseif contains(sweepErr.message, 'ChannelBlock', 'IgnoreCase', true) ...
                    || contains(sweepErr.identifier, 'Channel', 'IgnoreCase', true)
                rec.ChannelFailed = true;
            else
                % Treat other errors as channel-failure for the purposes
                % of the failure-rate metric so the sweep does not crash.
                rec.ChannelFailed = true;
            end
            rec.Wallclock = NaN;
        end
        perScenario(end + 1) = rec; %#ok<AGROW>
        localSaveCheckpoint(checkpointPath, perScenario, k, mode, ...
            numScenarios, runLabel, schemaVersion);

        if mod(k, max(1, floor(numel(plan) / 10))) == 0
            fprintf('  ...progress %d / %d (elapsed %.1fs)\n', ...
                k, numel(plan), toc(sweepStart));
        end
    end
    sweepDuration = toc(sweepStart);
    fprintf('  Sweep wallclock: %.1f s\n', sweepDuration);

    % --- 5. aggregate metrics -------------------------------------------
    metrics = localAggregateMetrics(perScenario);

    % --- 6. write baseline JSON -----------------------------------------
    baselineDir = fullfile(projectRoot, 'docs', 'baselines');
    if ~exist(baselineDir, 'dir')
        mkdir(baselineDir);
    end

    if isempty(baselineFilename) && strcmp(mode, 'full')
        baselinePath = fullfile(baselineDir, '2026-04-baseline-v0.json');
    elseif isempty(baselineFilename)
        baselinePath = fullfile(baselineDir, '2026-04-baseline-v0.smoke.json');
    else
        baselinePath = fullfile(baselineDir, baselineFilename);
    end

    wallclockVals = [perScenario.Wallclock];
    wallclockVals = wallclockVals(~isnan(wallclockVals));
    runRecovery = struct( ...
        'Resume', resumeRun, ...
        'NumRecoveredScenarios', numRecovered, ...
        'AggregationWallclockSec', sweepDuration, ...
        'ScenarioWallclockSecSum', sum(wallclockVals));
    payload = localBuildBaselinePayload( ...
        mode, numScenarios, plan, metrics, sweepDuration, ...
        schemaVersion, runRecovery);

    [clean, ~] = csrd.pipeline.annotation.sanitizeForJson(payload);
    txt = jsonencode(clean, 'PrettyPrint', true);
    fid = fopen(baselinePath, 'w');
    assert(fid ~= -1, ...
        'Cannot open baseline file for writing: %s', baselinePath);
    fprintf(fid, '%s', txt);
    fclose(fid);
    fprintf('  Baseline written to: %s\n', baselinePath);

    % --- 7. exit-condition assertions -----------------------------------
    localAssertExitConditions(metrics, mode, numScenarios, ...
        baselineDir, baselinePath, schemaVersion);

    fprintf('=== Phase 0 baseline sweep PASSED (%s mode) ===\n', mode);
end


% =========================================================================
function plan = localExpandRecipe(recipe, numScenarios)
% Expand the canonical 200-scenario recipe down to numScenarios. We keep
% relative cohort weights so the smoke run remains representative.
cohorts = recipe.Cohorts;
weights = double([cohorts.Count]);
weights = weights / sum(weights);
counts  = max(0, round(weights * numScenarios));

% Repair rounding: fix any drift so total == numScenarios.
delta = numScenarios - sum(counts);
if delta ~= 0
    [~, order] = sort(weights, 'descend');
    i = 1;
    step = sign(delta);
    while delta ~= 0 && i <= numel(order)
        idx = order(i);
        if step > 0 || counts(idx) > 0
            counts(idx) = counts(idx) + step;
            delta = delta - step;
        end
        i = i + 1;
        if i > numel(order)
            i = 1;
        end
    end
end
% Guarantee every cohort appears at least once when numScenarios >= numel(cohorts).
if numScenarios >= numel(cohorts)
    for k = 1:numel(cohorts)
        if counts(k) == 0
            [~, take] = max(counts);
            counts(take) = counts(take) - 1;
            counts(k) = 1;
        end
    end
end

plan = repmat(struct('ScenarioId', 0, 'Cohort', cohorts(1)), 0, 1);
sid = 1;
for k = 1:numel(cohorts)
    for j = 1:counts(k)
        plan(end + 1) = struct( ...
            'ScenarioId', sid, ...
            'Cohort', cohorts(k)); %#ok<AGROW>
        sid = sid + 1;
    end
end
end


% =========================================================================
function cfg = localCohortToRunnerCfg(masterCfg, cohort, runRoot, sid)
cfg = masterCfg;
cfg.Runner.NumScenarios     = 1;
cfg.Runner.RandomSeed       = 20260424 + sid; % deterministic per sid
cfg.Runner.Toolbox.Level    = 'minimal';
cfg.Logging.Policy          = 'Standard';
cfg.Logging.Progress.Mode   = 'Detailed';
cfg.Runner.Data.OutputDirectory = fullfile(runRoot, ...
    sprintf('scenario_%06d', sid));
cfg.Runner.Data.CompressData = false;

cfg = csrd.test_support.applyCanonicalFrameContract( ...
    cfg, cohort.ObservationDuration, cohort.NumFramesPerScenario);

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

% Phase 4 (audit §3.8.A): cohort-driven per-entity velocity ceiling.
% Project `cohort.CohortMaxSpeedMps` onto every entity-type Mobility
% subtree so PhysicalEnvironmentSimulator/createEntity →
% getMaxSpeedForEntityType lifts the sampled per-axis velocity envelope
% above the type-default 10 / 5 / 2 m/s. Cohorts that don't set
% CohortMaxSpeedMps (= 0) leave the factory defaults intact.
if isfield(cohort, 'CohortMaxSpeedMps') && cohort.CohortMaxSpeedMps > 0
    cohortMaxSpeed = double(cohort.CohortMaxSpeedMps);
    if ~isfield(cfg.Factories.Scenario.PhysicalEnvironment.Entities, 'Transmitters')
        cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters = struct();
    end
    if ~isfield(cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters, 'Mobility')
        cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Mobility = struct();
    end
    cfg.Factories.Scenario.PhysicalEnvironment.Entities ...
        .Transmitters.Mobility.MaxSpeedMps = cohortMaxSpeed;

    if ~isfield(cfg.Factories.Scenario.PhysicalEnvironment.Entities, 'Receivers')
        cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers = struct();
    end
    if ~isfield(cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers, 'Mobility')
        cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Mobility = struct();
    end
    cfg.Factories.Scenario.PhysicalEnvironment.Entities ...
        .Receivers.Mobility.MaxSpeedMps = cohortMaxSpeed;
end

% Phase 12: cohort-driven channel preference must use the existing
% scenario map ChannelModel contract. The previous channel-factory
% preference field was never consumed, so writing it here only made the
% cohort name lie about the channel actually used.
if isfield(cohort, 'ChannelPreference') && ~isempty(cohort.ChannelPreference)
    channelPref = char(cohort.ChannelPreference);
    if any(strcmp(cohort.MapTypes, 'Statistical'))
        cfg.Factories.Scenario.PhysicalEnvironment.Map ...
            .Statistical.ChannelModel = channelPref;
    end
    if any(strcmp(cohort.MapTypes, 'OSM'))
        cfg.Factories.Scenario.PhysicalEnvironment.Map ...
            .OSM.ChannelModel = channelPref;
    end
end
end


% =========================================================================
function [annotationPath, annotationStruct] = localRunOneScenario(cfg, sid)
% Phase 2 (audit C4 follow-up): SimulationRunner only knows scenarioId
% from its internal calculateScenarioDistribution loop, which always
% maps NumScenarios=1 to the single in-runner scenarioId 1. To give
% every test-level scenario `sid` its own annotation file (instead of
% having scenarios 2..N silently overwrite scenarios 1..N-1's
% annotation), we reset the GlobalLogManager so each runner spins up a
% fresh session directory, and we always read back the runner's
% canonical `scenario_000001_annotation.json` filename.
csrd.runtime.logger.GlobalLogManager.reset();
bootstrapLog = struct( ...
    'Name', sprintf('CSRD-Phase0-Baseline-S%06d', sid), ...
    'Level', 'DEBUG', ...
    'SaveToFile', true, ...
    'DisplayInConsole', false);
% Per-scenario sandbox: GlobalLogManager creates
%   <perScenarioDir>/session_<HHmmss>/logs/
% and SimulationRunner pins actualOutputDirectory to that session dir.
% Using the per-sid OutputDirectory (rather than the shared sweep_logs
% root) guarantees no two scenarios collide on the 1-second timestamp.
perScenarioDir = cfg.Runner.Data.OutputDirectory;
csrd.runtime.logger.GlobalLogManager.initialize(bootstrapLog, perScenarioDir);
policy = csrd.runtime.logger.policy.LogPolicy('Standard');
policy.apply();

cfg = csrd.test_support.buildRuntimePlanForTest(cfg);
runner = csrd.SimulationRunner( ...
    'RunnerConfig', cfg.Runner, ...
    'FactoryConfigs', cfg.Factories, ...
    'RuntimePlan', cfg.RuntimePlan);
setup(runner);

% Clear this scenario's annotation target BEFORE stepping. Each scenario already
% gets its own session-scoped outDir, so this is belt and braces on that -- but a
% baseline is the one artefact where a silently duplicated scenario is invisible
% after the fact, because the aggregate looks entirely plausible. Note the ordering:
% clearing after the step would delete the annotation this function then reads.
warnStatePre = warning('off', 'MATLAB:structOnObject');
annotationPathPre = fullfile(struct(runner).actualOutputDirectory, 'annotations', ...
    'scenario_000001_annotation.json');
warning(warnStatePre);
csrd.test_support.freshAnnotationReader('clear', annotationPathPre);

step(runner, 1, 1);

% Suppress the noisy `MATLAB:structOnObject` warning that fires every
% time we look at a SimulationRunner instance to discover the resolved
% output directory. Phase 1+ will expose this via a public accessor.
warnState = warning('off', 'MATLAB:structOnObject');
warnGuard = onCleanup(@() warning(warnState));
s = struct(runner);
outDir = s.actualOutputDirectory;
% Runner always writes scenario_000001 because totalScenarios=1; the
% per-scenario uniqueness is enforced by giving each scenario its own
% session-scoped outDir above.
annotationPath = fullfile(outDir, 'annotations', ...
    'scenario_000001_annotation.json');

annotationStruct = struct();
if exist(annotationPath, 'file')
    raw = fileread(annotationPath);
    try
        annotationStruct = jsondecode(raw);
    catch
        annotationStruct = struct();
    end
end
end


% =========================================================================
function rec = localEmptyScenarioRecord(sid, cohortName)
rec = struct( ...
    'ScenarioId', sid, ...
    'Cohort', cohortName, ...
    'Wallclock', NaN, ...
    'AnnotationBytes', NaN, ...
    'LogLines', NaN, ...
    'Skipped', false, ...
    'SkipReason', '', ...
    'ChannelFailed', false, ...
    'NumSourcesTotal', 0, ...
    'NumEmptySources', 0, ...
    'NumLowSnrExcluded', 0, ...
    'BwAbsRelDiffs', [], ...
    'BwAbsRelDiffsLowSnr', [], ...
    'JsonNanCount', 0, ...
    'JsonInfinityCount', 0, ...
    'SanitizeManifestEntryCount', 0, ...
    'BlueprintResamples', NaN, ...
    'BlueprintHash', '', ...
    'ValidatorVersion', '');
end


% =========================================================================
function [recovered, rec] = localTryRecoverScenarioRecord( ...
        perScenarioDir, sid, cohortName, checkpointRecords)
recovered = false;
rec = localEmptyScenarioRecord(sid, cohortName);

[foundInCheckpoint, checkpointRec] = localFindCheckpointRecord( ...
    checkpointRecords, sid);
if foundInCheckpoint
    rec = checkpointRec;
    recovered = true;
    return;
end

[annotationPath, annotationStruct] = localFindLatestAnnotation(perScenarioDir);
if isempty(annotationPath)
    return;
end

rec = localPopulateRecordFromAnnotation(rec, annotationPath, ...
    annotationStruct, perScenarioDir);
if isnan(rec.Wallclock)
    rec.Wallclock = localRecoverWallclockSeconds(perScenarioDir);
end
recovered = true;
end


function [found, rec] = localFindCheckpointRecord(records, sid)
found = false;
rec = struct();
if isempty(records)
    return;
end
idx = find([records.ScenarioId] == sid, 1, 'last');
if isempty(idx)
    return;
end
rec = records(idx);
found = true;
end


function records = localLoadCheckpointRecords(checkpointPath)
records = [];
if ~exist(checkpointPath, 'file')
    return;
end
try
    s = load(checkpointPath, 'checkpoint');
    if isfield(s, 'checkpoint') && isstruct(s.checkpoint) ...
            && isfield(s.checkpoint, 'PerScenario') ...
            && isstruct(s.checkpoint.PerScenario)
        records = s.checkpoint.PerScenario;
    end
catch
    records = [];
end
end


function localSaveCheckpoint(checkpointPath, perScenario, currentIndex, ...
        mode, numScenarios, runLabel, schemaVersion)
checkpoint = struct( ...
    'SavedAt', char(datetime('now', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''', 'TimeZone', 'UTC')), ...
    'CurrentIndex', currentIndex, ...
    'Mode', mode, ...
    'NumScenarios', numScenarios, ...
    'RunLabel', runLabel, ...
    'SchemaVersion', schemaVersion, ...
    'PerScenario', perScenario);
try
    save(checkpointPath, 'checkpoint', '-v7');
catch
    warning('CSRD:Baseline:CheckpointWriteFailed', ...
        'Could not write baseline checkpoint: %s', checkpointPath);
end
end


function [annotationPath, annotationStruct] = localFindLatestAnnotation( ...
        perScenarioDir)
annotationPath = '';
annotationStruct = struct();
sessionDirs = dir(fullfile(perScenarioDir, 'session_*'));
if isempty(sessionDirs)
    return;
end
[~, order] = sort([sessionDirs.datenum], 'descend');
sessionDirs = sessionDirs(order);
for k = 1:numel(sessionDirs)
    if ~sessionDirs(k).isdir
        continue;
    end
    candidate = fullfile(sessionDirs(k).folder, sessionDirs(k).name, ...
        'annotations', 'scenario_000001_annotation.json');
    if ~exist(candidate, 'file')
        continue;
    end
    try
        raw = fileread(candidate);
        annotationStruct = jsondecode(raw);
        annotationPath = candidate;
        return;
    catch
        annotationPath = '';
        annotationStruct = struct();
    end
end
end


function rec = localPopulateRecordFromAnnotation(rec, annotationPath, ...
        annotationStruct, perScenarioDir)
if isempty(annotationPath) || ~exist(annotationPath, 'file')
    return;
end

info = dir(annotationPath);
rec.AnnotationBytes = info(1).bytes;
raw = fileread(annotationPath);
% Phase 4 (audit §17.6 / phase-4-measurement.md S11):
% `sanitizeForJson` emits SanitizeManifest entries with
% `Reason="NaN->null"` / `Reason="Inf->Inf-string"` in Header.Runtime.
% Strip JSON string literals before scanning so the count reflects bare
% tokens only, which would indicate a real sanitizer leak.
rawNoStr = regexprep(raw, '"(\\.|[^"\\])*"', '""');
rec.JsonNanCount      = numel(regexp(rawNoStr, '\<NaN\>', 'match'));
rec.JsonInfinityCount = numel(regexp(rawNoStr, '\<Infinity\>', 'match'));
rec.LogLines = localCountLogLinesForScenario(perScenarioDir, rec.ScenarioId);
rec = localCollectBwAndEmptyStats(rec, annotationStruct);

if isstruct(annotationStruct) ...
        && isfield(annotationStruct, 'Header') ...
        && isfield(annotationStruct.Header, 'Runtime') ...
        && isfield(annotationStruct.Header.Runtime, 'SanitizeManifest')
    sm = annotationStruct.Header.Runtime.SanitizeManifest;
    if isstruct(sm) && isfield(sm, 'Entries')
        rec.SanitizeManifestEntryCount = numel(sm.Entries);
    end
end

% Phase 2 (audit C4 / C7): pull blueprint provenance out of the persisted
% annotation header so the aggregator can compute BlueprintResamplesP95.
if isstruct(annotationStruct) ...
        && isfield(annotationStruct, 'Header') ...
        && isfield(annotationStruct.Header, 'Runtime')
    rt = annotationStruct.Header.Runtime;
    if isfield(rt, 'BlueprintResamples') ...
            && isnumeric(rt.BlueprintResamples) ...
            && isscalar(rt.BlueprintResamples) ...
            && isfinite(rt.BlueprintResamples)
        rec.BlueprintResamples = double(rt.BlueprintResamples);
    end
    if isfield(rt, 'BlueprintHash')
        rec.BlueprintHash = char(string(rt.BlueprintHash));
    end
    if isfield(rt, 'ValidatorVersion')
        rec.ValidatorVersion = char(string(rt.ValidatorVersion));
    end
end
end


function seconds = localRecoverWallclockSeconds(perScenarioDir)
seconds = NaN;
logFiles = dir(fullfile(perScenarioDir, 'session_*', 'logs', '*.log'));
if isempty(logFiles)
    return;
end
[~, order] = sort([logFiles.datenum], 'ascend');
logFiles = logFiles(order);
for k = 1:numel(logFiles)
    try
        txt = fileread(fullfile(logFiles(k).folder, logFiles(k).name));
    catch
        continue;
    end
    tokens = regexp(txt, 'Total simulation time:\s*([0-9.]+)\s*seconds', ...
        'tokens');
    if ~isempty(tokens)
        seconds = str2double(tokens{end}{1});
        continue;
    end
    tokens = regexp(txt, 'Time:\s*([0-9.]+)s\s*\|\s*Progress:\s*100\.0%', ...
        'tokens');
    if ~isempty(tokens)
        seconds = str2double(tokens{end}{1});
    end
end
end


% =========================================================================
function lines = localCountLogLinesForScenario(perScenarioDir, ~)
% Phase 2 (audit C4 follow-up): each scenario gets its own session
% directory under `perScenarioDir/session_<HHmmss>/logs/`. The runner
% always reports scenarios under in-runner id=1, so we count every line
% in the per-scenario log files instead of grepping for an id token.
lines = 0;
sessionDirs = dir(fullfile(perScenarioDir, 'session_*'));
for k = 1:numel(sessionDirs)
    if ~sessionDirs(k).isdir, continue; end
    logFiles = dir(fullfile(sessionDirs(k).folder, sessionDirs(k).name, ...
        'logs', '*.log'));
    for j = 1:numel(logFiles)
        try
            txt = fileread(fullfile(logFiles(j).folder, logFiles(j).name));
            lines = lines + numel(regexp(txt, '\n', 'match'));
        catch
            % ignore unreadable rolled-over log files
        end
    end
end
end


% =========================================================================
function rec = localCollectBwAndEmptyStats(rec, annotation)
if ~isstruct(annotation)
    return;
end
% scenarioAnnotation in saved JSON may be a struct, struct array, or cell.
fields = {'Frames', 'Annotation', 'Annotations'};
candidates = {};
for f = 1:numel(fields)
    if isfield(annotation, fields{f})
        candidates{end + 1} = annotation.(fields{f}); %#ok<AGROW>
    end
end
candidates{end + 1} = annotation;
for c = 1:numel(candidates)
    rec = localScanForSources(rec, candidates{c});
end
end


function rec = localScanForSources(rec, payload)
if iscell(payload)
    for k = 1:numel(payload)
        rec = localScanForSources(rec, payload{k});
    end
    return;
end
if isstruct(payload)
    if isfield(payload, 'SignalSources')
        srcs = payload.SignalSources;
        if iscell(srcs)
            for k = 1:numel(srcs)
                rec = localScoreSource(rec, srcs{k});
            end
        else
            for k = 1:numel(srcs)
                rec = localScoreSource(rec, srcs(k));
            end
        end
    end
    if numel(payload) > 1
        for k = 1:numel(payload)
            rec = localScanForSources(rec, payload(k));
        end
    end
end
end


function rec = localScoreSource(rec, src)
% Phase 4 (audit §3.5 / §6 C8 / P4-followup-1): the v2 schema replaced
% the v1 top-level Realized / Planned blocks with the unified
% Truth.{Design, Execution, Measured} hierarchy. The baseline metric
% formerly published as `RealizedVsPlannedBwAbsRelDiffP95` is replaced
% by `ExecutionVsMeasuredBwAbsRelDiffP95`, the absolute relative gap between
% Truth.Execution.ModulatedBandwidthHz and
% Truth.Measured.SourcePlane.OccupiedBandwidthHz.
%
% WHAT THIS METRIC MEASURES NOW, AND WHAT IT CANNOT
% Both planes run ONE kernel (csrd.pipeline.measurement.occupiedBandwidthCore) on
% clean, per-emitter, per-antenna buffers; they differ only in WHICH buffer. So the
% only pipeline stage between them is PROPAGATION, and this metric is a
% fading/Doppler monitor plus the analysis bin grid. It structurally CANNOT detect
% a wrong bandwidth DEFINITION, because a wrong definition moves both planes
% together -- which is exactly how a -3 dB-down width shipped under the name
% "occupied bandwidth" for several releases while this gate stayed green.
% Definitional correctness is proved against external theory in
% tests/unit/OccupiedBandwidthAgainstTheoryTest.m, never here.
%
% Sources with NaN / empty / non-positive denominators are dropped from the sample
% (they cannot diagnose drift).
%
% THE LOW-SNR EXCLUSION IS GONE, and its removal is the point of this rework. It
% existed because the peak-relative OBW estimator broke once the noise floor came
% within 3 dB of the signal peak, so readings below ~6 dB SNR carried no
% engineering interpretation. Two things changed: that estimator was deleted, and
% the measurement moved AHEAD of noise injection, so neither plane sees noise at
% all. Keeping the exclusion would now remove precisely the cohort where a
% regression appears FIRST -- the historical defect lived at the bottom of the SNR
% range, and a gate blind there is worse than no gate.
%
% It costs nothing to include them: measured over 160 sources per cohort with the
% target SNR pinned, the gap is P95 = 0.000005 at both -10 dB and +25 dB, a ratio
% of 1.000 across a 35 dB swing (tests/regression/
% test_measured_plane_is_noise_independent.m). Before the reorder the same
% statistic read P95 = 1.979 for the low-SNR cohort.
%
% SnrFloorDb no longer EXCLUDES anything. It survives as a cohort LABEL: sources
% below it are additionally accumulated into the companion LowSnr percentiles, which
% are the instrument that showed the reorder worked (P95 1.979 before, 0.000005
% after). Those two uses were conflated in one if/else, so removing the exclusion by
% setting the floor to -Inf also emptied the companion sample and turned the
% instrument into a dead field. They are now independent: every source counts toward
% the gated percentile, and the sub-6 dB ones ALSO count toward the companion view.
SnrFloorDb = 6.0;

if ~isstruct(src), return; end
rec.NumSourcesTotal = rec.NumSourcesTotal + 1;

if ~isfield(src, 'Truth') || ~isstruct(src.Truth)
    return;
end
truth = src.Truth;

executionBwHz = NaN;
if isfield(truth, 'Execution') && isstruct(truth.Execution) ...
        && isfield(truth.Execution, 'ModulatedBandwidthHz') ...
        && isnumeric(truth.Execution.ModulatedBandwidthHz) ...
        && ~isempty(truth.Execution.ModulatedBandwidthHz) ...
        && isscalar(truth.Execution.ModulatedBandwidthHz)
    executionBwHz = double(truth.Execution.ModulatedBandwidthHz);
end

measuredBwHz = NaN;
if isfield(truth, 'Measured') && isstruct(truth.Measured) ...
        && isfield(truth.Measured, 'SourcePlane') ...
        && isstruct(truth.Measured.SourcePlane) ...
        && isfield(truth.Measured.SourcePlane, 'OccupiedBandwidthHz') ...
        && isnumeric(truth.Measured.SourcePlane.OccupiedBandwidthHz) ...
        && ~isempty(truth.Measured.SourcePlane.OccupiedBandwidthHz) ...
        && isscalar(truth.Measured.SourcePlane.OccupiedBandwidthHz)
    measuredBwHz = double(truth.Measured.SourcePlane.OccupiedBandwidthHz);
end

appliedSnrDb = NaN;
if isfield(truth, 'Execution') && isstruct(truth.Execution) ...
        && isfield(truth.Execution, 'AppliedSNRdB') ...
        && isnumeric(truth.Execution.AppliedSNRdB) ...
        && ~isempty(truth.Execution.AppliedSNRdB) ...
        && isscalar(truth.Execution.AppliedSNRdB)
    appliedSnrDb = double(truth.Execution.AppliedSNRdB);
end

if isfinite(executionBwHz) && executionBwHz > 0 && isfinite(measuredBwHz)
    diff = abs(measuredBwHz - executionBwHz) / executionBwHz;
    % EVERY source enters the gated sample. The old code sent sub-floor sources to
    % the companion sample INSTEAD, which made the gate structurally blind exactly
    % where the historical defect lived -- and blind by construction, so no amount
    % of sweeping would have caught it.
    rec.BwAbsRelDiffs(end + 1) = diff;
    if isfinite(appliedSnrDb) && appliedSnrDb < SnrFloorDb
        % ALSO record it in the low-SNR view. This is a second lens on the same
        % sample, not a partition: the count below is now "how many sources fell in
        % the low-SNR cohort", not "how many were excluded".
        rec.NumLowSnrExcluded = rec.NumLowSnrExcluded + 1;
        rec.BwAbsRelDiffsLowSnr(end + 1) = diff;
    end
end

if isfield(src, 'Status') && ischar(src.Status) ...
        && (strcmpi(src.Status, 'empty') || strcmpi(src.Status, 'no-signal'))
    rec.NumEmptySources = rec.NumEmptySources + 1;
end
end


% =========================================================================
function reason = localShortSkipReason(err)
if ~isempty(err.identifier)
    parts = strsplit(err.identifier, ':');
    reason = parts{end};
else
    reason = 'SkipScenario';
end
end


% =========================================================================
function metrics = localAggregateMetrics(rs)
n = numel(rs);
skipped = sum([rs.Skipped]);
chanFail = sum([rs.ChannelFailed]);

wallclocks = [rs.Wallclock];
wallclocks = wallclocks(~isnan(wallclocks));

logLines = [rs.LogLines];
logLines = logLines(~isnan(logLines));

annBytes = [rs.AnnotationBytes];
annBytes = annBytes(~isnan(annBytes));

bwAll = [];

bwLow = [];
for k = 1:n
    bwAll = [bwAll, rs(k).BwAbsRelDiffs]; %#ok<AGROW>
    bwLow = [bwLow, rs(k).BwAbsRelDiffsLowSnr]; %#ok<AGROW>
end

totalSrc = sum([rs.NumSourcesTotal]);
emptySrc = sum([rs.NumEmptySources]);

metrics = struct();
metrics.BlueprintAcceptanceRate          = (n - skipped) / max(n, 1);
metrics.ChannelFactoryFailureRate        = chanFail / max(n, 1);
metrics.WallclockSecPerScenarioP50       = localPercentile(wallclocks, 50);
metrics.WallclockSecPerScenarioP95       = localPercentile(wallclocks, 95);
metrics.LogLinesPerScenarioP50           = localPercentile(logLines, 50);
metrics.LogLinesPerScenarioP95           = localPercentile(logLines, 95);
metrics.AnnotationFileBytesP50           = localPercentile(annBytes, 50);
metrics.AnnotationFileBytesP95           = localPercentile(annBytes, 95);
% Phase 4 (audit §3.5 / §6 C8 / P4-followup-1): renamed metric.
% v1 RealizedVsPlannedBwAbsRelDiffP95 was retired together with the
% v1 schema; the v2 equivalent compares the schedule-set
% `Truth.Execution.ModulatedBandwidthHz` against the post-construction
% `Truth.Measured.SourcePlane.OccupiedBandwidthHz`.
metrics.ExecutionVsMeasuredBwAbsRelDiffP95 = localPercentile(bwAll, 95);
% Companion metrics over the SNR < SnrFloorDb cohort, which is now a SUBSET of the
% gated sample rather than the complement of it. Published, not gated: a low-SNR
% excursion should be visible without letting the bottom of the range set the
% threshold for the whole dataset.
% Historical note -- the gated metric formerly excluded the cohort that
% above excludes. These are the only numbers in the sweep that can observe a
% low-SNR measurement defect, so they are published for pre/post comparison.
metrics.ExecutionVsMeasuredBwAbsRelDiffLowSnrP50 = localPercentile(bwLow, 50);
metrics.ExecutionVsMeasuredBwAbsRelDiffLowSnrP95 = localPercentile(bwLow, 95);
if isempty(bwLow)
    metrics.ExecutionVsMeasuredBwAbsRelDiffLowSnrMax = NaN;
else
    metrics.ExecutionVsMeasuredBwAbsRelDiffLowSnrMax = max(bwLow);
end
metrics.EmptySignalSegmentRatio          = emptySrc / max(totalSrc, 1);

% Phase 2 (audit C7): blueprint resample percentile across scenarios
% whose annotations carried a numeric BlueprintResamples field.
resamples = [rs.BlueprintResamples];
resamples = resamples(~isnan(resamples));
metrics.BlueprintResamplesP50            = localPercentile(resamples, 50);
metrics.BlueprintResamplesP95            = localPercentile(resamples, 95);
metrics.BlueprintResamplesMax            = localMax(resamples);
% Coverage = fraction of scenarios that wrote a non-empty BlueprintHash
% AND a non-empty ValidatorVersion. Counting non-NaN BlueprintResamples
% would over-report because the schema defaults that field to 0 even
% when provenance was lost.
hashCovered = arrayfun(@(s) ~isempty(s.BlueprintHash) ...
    && ~isempty(s.ValidatorVersion), rs);
metrics.BlueprintProvenanceCoverage      = sum(hashCovered) / max(n, 1);

% --- diagnostics
diag = struct();
diag.NumScenarioSkipped = skipped;
reasons = {rs.SkipReason};
reasons = reasons(~cellfun(@isempty, reasons));
diag.NumScenarioSkippedByReason = localTallyReasons(reasons);
diag.NumScenarioRayTracingNoBuildingDataHit = ...
    sum(strcmp(reasons, 'NoBuildingData'));
diag.JsonNanCount      = sum([rs.JsonNanCount]);
diag.JsonInfinityCount = sum([rs.JsonInfinityCount]);
diag.SanitizeManifestSummary = struct( ...
    'TotalEntries', sum([rs.SanitizeManifestEntryCount]));
% Phase 4 (audit §3.5 / §6 C8): expose the low-SNR exclusion so the
% C8 gate is auditable. ExecutionVsMeasuredBwAbsRelDiff is computed
% only on sources whose AppliedSNRdB >= 6 dB; everything below is
% discarded because the receiver-side OBW estimator cannot resolve
% modulation edges below that floor (per Keysight 89600 / R&S FSV
% operator manuals' OBW reliability ceiling).
% Retains its historical name so the baseline schema is unchanged, but it now
% counts cohort MEMBERSHIP, not exclusion: nothing is excluded any more.
diag.NumLowSnrExcludedFromBwMetric = sum([rs.NumLowSnrExcluded]);
diag.NumBwSamplesUsedLowSnr = numel(bwLow);
diag.LowSnrFloorDb                 = 6.0;
diag.NumBwSamplesUsed              = numel(bwAll);
metrics.Diagnostics = diag;
end


% =========================================================================
function v = localPercentile(x, p)
if isempty(x)
    v = NaN;
    return;
end
v = prctile(x, p);
end


function v = localMax(x)
if isempty(x)
    v = NaN;
    return;
end
v = max(x);
end


% =========================================================================
function tally = localTallyReasons(reasons)
tally = struct();
unique_reasons = unique(reasons);
for k = 1:numel(unique_reasons)
    name = matlab.lang.makeValidName(unique_reasons{k});
    tally.(name) = sum(strcmp(reasons, unique_reasons{k}));
end
end


% =========================================================================
function payload = localBuildBaselinePayload(mode, numScenarios, plan, ...
        metrics, sweepDuration, schemaVersion, runRecovery)
[~, recipeFile, recipeExt] = fileparts(which('baseline_recipe_v0'));
recipeRel = sprintf('tests/regression/%s%s', recipeFile, recipeExt);

cohortNames = arrayfun(@(p) string(p.Cohort.Name), plan);
[uniqCohorts, ~, idx] = unique(cohortNames);
counts = accumarray(idx, 1);
recipeCounts = struct();
for k = 1:numel(uniqCohorts)
    name = matlab.lang.makeValidName(char(uniqCohorts(k)));
    recipeCounts.(name) = counts(k);
end

payload = struct( ...
    'SchemaVersion', schemaVersion, ...
    'GeneratedAt', char(datetime('now', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''', 'TimeZone', 'UTC')), ...
    'GeneratedBy', sprintf('tests/regression/test_baseline_sweep_200.m@%s', ...
        localGitShortSha()), ...
    'MatlabVersion', version(), ...
    'OS', computer('arch'), ...
    'Mode', mode, ...
    'SweepWallclockSec', sweepDuration, ...
    'RunRecovery', runRecovery, ...
    'Recipe', struct( ...
        'RecipeFile', recipeRel, ...
        'RecipeSha', localFileSha256(which('baseline_recipe_v0')), ...
        'NumScenarios', numScenarios, ...
        'RngSeed', 20260424, ...
        'Counts', recipeCounts), ...
    'ToolboxLevel', 'minimal', ...
    'LogPolicy', 'Standard', ...
    'Metrics', metrics);
end


function sha = localFileSha256(path)
if isempty(path) || ~exist(path, 'file')
    sha = 'unknown';
    return;
end
try
    md = java.security.MessageDigest.getInstance('SHA-256');
    fid = fopen(path, 'r');
    bytes = fread(fid, Inf, '*uint8');
    fclose(fid);
    md.update(bytes);
    digest = typecast(md.digest, 'uint8');
    sha = lower(reshape(dec2hex(digest, 2)', 1, []));
catch
    sha = 'sha-error';
end
end


function sha = localGitShortSha()
sha = 'no-git';
try
    [status, raw] = system('git rev-parse --short HEAD');
    if status == 0
        sha = strtrim(raw);
    end
catch
    sha = 'no-git';
end
end


% =========================================================================
function localAssertExitConditions(metrics, mode, numScenarios, ...
        baselineDir, baselinePath, schemaVersion)
% are owned by the unit/regression suites; here we enforce the
% baseline-level subset (C5/C6/C7).
diag = metrics.Diagnostics;
assert(diag.JsonNanCount == 0, ...
    'C6 violated: baseline JSON contains %d NaN literals.', ...
    diag.JsonNanCount);
assert(diag.JsonInfinityCount == 0, ...
    'C6 violated: baseline JSON contains %d Infinity literals.', ...
    diag.JsonInfinityCount);

% Phase 4 (audit §6 / P4-followup-1) the v1 RealizedVsPlannedBw metric
% is replaced by the v2-aligned ExecutionVsMeasured equivalent and the
% C8/C9 budgets shift to absorb the measurement-layer overhead.
requiredKeys = {'BlueprintAcceptanceRate', 'ChannelFactoryFailureRate', ...
    'WallclockSecPerScenarioP50', 'WallclockSecPerScenarioP95', ...
    'LogLinesPerScenarioP50', 'LogLinesPerScenarioP95', ...
    'AnnotationFileBytesP50', 'AnnotationFileBytesP95', ...
    'ExecutionVsMeasuredBwAbsRelDiffP95', 'EmptySignalSegmentRatio', ...
    'BlueprintResamplesP50', 'BlueprintResamplesP95', ...
    'BlueprintResamplesMax', 'BlueprintProvenanceCoverage'};
for k = 1:numel(requiredKeys)
    assert(isfield(metrics, requiredKeys{k}), ...
        'C5 violated: baseline metric %s missing.', requiredKeys{k});
end

% --- Phase 4 exit conditions (audit §17.6 / phase-4-measurement.md C8/C9)
%   Updated from Phase 3 to absorb the measurement-layer + Doppler costs:
%     BlueprintAcceptanceRate              >= 0.98  (Phase 3 unchanged)
%     BlueprintResamplesP95                <= 1     (Phase 3 unchanged)
%     EmptySignalSegmentRatio              <= 0.02  (Phase 3 unchanged)
%     ExecutionVsMeasuredBwAbsRelDiffP95   <  0.03  (now a PROPAGATION monitor
%                                                    over ALL SNR -- the sub-6 dB
%                                                    cohort is no longer excluded,
%                                                    only additionally reported;
%                                                    see localScoreSource. Measured
%                                                    0.0248 on a 4-scenario smoke
%                                                    sweep vs 0.0212 frozen, i.e.
%                                                    including the low-SNR cohort
%                                                    barely moves it, which is the
%                                                    reorder's whole point.)
%     WallclockSecPerScenarioP50           <= 23.0 s (Phase 3 19.95 s
%                                                    + ~15 % measurement
%                                                    overhead budget)
%     WallclockSecPerScenarioP95           <= 47.0 s (Phase 3 41.53 s
%                                                    + measured Phase 4
%                                                    overhead ~9.5 %
%                                                    + ~3 % environmental
%                                                    headroom; the
%                                                    pwelch-based
%                                                    measurement layer
%                                                    + Doppler shift
%                                                    + FramePlane cache
%                                                    landed at 45.47 s
%                                                    in baseline_v0,
%                                                    so the Phase 3
%                                                    +8 % planning
%                                                    budget had to be
%                                                    revised upward)
%     AnnotationFileBytesP50               <= 16384 B (12288 +
%                                                    ~33 % Truth subtree
%                                                    growth budget)
%
% Smoke runs (small N) only enforce the acceptance-rate floor because
% resample / wallclock / size percentiles on a tiny sample are too
% noisy; the canonical 210-scenario full sweep is the real gate.
assert(metrics.BlueprintAcceptanceRate >= 0.98, ...
    ['C8 violated: BlueprintAcceptanceRate=%.3f < 0.98 (Phase 4 ', ...
     'phase-4-measurement.md §6 C8).'], metrics.BlueprintAcceptanceRate);
isPhase5Final = strcmp(schemaVersion, 'baseline-v04') ...
    && strcmp(mode, 'full') && numScenarios >= 1000;

if strcmp(mode, 'full') && numScenarios >= 200
    if ~isnan(metrics.BlueprintResamplesP95)
        assert(metrics.BlueprintResamplesP95 <= 1, ...
            ['C8 violated: BlueprintResamplesP95=%.2f > 1 (Phase 4 ', ...
             '§6 C8).'], metrics.BlueprintResamplesP95);
    end
    assert(metrics.EmptySignalSegmentRatio <= 0.02, ...
        ['C8 violated: EmptySignalSegmentRatio=%.4f > 0.02 (Phase 4 ', ...
         '§6 C8).'], metrics.EmptySignalSegmentRatio);
    if ~isnan(metrics.ExecutionVsMeasuredBwAbsRelDiffP95)
        % The threshold is unchanged at 0.03, but it now polices propagation across
        % the WHOLE SNR range instead of the >= 6 dB cohort only. Measured
        % references for the two planes' agreement: AWGN max 0.0002, Rayleigh max
        % 0.0175, and a known Rician tail whose worst cluster is one FM emitter at
        % 12x-13.7x on 1024 active samples (mechanism still open, tracked in
        % csrd.test_support.measuredPlausibilityViolations). If that tail enters a
        % baseline sample it will trip this gate, which is the correct outcome:
        % it is a real, unexplained excursion, not measurement noise to be absorbed
        % by widening the bound.
        assert(metrics.ExecutionVsMeasuredBwAbsRelDiffP95 < 0.03, ...
            ['C8 violated: ExecutionVsMeasuredBwAbsRelDiffP95=%.4f >= 0.03 ', ...
             '(Phase 4 §6 C8 / P4-followup-1).'], ...
            metrics.ExecutionVsMeasuredBwAbsRelDiffP95);
    end
    if ~isPhase5Final && ~isnan(metrics.WallclockSecPerScenarioP50)
        assert(metrics.WallclockSecPerScenarioP50 <= 23.0, ...
            ['C9 violated: WallclockSecPerScenarioP50=%.2fs > 23.0s ', ...
             '(Phase 4 §6 C9).'], metrics.WallclockSecPerScenarioP50);
    end
    if ~isPhase5Final && ~isnan(metrics.WallclockSecPerScenarioP95)
        assert(metrics.WallclockSecPerScenarioP95 <= 47.0, ...
            ['C9 violated: WallclockSecPerScenarioP95=%.2fs > 47.0s ', ...
             '(Phase 4 §6 C9).'], metrics.WallclockSecPerScenarioP95);
    end
    if isPhase5Final
        fprintf(['  Phase 5 diagnostic: WallclockSecPerScenarioP50=%.2fs, ', ...
            'P95=%.2fs (operator MC wallclock is recorded, not gated).\n'], ...
            metrics.WallclockSecPerScenarioP50, ...
            metrics.WallclockSecPerScenarioP95);
    end
    if ~isnan(metrics.AnnotationFileBytesP50)
        assert(metrics.AnnotationFileBytesP50 <= 16384, ...
            ['C9 violated: AnnotationFileBytesP50=%.0f B > 16384 B ', ...
             '(Phase 4 §6 C9).'], metrics.AnnotationFileBytesP50);
    end
end

if strcmp(mode, 'full') && numScenarios >= 200
    canonicalPath = fullfile(baselineDir, '2026-04-baseline-v0.json');
    if exist(canonicalPath, 'file') && ~strcmp(canonicalPath, baselinePath)
        if isPhase5Final
            fprintf(['  Phase 5 diagnostic: prior baseline drift is recorded ', ...
                'for review, not gated against 2026-04-baseline-v0.json.\n']);
            return;
        end
        % Compare against prior canonical baseline, allow 10% drift.
        prior = jsondecode(fileread(canonicalPath));
        for k = 1:numel(requiredKeys)
            key = requiredKeys{k};
            if isfield(prior, 'Metrics') && isfield(prior.Metrics, key)
                priorVal = prior.Metrics.(key);
                newVal = metrics.(key);
                if isnumeric(priorVal) && priorVal > 0
                    drift = abs(newVal - priorVal) / priorVal;
                    assert(drift <= 0.10, ...
                        ['Baseline drift on %s: prior=%g new=%g ', ...
                        '(drift %.1f%% > 10%%).'], ...
                        key, priorVal, newVal, drift * 100);
                end
            end
        end
    end
end
end
