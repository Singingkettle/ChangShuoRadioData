function summary = run_phase25_deep_audit(varargin)
%RUN_PHASE25_DEEP_AUDIT Full-chain correctness and performance audit.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.

p = inputParser();
p.FunctionName = 'run_phase25_deep_audit';
addParameter(p, 'AuditDirectory', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'PerformanceDirectory', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'RunStaticAudit', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'RunTests', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'RunDefaultSimulation', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'RunOsmLargeMapSmoke', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'RunOsmSpecificMapSmoke', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'RunFullCoverageDryRun', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'RunPhase16DryRun', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'RunStress', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'StressCount', 100, @localPositiveInteger);
addParameter(p, 'RunNightly', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'ProfileDefaultSimulation', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'MaxHours', 8, @localPositiveScalar);
addParameter(p, 'LogRoots', {}, @(x) iscell(x) || ischar(x) || isstring(x));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

projectRoot = localProjectRoot();
addpath(projectRoot);
addpath(fullfile(projectRoot, 'tools'));
addpath(fullfile(projectRoot, 'tools', 'performance'));

auditDir = localResolveArtifactDirectory(projectRoot, p.Results.AuditDirectory, ...
    fullfile(projectRoot, 'artifacts', 'audits', 'phase25'));
perfDir = localResolveArtifactDirectory(projectRoot, p.Results.PerformanceDirectory, ...
    fullfile(projectRoot, 'artifacts', 'performance', 'phase25'));
localEnsureDirectory(auditDir);
localEnsureDirectory(perfDir);

runOptions = localResolveRunOptions(p.Results);
deadline = tic;
auditStartDatenum = now;

summary = struct();
summary.Schema = 'csrd.phase25.deep-audit.v1';
summary.GeneratedAtUtc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
summary.ProjectRoot = projectRoot;
summary.AuditDirectory = auditDir;
summary.PerformanceDirectory = perfDir;
summary.RunOptions = runOptions;
summary.References = localOfficialReferences();
summary.Git = localGitSnapshot(projectRoot);
summary.ConfigMatrix = localConfigMatrix(projectRoot);
summary.TestMatrix = localTestMatrix(projectRoot);
summary.StaticAudit = localMaybeRun(runOptions.RunStaticAudit, ...
    @() localStaticAudit(projectRoot));
summary.Runs = struct();

summary.Runs.FullCoverageDryRun = localMaybeRunWithDeadline( ...
    runOptions.RunFullCoverageDryRun, deadline, runOptions.MaxSeconds, ...
    @() localRunCoverageDryRun(projectRoot, ...
        'csrd2025/csrd2025_full_coverage_validation.m'));
summary.Runs.Phase16DryRun = localMaybeRunWithDeadline( ...
    runOptions.RunPhase16DryRun, deadline, runOptions.MaxSeconds, ...
    @() localRunCoverageDryRun(projectRoot, ...
        'csrd2025/csrd2025_osm_raytracing_validation.m'));
summary.Runs.CorrectnessTests = localMaybeRunWithDeadline( ...
    runOptions.RunTests, deadline, runOptions.MaxSeconds, ...
    @() localRunCorrectnessTests(projectRoot));
summary.Runs.DefaultSimulation = localMaybeRunWithDeadline( ...
    runOptions.RunDefaultSimulation, deadline, runOptions.MaxSeconds, ...
    @() localRunSimulationProbe(projectRoot, perfDir, ...
        'csrd2025/csrd2025.m', 'default', ...
        runOptions.ProfileDefaultSimulation));
summary.Runs.OsmSpecificMapSmoke = localMaybeRunWithDeadline( ...
    runOptions.RunOsmSpecificMapSmoke, deadline, runOptions.MaxSeconds, ...
    @() localRunSimulationProbe(projectRoot, perfDir, ...
        'csrd2025/csrd2025_osm_large_map_validation.m', ...
        'osm_specific_map', false));
summary.Runs.Stress = localMaybeRunWithDeadline( ...
    runOptions.RunStress, deadline, runOptions.MaxSeconds, ...
    @() localRunStress(projectRoot, perfDir, runOptions.StressCount, ...
        deadline, runOptions.MaxSeconds));

summary.LogAudit = localLogAudit(projectRoot, ...
    localResolveLogRoots(projectRoot, p.Results.LogRoots, summary.Runs));
summary.PerformanceTraceInventory = localPerformanceTraceInventory( ...
    {perfDir, fullfile(projectRoot, 'artifacts', 'performance')}, ...
    auditStartDatenum);
summary.Findings = localBuildFindings(summary);
summary.HasBlockerFindings = any(strcmp({summary.Findings.Severity}, 'Blocker'));
summary.Success = localAuditSuccess(summary);
summary.ElapsedSec = toc(deadline);

ts = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
summary.MatPath = fullfile(auditDir, ...
    sprintf('phase25-deep-audit-summary-%s.mat', ts));
summary.JsonPath = fullfile(auditDir, ...
    sprintf('phase25-deep-audit-summary-%s.json', ts));
summary.MarkdownPath = fullfile(auditDir, ...
    sprintf('phase25-deep-audit-summary-%s.md', ts));
summary.ReportMarkdown = summary.MarkdownPath;
save(summary.MatPath, 'summary');
localWriteJson(summary.JsonPath, summary);
localWriteMarkdown(summary.MarkdownPath, summary);

if p.Results.Verbose
    localPrintSummary(summary);
end
end

function options = localResolveRunOptions(input)
    % localResolveRunOptions - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
options = struct();
options.RunStaticAudit = input.RunStaticAudit;
options.RunTests = input.RunTests;
options.RunDefaultSimulation = input.RunDefaultSimulation;
options.RunOsmSpecificMapSmoke = input.RunOsmSpecificMapSmoke || ...
    input.RunOsmLargeMapSmoke;
options.RunFullCoverageDryRun = input.RunFullCoverageDryRun;
options.RunPhase16DryRun = input.RunPhase16DryRun;
options.RunStress = input.RunStress;
options.StressCount = input.StressCount;
options.ProfileDefaultSimulation = input.ProfileDefaultSimulation;
options.MaxHours = input.MaxHours;
options.MaxSeconds = input.MaxHours * 3600;
if input.RunNightly
    options.RunTests = true;
    options.RunDefaultSimulation = true;
    options.RunOsmSpecificMapSmoke = true;
    options.RunFullCoverageDryRun = true;
    options.RunPhase16DryRun = true;
    options.RunStress = true;
    options.ProfileDefaultSimulation = true;
end
end

function refs = localOfficialReferences()
    % localOfficialReferences - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
