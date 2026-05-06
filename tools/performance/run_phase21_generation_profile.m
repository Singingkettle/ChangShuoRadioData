function summary = run_phase21_generation_profile(varargin)
%RUN_PHASE21_GENERATION_PROFILE Phase 21 generation performance entrypoint.
% 中文说明：生成链路性能画像入口，输出到 ignored artifacts/performance/phase21/。
%
% This tool records low-overhead evidence without changing simulation
% contracts. Expensive smoke runs are opt-in so the quick path is safe for
% unit tests and local iteration.
%
% Examples:
%   summary = run_phase21_generation_profile()
%   summary = run_phase21_generation_profile('RunMeasurementMicrobench', true)
%   summary = run_phase21_generation_profile('RunDefaultSimulation', true)

p = inputParser();
p.FunctionName = 'run_phase21_generation_profile';
addParameter(p, 'ConfigPath', 'csrd2025/csrd2025.m', ...
    @(x) ischar(x) || isstring(x));
addParameter(p, 'OutputDirectory', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'RunMeasurementMicrobench', true, ...
    @(x) islogical(x) && isscalar(x));
addParameter(p, 'NumMicrobenchRepeats', 3, @localPositiveInteger);
addParameter(p, 'RunOsmFlatSmoke', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'RunOsmBuildingSmoke', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'RunDefaultSimulation', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

projectRoot = localProjectRoot();
addpath(projectRoot);

artifactDir = char(string(p.Results.OutputDirectory));
if isempty(artifactDir)
    artifactDir = fullfile(projectRoot, 'artifacts', 'performance', 'phase21');
end
if ~isfolder(artifactDir)
    mkdir(artifactDir);
end

summary = struct();
summary.Schema = 'csrd.phase21.generation-profile.v1';
summary.GeneratedAtUtc = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''));
summary.ProjectRoot = projectRoot;
summary.ConfigPath = char(string(p.Results.ConfigPath));
summary.ArtifactDirectory = artifactDir;
summary.MatlabVersion = version;
summary.Probes = struct();

cfgStart = tic;
cfg = csrd.runtime.config_loader(summary.ConfigPath);
summary.ConfigLoadSec = toc(cfgStart);
summary.ConfigContracts = localFrameContract(cfg);
summary.ConfigRuntime = localConfigRuntimeShape(cfg);

summary.Probes.MeasurementMicrobench = struct('Ran', false);
if p.Results.RunMeasurementMicrobench
    summary.Probes.MeasurementMicrobench = localRunMeasurementMicrobench( ...
        p.Results.NumMicrobenchRepeats);
end

summary.Probes.OsmFlatSmoke = localOptionalProbe('OSM flat smoke', ...
    p.Results.RunOsmFlatSmoke, @() localRunOsmFlatSmoke(projectRoot));
summary.Probes.OsmBuildingSmoke = localOptionalProbe('OSM building smoke', ...
    p.Results.RunOsmBuildingSmoke, @() localRunOsmBuildingSmoke(projectRoot));
summary.Probes.DefaultSimulation = localOptionalProbe('default simulation', ...
    p.Results.RunDefaultSimulation, @() localRunDefaultSimulation(cfg, ...
        artifactDir, projectRoot));

summary.Success = localProbeSuccess(summary.Probes);
ts = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
summaryPath = fullfile(artifactDir, sprintf('phase21-profile-%s.mat', ts));
jsonPath = fullfile(artifactDir, sprintf('phase21-profile-%s.json', ts));
save(summaryPath, 'summary');
localWriteJson(jsonPath, summary);
summary.SummaryPath = summaryPath;
summary.JsonPath = jsonPath;

if p.Results.Verbose
    localPrintSummary(summary);
end
end

function contract = localFrameContract(cfg)
contract = struct();
try
    runtime = csrd.pipeline.runtime.resolveFrameRuntimeContract( ...
        struct('Scenario', cfg.Factories.Scenario), struct());
    contract.FrameNumSamples = runtime.FrameNumSamples;
    contract.SampleRateHz = runtime.SampleRateHz;
    contract.FrameDurationSec = runtime.FrameDurationSec;
    contract.NumFramesPerScenario = runtime.NumFramesPerScenario;
    contract.ObservationDurationSec = runtime.ObservationDurationSec;
