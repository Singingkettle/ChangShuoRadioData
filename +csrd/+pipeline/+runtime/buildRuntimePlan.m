function config = buildRuntimePlan(config)
%BUILDRUNTIMEPLAN Build the canonical runtime plan from raw configuration.
% 中文说明：从原始配置构建唯一运行计划；生产链路只读取 RuntimePlan。

if nargin < 1 || isempty(config) || ~isstruct(config)
    error('CSRD:RuntimePlan:InvalidConfig', ...
        'buildRuntimePlan requires a nonempty configuration struct.');
end
if ~isfield(config, 'Runner') || ~isstruct(config.Runner)
    error('CSRD:RuntimePlan:MissingRunnerConfig', ...
        'Runner config is required to build RuntimePlan.');
end
if ~isfield(config, 'Factories') || ~isstruct(config.Factories)
    error('CSRD:RuntimePlan:MissingFactoryConfigs', ...
        'Factories config is required to build RuntimePlan.');
end
localRejectDeprecatedRawFields(config);

frame = csrd.pipeline.runtime.resolveFrameRuntimeContract( ...
    config.Factories, config.Runner);
truth = csrd.pipeline.runtime.validateRuntimeTruthContracts( ...
    config.Factories, config.Runner);

plan = struct();
plan.Version = 'Phase30RuntimePlan.v1';
plan.Frame = frame;
plan.RuntimeTruth = truth;
plan.Receiver = truth.Receiver;
plan.Channel = truth.Channel;
if isfield(truth, 'Transmit')
    plan.Transmit = truth.Transmit;
end
plan.Seed = localBuildSeedPlan(config.Runner);
plan.Map = localBuildMapPlan(config.Factories);

config.RuntimePlan = plan;
if ~isfield(config, 'Metadata') || ~isstruct(config.Metadata)
    config.Metadata = struct();
end
config.Metadata.RuntimeContracts = struct( ...
    'Frame', frame, ...
    'RuntimeTruth', truth, ...
    'RuntimePlanVersion', plan.Version);
end

function localRejectDeprecatedRawFields(config)
if isfield(config.Runner, 'FixedFrameLength')
    error('CSRD:RuntimePlan:DeprecatedRawField', ...
        'Runner.FixedFrameLength is forbidden; use Factories.Scenario.Global.FrameNumSamples.');
end
if isfield(config.Factories, 'Scenario') && ...
        isfield(config.Factories.Scenario, 'PhysicalEnvironment') && ...
        isfield(config.Factories.Scenario.PhysicalEnvironment, 'Map') && ...
        isfield(config.Factories.Scenario.PhysicalEnvironment.Map, 'OSM') && ...
        isfield(config.Factories.Scenario.PhysicalEnvironment.Map.OSM, 'MaxFileSizeMB')
    error('CSRD:RuntimePlan:DeprecatedRawField', ...
        'PhysicalEnvironment.Map.OSM.MaxFileSizeMB is forbidden; OSM selection is file-level balanced without size caps.');
end
if localHasFieldRecursive(config.Factories, 'SeedValue')
    error('CSRD:RuntimePlan:DeprecatedRawField', ...
        'SeedValue is forbidden in raw configuration; use Seed.');
end
if localHasFieldRecursive(config.Factories, 'SegmentID')
    error('CSRD:RuntimePlan:DeprecatedRawField', ...
        'SegmentID is forbidden in raw configuration; use SegmentId.');
end
end

function tf = localHasFieldRecursive(value, fieldName)
tf = false;
if isstruct(value)
    for idx = 1:numel(value)
        names = fieldnames(value(idx));
        if any(strcmp(names, fieldName))
            tf = true;
            return;
        end
        for k = 1:numel(names)
            if localHasFieldRecursive(value(idx).(names{k}), fieldName)
                tf = true;
                return;
            end
        end
    end
elseif iscell(value)
    for k = 1:numel(value)
        if localHasFieldRecursive(value{k}, fieldName)
            tf = true;
            return;
        end
    end
end
end

function seedPlan = localBuildSeedPlan(runnerConfig)
seedPlan = struct('Mode', 'fixed', 'RunSeed', [], ...
    'ScenarioSeedMethod', 'csrd.SimulationRunner.deriveScenarioSeed');
if isfield(runnerConfig, 'RandomSeed') && ~isempty(runnerConfig.RandomSeed)
    seed = runnerConfig.RandomSeed;
    if ischar(seed) || isstring(seed)
        seedPlan.Mode = char(string(seed));
    else
        seedPlan.RunSeed = double(seed);
    end
else
    seedPlan.Mode = 'unset';
end
end

function mapPlan = localBuildMapPlan(factoryConfigs)
mapPlan = struct( ...
    'OSMSelectionPolicy', 'BalancedFileCoverage', ...
    'SizeFiltering', 'Forbidden');
if ~isfield(factoryConfigs, 'Scenario') || ...
        ~isfield(factoryConfigs.Scenario, 'PhysicalEnvironment')
    return;
end
phys = factoryConfigs.Scenario.PhysicalEnvironment;
if isfield(phys, 'Map') && isstruct(phys.Map)
    if isfield(phys.Map, 'Types')
        mapPlan.Types = phys.Map.Types;
    end
    if isfield(phys.Map, 'Ratio')
        mapPlan.Ratio = phys.Map.Ratio;
    end
end
end