refs = struct( ...
    'MatlabPerformance', 'https://www.mathworks.com/help/matlab/matlab_prog/techniques-for-improving-performance.html', ...
    'MatlabProfiler', 'https://www.mathworks.com/help/matlab/matlab_prog/profiling-for-improving-performance.html', ...
    'Preallocation', 'https://www.mathworks.com/help/matlab/matlab_prog/preallocating-arrays.html', ...
    'SystemObjects', 'https://www.mathworks.com/help/matlab/matlab_prog/best-practices-for-defining-system-objects.html', ...
    'Parfor', 'https://www.mathworks.com/help/parallel-computing/decide-when-to-use-parfor.html', ...
    'Raytrace', 'https://www.mathworks.com/help/comm/ref/txsite.raytrace.html', ...
    'Siteviewer', 'https://www.mathworks.com/help/comm/ref/siteviewer.html');
end

function git = localGitSnapshot(projectRoot)
    % localGitSnapshot - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
git = struct('Available', false, 'Branch', '', 'StatusShort', '', ...
    'DiffStat', '', 'Error', '');
[status, branch] = system('git branch --show-current');
if status ~= 0
    git.Error = strtrim(branch);
    return;
end
git.Available = true;
git.Branch = strtrim(branch);
git.StatusShort = localSystemText(projectRoot, 'git status --short');
git.DiffStat = localSystemText(projectRoot, 'git diff --stat');
end

function matrix = localConfigMatrix(projectRoot)
    % localConfigMatrix - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
files = dir(fullfile(projectRoot, 'config', 'csrd2025', '*.m'));
matrix = repmat(localEmptyConfigRecord(), numel(files), 1);
for idx = 1:numel(files)
    rel = fullfile('csrd2025', files(idx).name);
    rec = localEmptyConfigRecord();
    rec.Name = files(idx).name;
    rec.Path = rel;
    try
        cfg = csrd.runtime.config_loader(rel);
        rec.Loaded = true;
        rec.RunnerNumScenarios = localGetNested(cfg, {'Runner', 'NumScenarios'}, NaN);
        scenarioPlan = csrd.pipeline.runtime.buildScenarioPlan( ...
            cfg.RuntimePlan, cfg.Factories.Scenario, ...
            struct('ScenarioId', 1, 'RandomSeed', cfg.Runner.RandomSeed));
        rec.FramePolicy = cfg.RuntimePlan.FramePolicy;
        rec.FrameNumSamples = scenarioPlan.Frame.FrameNumSamples;
        rec.SampleRateHz = scenarioPlan.Frame.SampleRateHz;
        rec.FrameDurationSec = scenarioPlan.Frame.FrameDurationSec;
        rec.NumFramesPerScenario = scenarioPlan.Frame.NumFramesPerScenario;
        rec.ObservationDurationSec = scenarioPlan.Frame.ObservationDurationSec;
        rec.MapTypes = localStringList(localGetNested(cfg, ...
            {'Factories', 'Scenario', 'PhysicalEnvironment', 'Map', 'Types'}, {}));
        rec.OSMSpecificFile = char(string(localGetNested(cfg, ...
            {'Factories', 'Scenario', 'PhysicalEnvironment', 'Map', 'OSM', 'SpecificFile'}, '')));
        rec.OSMFilePattern = char(string(localGetNested(cfg, ...
            {'Factories', 'Scenario', 'PhysicalEnvironment', 'Map', 'OSM', 'FilePattern'}, '*.osm')));
        rec.RegulatoryEnabled = logical(localGetNested(cfg, ...
            {'Factories', 'Scenario', 'CommunicationBehavior', 'Regulatory', 'Enable'}, false));
    catch ME
        rec.Error = sprintf('%s: %s', ME.identifier, ME.message);
    end
    matrix(idx) = rec;
end
end

function rec = localEmptyConfigRecord()
    % localEmptyConfigRecord - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
rec = struct('Name', '', 'Path', '', 'Loaded', false, 'Error', '', ...
    'RunnerNumScenarios', NaN, 'FrameNumSamples', NaN, ...
    'SampleRateHz', NaN, 'FrameDurationSec', NaN, ...
    'NumFramesPerScenario', NaN, 'ObservationDurationSec', NaN, ...
    'MapTypes', '', 'OSMSpecificFile', '', 'OSMFilePattern', '', ...
    'RegulatoryEnabled', false);
end

function matrix = localTestMatrix(projectRoot)
    % localTestMatrix - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
roots = {fullfile(projectRoot, 'tests', 'unit'), ...
    fullfile(projectRoot, 'tests', 'regression')};
records = repmat(struct('Suite', '', 'Name', '', 'Path', ''), 0, 1);
for rootIdx = 1:numel(roots)
    if ~isfolder(roots{rootIdx})
        continue;
    end
    files = dir(fullfile(roots{rootIdx}, '*.m'));
    [~, suite] = fileparts(roots{rootIdx});
    for idx = 1:numel(files)
        records(end + 1) = struct( ... %#ok<AGROW>
            'Suite', suite, ...
            'Name', files(idx).name, ...
            'Path', localRelativePath(projectRoot, ...
                fullfile(files(idx).folder, files(idx).name)));
    end
end
matrix = records;
end

function audit = localStaticAudit(projectRoot)
    % localStaticAudit - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
scanRoots = {'+csrd', 'config', 'tools', 'tests'};
files = localCollectMatlabFiles(projectRoot, scanRoots);
rules = localStaticRules();
findings = repmat(localEmptyFinding(), 0, 1);
for fileIdx = 1:numel(files)
    relPath = localRelativePath(projectRoot, files{fileIdx});
    if localIsGeneratedOrIgnored(relPath)
        continue;
    end
    text = fileread(files{fileIdx});
    for ruleIdx = 1:numel(rules)
        if ~localPathMatchesScope(relPath, rules(ruleIdx).Scope)
            continue;
        end
        matches = regexp(text, rules(ruleIdx).Pattern, 'lineanchors');
        if isempty(matches)
            continue;
        end
        finding = localFinding(rules(ruleIdx).Severity, ...
            rules(ruleIdx).Category, rules(ruleIdx).Code, ...
            relPath, rules(ruleIdx).Message, rules(ruleIdx).Recommendation);
        finding.Evidence = sprintf('Pattern: %s', rules(ruleIdx).Pattern);
        findings(end + 1) = finding; %#ok<AGROW>
    end
end
audit = struct();
audit.Schema = 'csrd.phase25.static-audit.v1';
audit.FilesScanned = numel(files);
audit.Rules = rules;
audit.Findings = findings;
audit.NumFindings = numel(findings);
audit.NumBlockers = sum(strcmp({findings.Severity}, 'Blocker'));
audit.NumCorrectness = sum(strcmp({findings.Severity}, 'Correctness'));
audit.NumPerformance = sum(strcmp({findings.Severity}, 'Performance'));
end

function rules = localStaticRules()
    % localStaticRules - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
