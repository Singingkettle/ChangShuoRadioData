function summary = run_phase22_generation_diagnostics(varargin)
%RUN_PHASE22_GENERATION_DIAGNOSTICS Run generation diagnostics via simulation.m.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.

p = inputParser();
p.FunctionName = 'run_phase22_generation_diagnostics';
addParameter(p, 'ArtifactDirectory', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'RunDefaultSimulation', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'RunFullCoverageValidation', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'RunOsmRayTracingValidation', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'RunOsmLargeMapValidation', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'RunOsmSpecificMapValidation', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'RunStress', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'StressCount', 0, @localNonnegativeInteger);
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

projectRoot = localProjectRoot();
addpath(projectRoot);
addpath(fullfile(projectRoot, 'tools'));

artifactDir = char(string(p.Results.ArtifactDirectory));
if isempty(artifactDir)
    artifactDir = fullfile(projectRoot, 'artifacts', 'performance', 'phase22');
end
if ~isfolder(artifactDir)
    mkdir(artifactDir);
end

summary = struct();
summary.Schema = 'csrd.phase22.generation-diagnostics.v1';
summary.GeneratedAtUtc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
summary.ProjectRoot = projectRoot;
summary.ArtifactDirectory = artifactDir;
summary.Runs = struct();

summary.ConfigShape.Default = localConfigShape('csrd2025/csrd2025.m');
summary.Runs.DefaultSimulation = localMaybeRun( ...
    p.Results.RunDefaultSimulation, @() localRunViaSimulation( ...
        'csrd2025/csrd2025.m', artifactDir, 'default'));
summary.Runs.FullCoverageValidation = localMaybeRun( ...
    p.Results.RunFullCoverageValidation, @() localRunViaSimulation( ...
        'csrd2025/csrd2025_full_coverage_validation.m', artifactDir, ...
        'full_coverage'));
summary.Runs.OsmRayTracingValidation = localMaybeRun( ...
    p.Results.RunOsmRayTracingValidation, @() localRunViaSimulation( ...
        'csrd2025/csrd2025_osm_raytracing_validation.m', artifactDir, ...
        'osm_raytracing'));
summary.Runs.OsmSpecificMapValidation = localMaybeRun( ...
    p.Results.RunOsmSpecificMapValidation || p.Results.RunOsmLargeMapValidation, ...
    @() localRunViaSimulation( ...
        'csrd2025/csrd2025_osm_large_map_validation.m', artifactDir, ...
        'osm_specific_map'));
summary.Runs.Stress = localMaybeRun( ...
    p.Results.RunStress && p.Results.StressCount > 0, ...
    @() localRunStress(artifactDir, p.Results.StressCount));

summary.Success = localAllRunsPassed(summary.Runs);
ts = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
summary.SummaryPath = fullfile(artifactDir, ...
    sprintf('phase22-generation-diagnostics-%s.mat', ts));
summary.JsonPath = fullfile(artifactDir, ...
    sprintf('phase22-generation-diagnostics-%s.json', ts));
save(summary.SummaryPath, 'summary');
localWriteJson(summary.JsonPath, summary);

if p.Results.Verbose
    localPrintSummary(summary);
end
end

function shape = localConfigShape(configPath)
    % localConfigShape - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
shape = struct('ConfigPath', configPath, 'Loaded', false);
try
    cfg = csrd.runtime.config_loader(configPath);
    shape.Loaded = true;
    shape.NumScenarios = cfg.Runner.NumScenarios;
    if isfield(cfg.Runner, 'Performance')
        shape.Performance = cfg.Runner.Performance;
    end
    scenarioPlan = csrd.pipeline.runtime.buildScenarioPlan( ...
        cfg.RuntimePlan, cfg.Factories.Scenario, ...
        struct('ScenarioId', 1, 'RandomSeed', cfg.Runner.RandomSeed));
    shape.FramePolicy = cfg.RuntimePlan.FramePolicy;
    shape.FrameNumSamples = scenarioPlan.Frame.FrameNumSamples;
    shape.SampleRateHz = scenarioPlan.Frame.SampleRateHz;
    shape.FrameDurationSec = scenarioPlan.Frame.FrameDurationSec;
    shape.NumFramesPerScenario = scenarioPlan.Frame.NumFramesPerScenario;
catch ME
    shape.Error = sprintf('%s: %s', ME.identifier, ME.message);
end
end

function run = localMaybeRun(shouldRun, runner)
    % localMaybeRun - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
run = struct('Ran', false, 'Status', 'NotRun', 'ElapsedSec', NaN, ...
    'ErrorIdentifier', '', 'ErrorMessage', '');
if ~shouldRun
    return;
end
run.Ran = true;
t = tic;
try
    detail = runner();
    run.Detail = detail;
    if localDetailHasFailures(detail)
        run.Status = 'Failed';
        run.ErrorIdentifier = 'CSRD:Phase22:NestedRunFailed';
        run.ErrorMessage = 'One or more nested diagnostic runs failed.';
    else
        run.Status = 'Passed';
    end
catch ME
    run.Status = 'Failed';
    run.ErrorIdentifier = ME.identifier;
    run.ErrorMessage = ME.message;
end
run.ElapsedSec = toc(t);
end

function tf = localDetailHasFailures(detail)
    % localDetailHasFailures - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
tf = false;
if ~isstruct(detail)
    return;
end
if isfield(detail, 'Failed') && isnumeric(detail.Failed) && ...
        any(detail.Failed(:) > 0)
    tf = true;
    return;
end
if isfield(detail, 'Results') && isstruct(detail.Results)
    for idx = 1:numel(detail.Results)
        item = detail.Results(idx);
        if isfield(item, 'Status') && strcmp(char(string(item.Status)), 'Failed')
            tf = true;
            return;
        end
    end