catch ME
    contract.Error = sprintf('%s: %s', ME.identifier, ME.message);
end
end

function shape = localConfigRuntimeShape(cfg)
shape = struct();
shape.NumScenarios = localGet(cfg.Runner, 'NumScenarios', NaN);
shape.LogPolicy = '';
if isfield(cfg.Runner, 'Log') && isfield(cfg.Runner.Log, 'Policy')
    shape.LogPolicy = char(string(cfg.Runner.Log.Policy));
end
shape.PrettyPrintAnnotations = NaN;
if isfield(cfg.Runner, 'Data') && ...
        isfield(cfg.Runner.Data, 'PrettyPrintAnnotations')
    shape.PrettyPrintAnnotations = logical(cfg.Runner.Data.PrettyPrintAnnotations);
end
shape.StageTimingEnabled = false;
if isfield(cfg.Runner, 'Performance') && ...
        isfield(cfg.Runner.Performance, 'EnableStageTiming')
    shape.StageTimingEnabled = logical(cfg.Runner.Performance.EnableStageTiming);
end
end

function bench = localRunMeasurementMicrobench(numRepeats)
bench = struct('Ran', true);
fs = 50e6;
n = 32768;
t = (0:n - 1).' / fs;
rng(21);
signal = exp(1j * 2 * pi * 2.2e6 * t) + ...
    0.15 * complex(randn(n, 1), randn(n, 1));
observableBwHz = 20e6;

legacyTimes = zeros(numRepeats, 1);
summaryTimes = zeros(numRepeats, 1);
legacy = struct();
fast = struct();
for k = 1:numRepeats
    tLegacy = tic;
    legacy.OccupiedBandwidthHz = csrd.pipeline.measurement.obwActual(signal, fs, 99);
    legacy.CenterFrequencyHz = csrd.pipeline.measurement.spectrumCentroid(signal, fs);
    legacy.Envelope = csrd.pipeline.measurement.detectBurstEnvelope(signal, fs, struct());
    legacy.TimeOccupancy = legacy.Envelope.TimeOccupancy;
    legacy.FrequencyOccupancy = csrd.pipeline.measurement.frequencyOccupancy( ...
        legacy.OccupiedBandwidthHz, observableBwHz);
    legacyTimes(k) = toc(tLegacy);

    tSummary = tic;
    fast = csrd.pipeline.measurement.measureSignalSummary( ...
        signal, fs, observableBwHz);
    summaryTimes(k) = toc(tSummary);
end

bench.NumRepeats = numRepeats;
bench.LegacyMedianSec = median(legacyTimes);
bench.SummaryMedianSec = median(summaryTimes);
bench.Speedup = bench.LegacyMedianSec / max(bench.SummaryMedianSec, eps);
bench.Equivalence = struct( ...
    'OccupiedBandwidthAbsHz', abs(legacy.OccupiedBandwidthHz - fast.OccupiedBandwidthHz), ...
    'CenterFrequencyAbsHz', abs(legacy.CenterFrequencyHz - fast.CenterFrequencyHz), ...
    'TimeOccupancyAbs', abs(legacy.TimeOccupancy - fast.TimeOccupancy), ...
    'FrequencyOccupancyAbs', abs(legacy.FrequencyOccupancy - fast.FrequencyOccupancy));
bench.Passed = bench.Equivalence.OccupiedBandwidthAbsHz <= max(1, 1e-9 * fs) && ...
    bench.Equivalence.CenterFrequencyAbsHz <= max(1, 1e-9 * fs) && ...
    bench.Equivalence.TimeOccupancyAbs <= 1e-12 && ...
    bench.Equivalence.FrequencyOccupancyAbs <= 1e-12;
end

function probe = localOptionalProbe(name, shouldRun, runner)
probe = struct('Ran', false, 'Name', name, 'Status', 'NotRun', ...
    'ElapsedSec', NaN, 'Error', '');