rules = [ ...
    localRule('Correctness', 'RuntimeFallback', 'FRAME_WINDOW_WHOLE_OBS', ...
        'FrameWindow\\s*=\\s*\\[\\s*0\\s*,\\s*ObservationDuration\\s*\\]', ...
        {'+csrd'}, ...
        'Production code appears to use the whole observation duration as a frame window.', ...
        'Derive the absolute per-frame FrameWindow from FrameNumSamples/SampleRate and clip ActiveIntervals.'), ...
    localRule('Correctness', 'RuntimeFallback', 'MESSAGE_LENGTH_1024', ...
        'messageLength\\s*=\\s*1024', {'+csrd'}, ...
        'Message length fallback to 1024 was found.', ...
        'Require per-segment Placement.Duration-derived message length.'), ...
    localRule('Correctness', 'RuntimeFallback', 'SYMBOL_RATE_100K', ...
        'symbolRate\\s*=\\s*100e3', {'+csrd'}, ...
        'Symbol-rate fallback to 100 kHz was found.', ...
        'Require explicit symbol rate from scenario/modulation plan.'), ...
    localRule('Correctness', 'RuntimeFallback', 'CHANNEL_SEED_FRAME_FALLBACK', ...
        'frame_\\%|frame_', {'+csrd/+factories/ChannelFactory.m'}, ...
        'Channel seed frame fallback candidate was found.', ...
        'Production channel seed must use non-empty BurstId.'), ...
    localRule('Correctness', 'Measurement', 'MEASUREMENT_NAN_SILENT', ...
        'NaN', {'+csrd/+pipeline/+measurement', '+csrd/+core'}, ...
        'Measurement path writes NaN; verify NoSignal status or fail-fast behavior.', ...
        'Live-source measurement failures should throw CSRD:Measurement:*.'), ...
    localRule('Performance', 'HotPath', 'SITEVIEWER_CONSTRUCT', ...
        'siteviewer\\s*\\(', {'+csrd'}, ...
        'siteviewer construction appears in production code.', ...
        'Ensure it is process/scenario cached and never created by metadata-only paths.'), ...
    localRule('Performance', 'HotPath', 'RAYTRACE_CALL', ...
        'raytrace\\s*\\(', {'+csrd'}, ...
        'raytrace call appears in production code.', ...
        'Ensure Tx x Rx batching and ray-set cache are used for stable links.'), ...
    localRule('Performance', 'HotPath', 'UNCONDITIONAL_DBSTACK', ...
        'dbstack\\s*\\(', {'+csrd', 'tools'}, ...
        'dbstack is expensive on logger hot paths.', ...
        'Only call dbstack after log-level filtering.'), ...
    localRule('Performance', 'HotPath', 'JSON_IN_LOOP_CANDIDATE', ...
        'for\\s+.*\\n[\\s\\S]{0,400}jsonencode\\s*\\(', {'+csrd', 'tools'}, ...
        'jsonencode appears near a loop.', ...
        'Move JSON encoding outside frame/source hot loops when possible.'), ...
    localRule('Cleanup', 'DynamicGrowth', 'END_PLUS_ONE', ...
        'end\\s*\\+\\s*1', {'+csrd'}, ...
        'Dynamic array/cell growth candidate was found.', ...
        'Preallocate when loop bounds are known or record why growth is bounded.'), ...
    localRule('Correctness', 'SpatialUnits', 'LAT_LONG_POSITION_MIX', ...
        'Latitude|Longitude|GeoPositionDeg|PositionUnit', {'+csrd'}, ...
        'Spatial unit related code requires review for meter/degree separation.', ...
        'RayTracing should consume GeoPositionDeg; distance/Doppler should consume meter Position.') ...
    ];
end

function rule = localRule(severity, category, code, pattern, scope, message, recommendation)
    % localRule - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
rule = struct('Severity', severity, 'Category', category, 'Code', code, ...
    'Pattern', pattern, 'Scope', {scope}, 'Message', message, ...
    'Recommendation', recommendation);
end

function logAudit = localLogAudit(projectRoot, logRoots)
    % localLogAudit - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
roots = localNormalizeRoots(logRoots);
records = repmat(localEmptyLogRecord(), 0, 1);
for idx = 1:numel(roots)
    if ~isfolder(roots{idx})
        continue;
    end
    files = dir(fullfile(roots{idx}, '**', '*.log'));
    files = [files; dir(fullfile(roots{idx}, '**', '*.txt'))]; %#ok<AGROW>
    [~, order] = sort([files.datenum], 'descend');
    files = files(order(1:min(numel(files), 50)));
    for fileIdx = 1:numel(files)
        pathText = fullfile(files(fileIdx).folder, files(fileIdx).name);
        text = localReadTextLimited(pathText, 2e6);
        rec = localClassifyLogText(text);
        rec.Path = localRelativePath(projectRoot, pathText);
        rec.BytesRead = strlength(text);
        records(end + 1) = rec; %#ok<AGROW>
    end
end
logAudit = struct();
logAudit.FilesScanned = numel(records);
logAudit.Records = records;
logAudit.TotalErrors = sum([records.Errors]);
logAudit.TotalWarnings = sum([records.Warnings]);
logAudit.TotalFrameContract = sum([records.FrameContract]);
logAudit.TotalMeasurement = sum([records.Measurement]);
logAudit.TotalRayTracing = sum([records.RayTracing]);
logAudit.TotalFrequencyOverlap = sum([records.FrequencyOverlap]);
end

function roots = localResolveLogRoots(projectRoot, requestedRoots, runs)
    % localResolveLogRoots - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
roots = localNormalizeRoots(requestedRoots);
if ~isempty(roots)
    return;
end
roots = {};
names = fieldnames(runs);
for idx = 1:numel(names)
    run = runs.(names{idx});
    if ~isstruct(run) || ~isfield(run, 'Ran') || ~run.Ran || ...
            ~isfield(run, 'Detail')
        continue;
    end
    if isfield(run.Detail, 'OutputDirectory') && ...
            ~isempty(run.Detail.OutputDirectory)
        roots{end + 1} = run.Detail.OutputDirectory; %#ok<AGROW>
    end
    if isfield(run.Detail, 'Records')
        records = run.Detail.Records;
        for recIdx = 1:numel(records)
            if isfield(records(recIdx), 'OutputDirectory') && ...
                    ~isempty(records(recIdx).OutputDirectory)
                roots{end + 1} = records(recIdx).OutputDirectory; %#ok<AGROW>
            end
        end
    end
end
roots = unique(roots, 'stable');
for idx = 1:numel(roots)
    if ~isfolder(roots{idx})
        roots{idx} = fullfile(projectRoot, 'data', roots{idx});
    end
end
roots = roots(cellfun(@isfolder, roots));
end

function rec = localClassifyLogText(text)
    % localClassifyLogText - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
rec = localEmptyLogRecord();
rec.Errors = localCount(text, 'ERROR');
rec.Warnings = localCount(text, 'WARNING');
rec.FrameContract = localCount(text, 'FrameWindow resolves') + ...
    localCount(text, 'FrameNumSamples');
rec.Measurement = localCount(text, 'CSRD:Measurement') + ...
    localCount(text, 'detectBurstEnvelope') + localCount(text, 'Measurement failed');