end
end

function detail = localRunViaSimulation(baseConfig, artifactDir, tag)
    % localRunViaSimulation - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
configPath = localWriteProfileConfig(baseConfig, artifactDir, tag, [], []);
simulation(1, 1, configPath);
perf = localLatestPerformanceTrace(artifactDir);
localAssertNoHardFailures(perf, tag);
detail = struct( ...
    'BaseConfig', baseConfig, ...
    'GeneratedConfig', configPath, ...
    'ArtifactDirectory', artifactDir, ...
    'OutputTag', tag, ...
    'PerformanceTrace', perf);
end

function detail = localRunStress(artifactDir, stressCount)
    % localRunStress - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
results = repmat(struct('Index', 0, 'Status', '', 'ElapsedSec', NaN, ...
    'GeneratedConfig', '', 'ErrorIdentifier', '', 'ErrorMessage', ''), ...
    stressCount, 1);
for idx = 1:stressCount
    tag = sprintf('stress_%03d', idx);
    configPath = localWriteProfileConfig('csrd2025/csrd2025.m', ...
        artifactDir, tag, 1, idx);
    t = tic;
    results(idx).Index = idx;
    results(idx).GeneratedConfig = configPath;
    try
        simulation(1, 1, configPath);
        perf = localLatestPerformanceTrace(artifactDir);
        localAssertNoHardFailures(perf, tag);
        results(idx).Status = 'Passed';
    catch ME
        results(idx).Status = 'Failed';
        results(idx).ErrorIdentifier = ME.identifier;
        results(idx).ErrorMessage = ME.message;
    end
    results(idx).ElapsedSec = toc(t);
end
detail = struct();
detail.Count = stressCount;
detail.Results = results;
detail.Passed = sum(strcmp({results.Status}, 'Passed'));
detail.Failed = sum(strcmp({results.Status}, 'Failed'));
end

function perf = localLatestPerformanceTrace(artifactDir)
    % localLatestPerformanceTrace - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
files = dir(fullfile(artifactDir, '**', 'phase21-stage-timing-worker*.mat'));
perf = struct('Found', false);
if isempty(files)
    return;
end
[~, order] = sort([files.datenum], 'descend');
latest = files(order(1));
pathText = fullfile(latest.folder, latest.name);
loaded = load(pathText, 'performanceTrace');
perf.Found = true;
perf.Path = pathText;
perf.Summary = loaded.performanceTrace.Summary;
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
summary = perf.Summary;
if isfield(summary, 'FailedScenarios') && summary.FailedScenarios > 0
    error('CSRD:Phase22:SimulationHadFailedScenarios', ...
        ['Diagnostic run "%s" completed MATLAB execution but reported ', ...
         '%d failed scenarios in %s.'], ...
        tag, summary.FailedScenarios, perf.Path);
end
end

function configPath = localWriteProfileConfig(baseConfig, artifactDir, tag, numScenarios, seed)
    % localWriteProfileConfig - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
configDir = fullfile(artifactDir, 'generated_configs');
if ~isfolder(configDir)
    mkdir(configDir);
end
safeTag = regexprep(char(string(tag)), '[^A-Za-z0-9_]', '_');
functionName = sprintf('phase22_%s_%s', safeTag, ...
    char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS')));
configPath = fullfile(configDir, [functionName, '.m']);
fid = fopen(configPath, 'w');
if fid == -1
    error('CSRD:Phase22:ConfigOpenFailed', ...
        'Could not create diagnostic config: %s', configPath);
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
    localEscape(artifactDir));
fprintf(fid, 'config.Runner.Data.OutputDirectory = ''CSRD2025_phase22_%s'';\n', ...
    localEscape(safeTag));
fprintf(fid, 'config.Runner.Data.PrettyPrintAnnotations = false;\n');
fprintf(fid, 'config.Logging.Policy = ''LargeMC'';\n');
fprintf(fid, 'config.Logging.File.Enabled = true;\n');
fprintf(fid, 'config.Logging.Console.Enabled = false;\n');
fprintf(fid, 'config.Logging.Progress.Mode = ''Summary'';\n');
fprintf(fid, 'end\n');
clear cleanup;
end

function ok = localAllRunsPassed(runs)
    % localAllRunsPassed - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
ok = true;
names = fieldnames(runs);
for idx = 1:numel(names)
    run = runs.(names{idx});
    if isstruct(run) && isfield(run, 'Ran') && run.Ran && ...
            ~strcmp(run.Status, 'Passed')
        ok = false;
        return;
    end
end
end

function localWriteJson(pathText, payload)
    % localWriteJson - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
fid = fopen(pathText, 'w');
if fid == -1
    error('CSRD:Phase22:JsonOpenFailed', ...
        'Could not write diagnostics JSON: %s', pathText);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonencode(payload));
clear cleanup;
end

function localPrintSummary(summary)
    % localPrintSummary - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
fprintf('Phase 22 generation diagnostics written to:\n  %s\n  %s\n', ...
    summary.SummaryPath, summary.JsonPath);
names = fieldnames(summary.Runs);
for idx = 1:numel(names)
    run = summary.Runs.(names{idx});
    if run.Ran
        fprintf('  %s: %s in %.2fs\n', names{idx}, run.Status, run.ElapsedSec);
    end
end
end

function text = localEscape(text)
    % localEscape - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
text = strrep(char(string(text)), '''', '''''');
end

function tf = localNonnegativeInteger(value)
    % localNonnegativeInteger - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
tf = isnumeric(value) && isscalar(value) && isfinite(value) && ...
    value >= 0 && floor(value) == value;
end

function projectRoot = localProjectRoot()
    % localProjectRoot - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
here = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(here));
end