if ~shouldRun
    return;
end
probe.Ran = true;
t = tic;
try
    detail = runner();
    probe.Status = 'Passed';
    probe.Detail = detail;
catch ME
    probe.Status = 'Failed';
    probe.Error = sprintf('%s: %s', ME.identifier, ME.message);
end
probe.ElapsedSec = toc(t);
end

function detail = localRunOsmFlatSmoke(projectRoot)
addpath(fullfile(projectRoot, 'tests', 'regression'));
summary = test_simulation_entrypoint_coverage_sweep( ...
    'Mode', 'quick', ...
    'IncludeBuildingOSM', false, ...
    'StartAt', 5, ...
    'StopAfter', 5, ...
    'EnforceCoverage', false);
assert(summary.CasesPassed == 1 && summary.CasesSkipped == 0, ...
    'CSRD:Phase21:OsmFlatSmokeFailed', ...
    'OSM flat smoke expected one passed case and zero skips.');
detail = summary;
end

function detail = localRunOsmBuildingSmoke(projectRoot)
addpath(fullfile(projectRoot, 'tests', 'regression'));
test_osm_building_raytracing();
detail = struct('Function', 'test_osm_building_raytracing', 'Passed', true);
end

function detail = localRunDefaultSimulation(cfg, artifactDir, projectRoot)
cfg.Runner.Performance.EnableStageTiming = true;
cfg.Runner.Performance.ArtifactDirectory = artifactDir;
cfg.Runner.Data.OutputDirectory = 'CSRD2025_phase21_profile';
csrd.runtime.logger.GlobalLogManager.reset();
if isfield(cfg, 'Log')
    logCfg = cfg.Log;
else
    logCfg = struct('Name', 'CSRD-Phase21-Profile', ...
        'Level', 'INFO', 'SaveToFile', true, 'DisplayInConsole', true);
end
outputDir = fullfile(projectRoot, 'data', cfg.Runner.Data.OutputDirectory);
csrd.runtime.logger.GlobalLogManager.initialize(logCfg, outputDir);
runner = csrd.SimulationRunner('RunnerConfig', cfg.Runner);
runner.FactoryConfigs = cfg.Factories;
runner(1, 1);
detail = struct('OutputDirectory', outputDir, 'StageTimingDirectory', artifactDir);
end

function ok = localProbeSuccess(probes)
ok = true;
names = fieldnames(probes);
for k = 1:numel(names)
    probe = probes.(names{k});
    if isstruct(probe) && isfield(probe, 'Ran') && probe.Ran && ...
            isfield(probe, 'Status') && strcmpi(probe.Status, 'Failed')
        ok = false;
    elseif isstruct(probe) && isfield(probe, 'Ran') && probe.Ran && ...
            isfield(probe, 'Passed') && ~probe.Passed
        ok = false;
    end
end
end

function value = localGet(s, fieldName, defaultValue)
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = s.(fieldName);
else
    value = defaultValue;
end
end

function localWriteJson(path, payload)
fid = fopen(path, 'w');
if fid == -1
    error('CSRD:Phase21:JsonOpenFailed', ...
        'Could not open profile JSON for writing: %s', path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonencode(payload));
clear cleanup;
end

function localPrintSummary(summary)
fprintf('Phase 21 profile written to:\n  %s\n  %s\n', ...
    summary.SummaryPath, summary.JsonPath);
if isfield(summary.Probes, 'MeasurementMicrobench') && ...
        summary.Probes.MeasurementMicrobench.Ran
    bench = summary.Probes.MeasurementMicrobench;
    fprintf('Measurement summary speedup: %.2fx (legacy %.4fs, summary %.4fs)\n', ...
        bench.Speedup, bench.LegacyMedianSec, bench.SummaryMedianSec);
end
end

function tf = localPositiveInteger(value)
tf = isnumeric(value) && isscalar(value) && isfinite(value) && ...
    value >= 1 && floor(value) == value;
end

function projectRoot = localProjectRoot()
here = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(here));
end