rec.RayTracing = localCount(text, 'RayTracing failed') + ...
    localCount(text, 'raytrace') + localCount(text, 'siteviewer');
rec.FrequencyOverlap = localCount(text, 'Insufficient bandwidth') + ...
    localCount(text, 'overlapping allocation');
rec.Annotation = localCount(text, 'CSRD:Annotation') + ...
    localCount(text, 'annotation');
rec.Construction = localCount(text, 'CSRD:Construction') + ...
    localCount(text, 'Construction');
end

function rec = localEmptyLogRecord()
    % localEmptyLogRecord - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
rec = struct('Path', '', 'BytesRead', 0, 'Errors', 0, 'Warnings', 0, ...
    'FrameContract', 0, 'Measurement', 0, 'RayTracing', 0, ...
    'FrequencyOverlap', 0, 'Annotation', 0, 'Construction', 0);
end

function inventory = localPerformanceTraceInventory(roots, minDatenum)
    % localPerformanceTraceInventory - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if nargin < 2 || isempty(minDatenum)
    minDatenum = -Inf;
end
records = repmat(struct('Path', '', 'FoundSummary', false, ...
    'SuccessfulScenarios', NaN, 'FailedScenarios', NaN, ...
    'SkippedScenarios', NaN, 'TotalElapsedSec', NaN, ...
    'TopRuntimeEvent', '', 'TopRuntimeEventSec', NaN), 0, 1);
seen = strings(0, 1);
for rootIdx = 1:numel(roots)
    root = roots{rootIdx};
    if ~isfolder(root)
        continue;
    end
    files = dir(fullfile(root, '**', 'phase*-stage-timing-worker*.mat'));
    files = [files; dir(fullfile(root, '**', 'phase21-stage-timing-worker*.mat'))]; %#ok<AGROW>
    files = files([files.datenum] >= minDatenum);
    if isempty(files)
        continue;
    end
    [~, order] = sort([files.datenum], 'descend');
    files = files(order(1:min(numel(files), 30)));
    for idx = 1:numel(files)
        pathText = fullfile(files(idx).folder, files(idx).name);
        if any(seen == string(pathText))
            continue;
        end
        seen(end + 1) = string(pathText); %#ok<AGROW>
        rec = localPerformanceTraceRecord(pathText);
        records(end + 1) = rec; %#ok<AGROW>
    end
end
inventory = struct('FilesScanned', numel(records), 'Records', records);
end

function rec = localPerformanceTraceRecord(pathText)
    % localPerformanceTraceRecord - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
rec = struct('Path', pathText, 'FoundSummary', false, ...
    'SuccessfulScenarios', NaN, 'FailedScenarios', NaN, ...
    'SkippedScenarios', NaN, 'TotalElapsedSec', NaN, ...
    'TopRuntimeEvent', '', 'TopRuntimeEventSec', NaN);
try
    loaded = load(pathText, 'performanceTrace');
    if ~isfield(loaded, 'performanceTrace')
        return;
    end
    tr = loaded.performanceTrace;
    if isfield(tr, 'Summary')
        rec.FoundSummary = true;
        rec.SuccessfulScenarios = localGet(tr.Summary, 'SuccessfulScenarios', NaN);
        rec.FailedScenarios = localGet(tr.Summary, 'FailedScenarios', NaN);
        rec.SkippedScenarios = localGet(tr.Summary, 'SkippedScenarios', NaN);
        rec.TotalElapsedSec = localGet(tr.Summary, 'TotalElapsedSec', NaN);
    end
    if isfield(tr, 'RuntimePerformance') && ...
            isfield(tr.RuntimePerformance, 'Events') && ...
            ~isempty(tr.RuntimePerformance.Events)
        events = tr.RuntimePerformance.Events;
        elapsed = [events.ElapsedSec];
        [maxElapsed, idx] = max(elapsed);
        rec.TopRuntimeEvent = events(idx).Name;
        rec.TopRuntimeEventSec = maxElapsed;
    end
catch
end
end

function run = localMaybeRun(shouldRun, runner)
    % localMaybeRun - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
run = struct('Ran', false, 'Status', 'NotRun', 'ElapsedSec', NaN, ...
    'ErrorIdentifier', '', 'ErrorMessage', '', 'Detail', struct());
if ~shouldRun
    return;
end
run.Ran = true;
t = tic;
try
    run.Detail = runner();
    run.Status = 'Passed';
catch ME
    run.Status = 'Failed';
    run.ErrorIdentifier = ME.identifier;
    run.ErrorMessage = ME.message;
end
run.ElapsedSec = toc(t);
end

function run = localMaybeRunWithDeadline(shouldRun, deadline, maxSeconds, runner)
    % localMaybeRunWithDeadline - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
run = localMaybeRun(false, runner);
if ~shouldRun
    return;
end
if toc(deadline) >= maxSeconds
    run.Ran = false;
    run.Status = 'Skipped';
    run.ErrorIdentifier = 'CSRD:Phase25:DeadlineReached';
    run.ErrorMessage = 'Skipped because the Phase 25 audit deadline was reached.';
    return;
end
run = localMaybeRun(true, runner);
end

function detail = localRunCoverageDryRun(projectRoot, configPath)
    % localRunCoverageDryRun - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
cfg = csrd.runtime.config_loader(configPath);
detail = csrd.support.validation.runFullCoverageValidation( ...
    cfg, configPath, projectRoot, 1, 1, 'DryRun', true);
end

function detail = localRunCorrectnessTests(projectRoot)
    % localRunCorrectnessTests - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
testFiles = { ...
    fullfile(projectRoot, 'tests', 'unit', 'FrameRuntimeContractTest.m'), ...
    fullfile(projectRoot, 'tests', 'unit', 'RuntimeTruthContractTest.m'), ...
    fullfile(projectRoot, 'tests', 'unit', 'ScenarioFactoryOsmSelectionContractTest.m'), ...
    fullfile(projectRoot, 'tests', 'unit', 'FrequencyAllocationOverlapContractTest.m'), ...
    fullfile(projectRoot, 'tests', 'unit', 'OsmMapResourceCacheContractTest.m'), ...
    fullfile(projectRoot, 'tests', 'unit', 'RayTracingBatchEquivalenceTest.m'), ...
    fullfile(projectRoot, 'tests', 'unit', 'TRFSimulatorTest.m'), ...
    fullfile(projectRoot, 'tests', 'unit', 'ObwActualShortSignalContractTest.m'), ...
    fullfile(projectRoot, 'tests', 'unit', 'BuildSourceAnnotationV2Test.m'), ...
    fullfile(projectRoot, 'tests', 'unit', 'MeasurementCompletenessHookTest.m')};
