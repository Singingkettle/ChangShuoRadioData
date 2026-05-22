function summary = diagnose_default_simulation_runtime_contracts(varargin)
%DIAGNOSE_DEFAULT_SIMULATION_RUNTIME_CONTRACTS Phase 20 default-chain probe.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
%
% Usage:
%   summary = diagnose_default_simulation_runtime_contracts()
%   summary = diagnose_default_simulation_runtime_contracts('RunSimulation', true)

p = inputParser();
addParameter(p, 'ConfigPath', 'csrd2025/csrd2025.m', @(x) ischar(x) || isstring(x));
addParameter(p, 'RunSimulation', false, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});

projectRoot = localProjectRoot();
artifactDir = fullfile(projectRoot, 'artifacts', 'debug', 'default-simulation');
if ~isfolder(artifactDir)
    mkdir(artifactDir);
end

summary = struct();
summary.Timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
summary.ConfigPath = char(string(p.Results.ConfigPath));
summary.ArtifactDir = artifactDir;

cfg = csrd.runtime.config_loader(summary.ConfigPath);
scenarioCfg = cfg.Factories.Scenario;
scenarioPlan = csrd.pipeline.runtime.buildScenarioPlan( ...
    cfg.RuntimePlan, scenarioCfg, ...
    struct('ScenarioId', 1, 'RandomSeed', cfg.Runner.RandomSeed));
summary.FramePolicy = cfg.RuntimePlan.FramePolicy;
summary.FrameNumSamples = scenarioPlan.Frame.FrameNumSamples;
summary.SampleRateHz = scenarioPlan.Frame.SampleRateHz;
summary.FrameDurationSec = scenarioPlan.Frame.FrameDurationSec;
summary.NumFramesPerScenario = scenarioPlan.Frame.NumFramesPerScenario;
summary.ObservationDurationSec = scenarioPlan.Frame.ObservationDurationSec;

summary.Scenarios = localScenarioMatrix(scenarioCfg);
summary.RunSimulation = p.Results.RunSimulation;
summary.RunStatus = 'NotRun';
summary.FirstFailure = '';
if p.Results.RunSimulation
    try
        simulation(1, 1, summary.ConfigPath);
        summary.RunStatus = 'Success';
    catch ME
        summary.RunStatus = 'Failed';
        summary.FirstFailure = sprintf('%s: %s', ME.identifier, ME.message);
    end
end

summaryPath = fullfile(artifactDir, sprintf('phase20-default-contract-%s.mat', ...
    char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))));
save(summaryPath, 'summary');
summary.SummaryPath = summaryPath;

fprintf('Phase 20 default simulation diagnostic written to %s\n', summaryPath);
end

function projectRoot = localProjectRoot()
    % localProjectRoot - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
here = fileparts(mfilename('fullpath'));
projectRoot = fileparts(fileparts(here));
end

function rows = localScenarioMatrix(scenarioCfg)
    % localScenarioMatrix - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
rows = struct('MapMode', {}, 'ChannelModel', {}, 'RequiredCarrierRangeHz', {});
mapCfg = scenarioCfg.PhysicalEnvironment.Map;
if isfield(mapCfg, 'TypeRatio') && isstruct(mapCfg.TypeRatio)
    names = fieldnames(mapCfg.TypeRatio);
    weights = cellfun(@(name) mapCfg.TypeRatio.(name), names);
elseif isfield(mapCfg, 'Types') && isfield(mapCfg, 'Ratio')
    names = mapCfg.Types;
    weights = mapCfg.Ratio;
else
    rows = struct('MapMode', {}, 'ChannelModel', {}, 'RequiredCarrierRangeHz', {});
    return;
end
for k = 1:numel(names)
    name = char(string(names{k}));
    if weights(k) <= 0
        continue;
    end
    row = struct();
    row.MapMode = name;
    if isfield(mapCfg, name) && isfield(mapCfg.(name), 'ChannelModel')
        row.ChannelModel = mapCfg.(name).ChannelModel;
    else
        row.ChannelModel = '';
    end
    if strcmpi(row.ChannelModel, 'RayTracing')
        row.RequiredCarrierRangeHz = [100e6, 100e9];
    else
        row.RequiredCarrierRangeHz = [];
    end
    rows(end + 1) = row; %#ok<AGROW>
end
end