testFiles = testFiles(cellfun(@isfile, testFiles));
results = runtests(testFiles);
detail = struct();
detail.NumResults = numel(results);
detail.NumFailed = sum([results.Failed]);
detail.NumIncomplete = sum([results.Incomplete]);
detail.Passed = detail.NumFailed == 0 && detail.NumIncomplete == 0;
assert(detail.Passed, 'CSRD:Phase25:CorrectnessTestsFailed', ...
    'Phase 25 correctness suite failed: %d failed, %d incomplete.', ...
    detail.NumFailed, detail.NumIncomplete);
end

function detail = localRunSimulationProbe(projectRoot, perfDir, baseConfig, tag, profileEnabled)
    % localRunSimulationProbe - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
[configPath, outputDir] = localWriteGeneratedConfig(projectRoot, perfDir, ...
    baseConfig, tag, [], []);
oldPath = path;
cleanupPath = onCleanup(@() path(oldPath)); %#ok<NASGU>
addpath(fullfile(projectRoot, 'tools'));
if profileEnabled
    profile clear;
    profile on;
end
try
    simulation(1, 1, configPath);
    if profileEnabled
        profileInfo = profile('info');
        profile off;
    else
        profileInfo = struct();
    end
catch ME
    if profileEnabled
        profile off;
    end
    rethrow(ME);
end
perf = localLatestPerformanceTrace(perfDir);
annotationAudit = localAuditAnnotationDirectory(outputDir);
localAssertAnnotationAudit(annotationAudit, tag);
detail = struct('BaseConfig', baseConfig, 'GeneratedConfig', configPath, ...
    'Tag', tag, 'OutputDirectory', outputDir, ...
    'PerformanceTrace', perf, 'AnnotationAudit', annotationAudit);
if profileEnabled
    detail.ProfileTopFunctions = localProfileTop(profileInfo, 20);
end
localAssertNoHardFailures(perf, tag);
end

function detail = localRunStress(projectRoot, perfDir, count, deadline, maxSeconds)
    % localRunStress - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
records = repmat(struct('Index', 0, 'Seed', 0, 'Status', '', ...
    'ElapsedSec', NaN, 'GeneratedConfig', '', 'OutputDirectory', '', ...
    'AnnotationFiles', NaN, 'InvalidMeasuredAnnotations', NaN, ...
    'ErrorIdentifier', '', 'ErrorMessage', ''), count, 1);
passed = 0;
failed = 0;
for idx = 1:count
    if toc(deadline) >= maxSeconds
        break;
    end
    seed = 20260500 + idx;
    tag = sprintf('stress_%03d', idx);
    [configPath, outputDir] = localWriteGeneratedConfig(projectRoot, perfDir, ...
        'csrd2025/csrd2025.m', tag, 1, seed);
    records(idx).Index = idx;
    records(idx).Seed = seed;
    records(idx).GeneratedConfig = configPath;
    records(idx).OutputDirectory = outputDir;
    t = tic;
    try
        simulation(1, 1, configPath);
        perf = localLatestPerformanceTrace(perfDir);
        localAssertNoHardFailures(perf, tag);
        annotationAudit = localAuditAnnotationDirectory(outputDir);
        records(idx).AnnotationFiles = annotationAudit.FileCount;
        records(idx).InvalidMeasuredAnnotations = ...
            annotationAudit.InvalidMeasuredCount;
        localAssertAnnotationAudit(annotationAudit, tag);
        records(idx).Status = 'Passed';
        passed = passed + 1;
    catch ME
        records(idx).Status = 'Failed';
        records(idx).ErrorIdentifier = ME.identifier;
        records(idx).ErrorMessage = ME.message;
        failed = failed + 1;
        break;
    end
    records(idx).ElapsedSec = toc(t);
end
detail = struct('RequestedCount', count, 'Passed', passed, ...
    'Failed', failed, 'Records', records);
if failed > 0
    error('CSRD:Phase25:StressFailed', ...
        'Phase 25 stress run failed at the first failing seed.');
end
end

function [configPath, outputDir] = localWriteGeneratedConfig(projectRoot, perfDir, baseConfig, tag, numScenarios, seed)
    % localWriteGeneratedConfig - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
configDir = fullfile(perfDir, 'generated_configs');
localEnsureDirectory(configDir);
safeTag = regexprep(char(string(tag)), '[^A-Za-z0-9_]', '_');
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'));
functionName = sprintf('phase25_%s_%s', safeTag, stamp);
outputName = sprintf('CSRD2025_phase25_%s_%s', safeTag, stamp);
outputDir = fullfile(projectRoot, 'data', outputName);
configPath = fullfile(configDir, [functionName, '.m']);
fid = fopen(configPath, 'w');
if fid == -1
    error('CSRD:Phase25:ConfigOpenFailed', ...
        'Could not create audit config: %s', configPath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'function config = %s()\n', functionName);
fprintf(fid, 'config.baseConfigs = {''%s''};\n', localEscape(baseConfig));
if ~isempty(numScenarios)
    fprintf(fid, 'config.Runner.NumScenarios = %d;\n', numScenarios);
end
if ~isempty(seed)
    fprintf(fid, 'config.Runner.RandomSeed = %d;\n', seed);
end
fprintf(fid, 'config.Runner.Performance.EnableStageTiming = true;\n');
fprintf(fid, 'config.Runner.Performance.ArtifactDirectory = ''%s'';\n', ...
    localEscape(perfDir));
fprintf(fid, 'config.Runner.Data.OutputDirectory = ''%s'';\n', ...
    localEscape(outputName));
fprintf(fid, 'config.Runner.Data.PrettyPrintAnnotations = false;\n');
fprintf(fid, 'config.Logging.Policy = ''LargeMC'';\n');
fprintf(fid, 'config.Logging.File.Enabled = true;\n');
fprintf(fid, 'config.Logging.Console.Enabled = false;\n');
fprintf(fid, 'config.Logging.Progress.Mode = ''Summary'';\n');
fprintf(fid, 'end\n');
clear cleanup;
addpath(configDir);
end

function perf = localLatestPerformanceTrace(perfDir)
    % localLatestPerformanceTrace - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
files = dir(fullfile(perfDir, '**', 'phase21-stage-timing-worker*.mat'));
perf = struct('Found', false, 'Path', '', 'Summary', struct(), ...
    'RuntimePerformance', struct());
if isempty(files)
    return;
end
[~, order] = sort([files.datenum], 'descend');
pathText = fullfile(files(order(1)).folder, files(order(1)).name);
loaded = load(pathText, 'performanceTrace');
perf.Found = true;
perf.Path = pathText;
if isfield(loaded.performanceTrace, 'Summary')
    perf.Summary = loaded.performanceTrace.Summary;
end
if isfield(loaded.performanceTrace, 'RuntimePerformance')
    perf.RuntimePerformance = loaded.performanceTrace.RuntimePerformance;
end
end

function localAssertNoHardFailures(perf, tag)
    % localAssertNoHardFailures - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if ~isstruct(perf) || ~isfield(perf, 'Found') || ~perf.Found || ...
        ~isfield(perf, 'Summary')
    return;
end
failed = localGet(perf.Summary, 'FailedScenarios', 0);
skipped = localGet(perf.Summary, 'SkippedScenarios', 0);
if failed > 0 || skipped > 0
    error('CSRD:Phase25:SimulationHadFailures', ...
        'Audit run "%s" reported failed=%d skipped=%d in %s.', ...
        tag, failed, skipped, perf.Path);
end
end

function audit = localAuditAnnotationDirectory(outputDir)
    % localAuditAnnotationDirectory - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
audit = struct('OutputDirectory', outputDir, 'DirectoryExists', false, ...
    'FileCount', 0, 'InvalidMeasuredCount', 0, ...
    'Issues', repmat(localEmptyAnnotationIssue(), 0, 1));
if ~isfolder(outputDir)
    return;
end
audit.DirectoryExists = true;
files = dir(fullfile(outputDir, '**', '*.json'));
for idx = 1:numel(files)
    pathText = fullfile(files(idx).folder, files(idx).name);
    if ~contains(lower(strrep(pathText, '\', '/')), '/annotations/')
        continue;
    end
    audit.FileCount = audit.FileCount + 1;
    try
        text = fileread(pathText);
        decoded = jsondecode(text);
        issues = localAuditAnnotationNode(decoded, pathText, '$');
        if ~isempty(issues)
            audit.Issues = [audit.Issues, issues]; %#ok<AGROW>
            audit.InvalidMeasuredCount = audit.InvalidMeasuredCount + numel(issues);
        end
    catch ME
        issue = localEmptyAnnotationIssue();
        issue.File = pathText;
        issue.Path = '$';
        issue.Field = '<json>';
        issue.Message = sprintf('Could not decode annotation JSON: %s', ME.message);
        audit.Issues(end + 1) = issue; %#ok<AGROW>
        audit.InvalidMeasuredCount = audit.InvalidMeasuredCount + 1;
    end
end
end

function issues = localAuditAnnotationNode(node, filePath, jsonPath)
    % localAuditAnnotationNode - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
issues = repmat(localEmptyAnnotationIssue(), 0, 1);
if iscell(node)
    for idx = 1:numel(node)
        childPath = sprintf('%s{%d}', jsonPath, idx);
        issues = [issues, localAuditAnnotationNode(node{idx}, filePath, childPath)]; %#ok<AGROW>
    end
    return;
end
if ~isstruct(node)
    return;
end
for itemIdx = 1:numel(node)
    item = node(itemIdx);
    itemPath = jsonPath;
    if numel(node) > 1
        itemPath = sprintf('%s(%d)', jsonPath, itemIdx);
    end
    if isfield(item, 'MeasurementStatus') && ...
            strcmpi(localTextScalar(item.MeasurementStatus), 'Measured')
        issues = [issues, localCheckMeasuredAnnotation(item, filePath, itemPath)]; %#ok<AGROW>
    end
    names = fieldnames(item);
    for nameIdx = 1:numel(names)
        fieldName = names{nameIdx};
        child = item.(fieldName);
        if isstruct(child) || iscell(child)
            childPath = sprintf('%s.%s', itemPath, fieldName);
            issues = [issues, localAuditAnnotationNode(child, filePath, childPath)]; %#ok<AGROW>
        end
    end
end
end

function issues = localCheckMeasuredAnnotation(item, filePath, jsonPath)
    % localCheckMeasuredAnnotation - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
required = {'OccupiedBandwidthHz', 'CenterFrequencyHz', ...
    'TimeOccupancy', 'FrequencyOccupancy'};
optionalFinite = {'SNRdB'};
issues = repmat(localEmptyAnnotationIssue(), 0, 1);
for idx = 1:numel(required)
    fieldName = required{idx};
    if ~isfield(item, fieldName) || ~localIsFiniteJsonScalar(item.(fieldName))
        issues(end + 1) = localAnnotationIssue(filePath, jsonPath, fieldName, ... %#ok<AGROW>
            'Measured annotation field must be a finite numeric scalar.');
    end
end
for idx = 1:numel(optionalFinite)
    fieldName = optionalFinite{idx};
    if isfield(item, fieldName) && ~localIsFiniteJsonScalar(item.(fieldName))
        issues(end + 1) = localAnnotationIssue(filePath, jsonPath, fieldName, ... %#ok<AGROW>
            'Optional measured annotation field is present but not finite.');
    end
end
end

function localAssertAnnotationAudit(audit, tag)
    % localAssertAnnotationAudit - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if ~audit.DirectoryExists || audit.FileCount == 0
    error('CSRD:Phase25:MissingAnnotationOutput', ...
        'Audit run "%s" did not produce annotation JSON under %s.', ...
        tag, audit.OutputDirectory);
end
if audit.InvalidMeasuredCount > 0
    first = audit.Issues(1);
    error('CSRD:Phase25:InvalidMeasuredAnnotation', ...
        ['Audit run "%s" found %d invalid Measured annotation fields. ', ...
         'First: %s %s.%s - %s'], ...
        tag, audit.InvalidMeasuredCount, first.File, first.Path, ...
        first.Field, first.Message);
end
end

function issue = localAnnotationIssue(filePath, jsonPath, fieldName, message)
    % localAnnotationIssue - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
issue = localEmptyAnnotationIssue();
issue.File = filePath;
issue.Path = jsonPath;
issue.Field = fieldName;
issue.Message = message;
end

function issue = localEmptyAnnotationIssue()
    % localEmptyAnnotationIssue - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
issue = struct('File', '', 'Path', '', 'Field', '', 'Message', '');
end

function tf = localIsFiniteJsonScalar(value)
    % localIsFiniteJsonScalar - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
tf = isnumeric(value) && isscalar(value) && isfinite(double(value));
end

function text = localTextScalar(value)
    % localTextScalar - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if ischar(value) || isstring(value)
    text = char(string(value));
else
    text = '';
end
end

function top = localProfileTop(profileInfo, count)
    % localProfileTop - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
top = repmat(struct('FunctionName', '', 'TotalTime', NaN, ...
    'SelfTime', NaN, 'NumCalls', NaN), 0, 1);
if ~isstruct(profileInfo) || ~isfield(profileInfo, 'FunctionTable') || ...
        isempty(profileInfo.FunctionTable)
    return;
end
tableData = profileInfo.FunctionTable;
[~, order] = sort([tableData.TotalTime], 'descend');
order = order(1:min(count, numel(order)));
for idx = 1:numel(order)
    item = tableData(order(idx));
    top(end + 1) = struct( ... %#ok<AGROW>
        'FunctionName', item.FunctionName, ...
        'TotalTime', item.TotalTime, ...
        'SelfTime', item.SelfTime, ...
        'NumCalls', item.NumCalls);
end
end

function findings = localBuildFindings(summary)
    % localBuildFindings - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
findings = repmat(localEmptyFinding(), 0, 1);
if summary.StaticAudit.Ran && isfield(summary.StaticAudit.Detail, 'Findings')
    findings = [findings, summary.StaticAudit.Detail.Findings]; %#ok<AGROW>
end
if summary.LogAudit.TotalErrors > 0
    findings(end + 1) = localFinding('Blocker', 'RuntimeLog', ... %#ok<AGROW>
        'LOG_ERRORS_PRESENT', 'logs', ...
        sprintf('Scanned logs contain %d ERROR lines.', summary.LogAudit.TotalErrors), ...
        'Open the newest log record and fix the first hard failure.');
end
if summary.LogAudit.TotalFrequencyOverlap > 0
    findings(end + 1) = localFinding('Correctness', 'RuntimeLog', ... %#ok<AGROW>
        'FREQUENCY_OVERLAP_WARNING', 'logs', ...
        'Scanned logs contain frequency overlap warnings.', ...
        'Default generation must avoid overlap or mark explicit overlap provenance.');
end
runNames = fieldnames(summary.Runs);
for idx = 1:numel(runNames)
    run = summary.Runs.(runNames{idx});
    if isstruct(run) && isfield(run, 'Ran') && run.Ran && ...
            strcmp(run.Status, 'Failed')
        findings(end + 1) = localFinding('Blocker', 'AuditRun', ... %#ok<AGROW>
            ['RUN_FAILED_', upper(runNames{idx})], runNames{idx}, ...
            sprintf('%s failed: %s', runNames{idx}, run.ErrorMessage), ...
            'Fix the first reproducible failure before continuing performance work.');
    end
end
end

function tf = localAuditSuccess(summary)
    % localAuditSuccess - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
tf = true;
runNames = fieldnames(summary.Runs);
for idx = 1:numel(runNames)
    run = summary.Runs.(runNames{idx});
    if isstruct(run) && isfield(run, 'Ran') && run.Ran && ...
            strcmp(run.Status, 'Failed')
        tf = false;
        return;
    end
end
end

function finding = localFinding(severity, category, code, location, message, recommendation)
    % localFinding - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
finding = localEmptyFinding();
finding.Severity = char(string(severity));
finding.Category = char(string(category));
finding.Code = char(string(code));
finding.Location = char(string(location));
finding.Message = char(string(message));
finding.Recommendation = char(string(recommendation));
end

function finding = localEmptyFinding()
    % localEmptyFinding - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
finding = struct('Severity', '', 'Category', '', 'Code', '', ...
    'Location', '', 'Message', '', 'Evidence', '', 'Recommendation', '');
end

function localWriteJson(pathText, payload)
    % localWriteJson - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
[clean, ~] = csrd.pipeline.annotation.sanitizeForJson(payload);
fid = fopen(pathText, 'w');
if fid == -1
    error('CSRD:Phase25:JsonOpenFailed', ...
        'Could not write audit JSON: %s', pathText);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', jsonencode(clean));
end

function localWriteMarkdown(pathText, summary)
    % localWriteMarkdown - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
fid = fopen(pathText, 'w');
if fid == -1
    error('CSRD:Phase25:MarkdownOpenFailed', ...
        'Could not write audit Markdown: %s', pathText);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '# Phase 25 Deep Audit Summary\n\n');
fprintf(fid, '- Generated: %s\n', summary.GeneratedAtUtc);
fprintf(fid, '- Success: %d\n', summary.Success);
fprintf(fid, '- Elapsed: %.2f s\n', summary.ElapsedSec);
fprintf(fid, '- Git branch: %s\n\n', summary.Git.Branch);
fprintf(fid, '## Findings\n\n');
if isempty(summary.Findings)
    fprintf(fid, 'No findings recorded.\n\n');
else
    for idx = 1:numel(summary.Findings)
        f = summary.Findings(idx);
        fprintf(fid, '- **%s** `%s` %s: %s\n', ...
            f.Severity, f.Code, f.Location, f.Message);
    end
    fprintf(fid, '\n');
end
fprintf(fid, '## Runs\n\n');
names = fieldnames(summary.Runs);
for idx = 1:numel(names)
    run = summary.Runs.(names{idx});
    fprintf(fid, '- %s: %s (ran=%d, %.2f s)\n', ...
        names{idx}, run.Status, run.Ran, run.ElapsedSec);
    if isfield(run, 'Detail') && isfield(run.Detail, 'AnnotationAudit')
        aa = run.Detail.AnnotationAudit;
        fprintf(fid, '  - AnnotationAudit: files=%d invalidMeasured=%d\n', ...
            aa.FileCount, aa.InvalidMeasuredCount);
    end
end
fprintf(fid, '\n');
localWriteStressMarkdown(fid, summary);
localWritePerformanceMarkdown(fid, summary);
end

function localWriteStressMarkdown(fid, summary)
    % localWriteStressMarkdown - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if ~isfield(summary.Runs, 'Stress') || ~summary.Runs.Stress.Ran || ...
        ~isfield(summary.Runs.Stress, 'Detail') || ...
        ~isfield(summary.Runs.Stress.Detail, 'Records')
    return;
end
detail = summary.Runs.Stress.Detail;
fprintf(fid, '## Stress Evidence\n\n');
fprintf(fid, '- Requested: %d\n', detail.RequestedCount);
fprintf(fid, '- Passed: %d\n', detail.Passed);
fprintf(fid, '- Failed: %d\n', detail.Failed);
records = detail.Records;
elapsed = [records.ElapsedSec];
valid = isfinite(elapsed) & elapsed > 0;
if any(valid)
    fprintf(fid, '- Mean elapsed: %.2f s\n', mean(elapsed(valid)));
    fprintf(fid, '- Max elapsed: %.2f s\n\n', max(elapsed(valid)));
    [~, order] = sort(elapsed, 'descend', 'MissingPlacement', 'last');
    fprintf(fid, '| Rank | Index | Seed | ElapsedSec | AnnotationFiles | InvalidMeasured | Status |\n');
    fprintf(fid, '| --- | ---: | ---: | ---: | ---: | ---: | --- |\n');
    rows = 0;
    for idx = 1:numel(order)
        rec = records(order(idx));
        if ~isfinite(rec.ElapsedSec) || rec.ElapsedSec <= 0
            continue;
        end
        rows = rows + 1;
        fprintf(fid, '| %d | %d | %d | %.2f | %d | %d | %s |\n', ...
            rows, rec.Index, rec.Seed, rec.ElapsedSec, ...
            rec.AnnotationFiles, rec.InvalidMeasuredAnnotations, rec.Status);
        if rows >= 5
            break;
        end
    end
    fprintf(fid, '\n');
end
end

function localWritePerformanceMarkdown(fid, summary)
    % localWritePerformanceMarkdown - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if ~isfield(summary, 'PerformanceTraceInventory') || ...
        ~isfield(summary.PerformanceTraceInventory, 'Records') || ...
        isempty(summary.PerformanceTraceInventory.Records)
    return;
end
records = summary.PerformanceTraceInventory.Records;
elapsed = [records.TotalElapsedSec];
valid = isfinite(elapsed) & elapsed > 0;
if ~any(valid)
    return;
end
fprintf(fid, '## Performance Hotspots\n\n');
fprintf(fid, '| Rank | TotalSec | TopRuntimeEvent | EventSec | Trace |\n');
fprintf(fid, '| --- | ---: | --- | ---: | --- |\n');
[~, order] = sort(elapsed, 'descend', 'MissingPlacement', 'last');
rows = 0;
for idx = 1:numel(order)
    rec = records(order(idx));
    if ~isfinite(rec.TotalElapsedSec) || rec.TotalElapsedSec <= 0
        continue;
    end
    rows = rows + 1;
    fprintf(fid, '| %d | %.2f | `%s` | %.2f | `%s` |\n', ...
        rows, rec.TotalElapsedSec, rec.TopRuntimeEvent, ...
        rec.TopRuntimeEventSec, rec.Path);
    if rows >= 8
        break;
    end
end
fprintf(fid, '\n');
end

function localPrintSummary(summary)
    % localPrintSummary - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
fprintf('Phase 25 deep audit written to:\n  %s\n  %s\n  %s\n', ...
    summary.MatPath, summary.JsonPath, summary.MarkdownPath);
fprintf('Success=%d, findings=%d, elapsed=%.2fs\n', ...
    summary.Success, numel(summary.Findings), summary.ElapsedSec);
end

function files = localCollectMatlabFiles(projectRoot, roots)
    % localCollectMatlabFiles - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
files = {};
for idx = 1:numel(roots)
    rootPath = fullfile(projectRoot, roots{idx});
    if ~isfolder(rootPath)
        continue;
    end
    listing = dir(fullfile(rootPath, '**', '*.m'));
    for fileIdx = 1:numel(listing)
        files{end + 1} = fullfile(listing(fileIdx).folder, listing(fileIdx).name); %#ok<AGROW>
    end
end
end

function tf = localPathMatchesScope(relPath, scopes)
    % localPathMatchesScope - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
tf = false;
relPath = strrep(relPath, '\', '/');
for idx = 1:numel(scopes)
    scope = strrep(char(string(scopes{idx})), '\', '/');
    if startsWith(relPath, scope)
        tf = true;
        return;
    end
end
end

function tf = localIsGeneratedOrIgnored(relPath)
    % localIsGeneratedOrIgnored - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
relPath = strrep(relPath, '\', '/');
tf = startsWith(relPath, 'data/') || startsWith(relPath, 'artifacts/');
end

function roots = localNormalizeRoots(value)
    % localNormalizeRoots - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isempty(value)
    roots = {};
elseif iscell(value)
    roots = cellfun(@(x) char(string(x)), value, 'UniformOutput', false);
else
    roots = cellstr(string(value));
end
end

function text = localReadTextLimited(pathText, maxChars)
    % localReadTextLimited - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
fid = fopen(pathText, 'r');
if fid == -1
    text = "";
    return;
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
text = string(fread(fid, maxChars, '*char').');
end

function n = localCount(text, pattern)
    % localCount - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
n = numel(strfind(char(text), pattern));
end

function value = localGet(s, fieldName, defaultValue)
    % localGet - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = s.(fieldName);
else
    value = defaultValue;
end
end

function value = localGetNested(s, fields, defaultValue)
    % localGetNested - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
value = s;
for idx = 1:numel(fields)
    field = fields{idx};
    if ~isstruct(value) || ~isfield(value, field)
        value = defaultValue;
        return;
    end
    value = value.(field);
    if isempty(value)
        value = defaultValue;
        return;
    end
end
end

function text = localStringList(value)
    % localStringList - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if iscell(value)
    text = strjoin(cellfun(@(x) char(string(x)), value, ...
        'UniformOutput', false), ',');
elseif isstring(value) || ischar(value)
    text = strjoin(cellstr(string(value)), ',');
else
    text = '';
end
end

function dirPath = localResolveArtifactDirectory(projectRoot, requested, defaultPath)
    % localResolveArtifactDirectory - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isempty(requested)
    dirPath = defaultPath;
else
    dirPath = char(string(requested));
    if ~localIsAbsolutePath(dirPath)
        dirPath = fullfile(projectRoot, dirPath);
    end
end
dirPath = localNormalizePathText(dirPath);
projectCanonical = localNormalizePathText(projectRoot);
if startsWith(lower(dirPath), lower(projectCanonical)) && ...
        ~startsWith(lower(dirPath), lower(localNormalizePathText( ...
        fullfile(projectCanonical, 'artifacts')))) && ...
        ~startsWith(lower(dirPath), lower(localNormalizePathText( ...
        fullfile(projectCanonical, 'data'))))
    error('CSRD:Phase25:ArtifactPathOutsideIgnoredRoots', ...
        ['Phase 25 audit output inside the repo must be under artifacts/ ', ...
         'or data/: %s'], dirPath);
end
end

function localEnsureDirectory(pathText)
    % localEnsureDirectory - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if ~isfolder(pathText)
    mkdir(pathText);
end
end

function text = localSystemText(projectRoot, command)
    % localSystemText - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
old = pwd;
cleanup = onCleanup(@() cd(old)); %#ok<NASGU>
cd(projectRoot);
[~, out] = system(command);
text = strtrim(out);
end

function rel = localRelativePath(projectRoot, pathText)
    % localRelativePath - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
root = localNormalizePathText(projectRoot);
p = localNormalizePathText(pathText);
if startsWith(lower(p), lower([root, filesep]))
    rel = p(numel(root) + 2:end);
else
    rel = p;
end
end

function pathText = localNormalizePathText(pathText)
    % localNormalizePathText - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
pathText = char(string(pathText));
if ~localIsAbsolutePath(pathText)
    pathText = fullfile(pwd, pathText);
end
pathText = strrep(pathText, '/', filesep);
pathText = regexprep(pathText, [regexptranslate('escape', filesep), '+'], filesep);
if numel(pathText) > 1 && endsWith(pathText, filesep)
    pathText = extractBefore(pathText, strlength(pathText));
    pathText = char(pathText);
end
end

function tf = localIsAbsolutePath(pathText)
    % localIsAbsolutePath - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
pathText = char(string(pathText));
if ispc
    tf = numel(pathText) >= 3 && pathText(2) == ':' && ...
        any(pathText(3) == ['\', '/']);
else
    tf = startsWith(pathText, filesep);
end
end

function escaped = localEscape(text)
    % localEscape - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
escaped = strrep(char(string(text)), '''', '''''');
end

function tf = localPositiveInteger(value)
    % localPositiveInteger - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
tf = isnumeric(value) && isscalar(value) && isfinite(value) && ...
    value >= 1 && floor(value) == value;
end

function tf = localPositiveScalar(value)
    % localPositiveScalar - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
tf = isnumeric(value) && isscalar(value) && isfinite(value) && value > 0;
end

function projectRoot = localProjectRoot()
    % localProjectRoot - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
here = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(here));
end
