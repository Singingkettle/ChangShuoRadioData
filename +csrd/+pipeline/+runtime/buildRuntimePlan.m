function config = buildRuntimePlan(config)
%BUILDRUNTIMEPLAN Build the canonical runtime plan from raw configuration.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.

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
config = localCapReceiverToSdr(config);

framePolicy = localBuildFramePolicy(config.Factories);
loggingPlan = localBuildLoggingPlan(config);
truth = csrd.pipeline.runtime.validateRuntimeTruthContracts( ...
    config.Factories, config.Runner);

plan = struct();
plan.Version = 'RuntimePlan.v1';
plan.ConfigFingerprint = csrd.pipeline.runtime.runtimeConfigFingerprint( ...
    config.Runner, config.Factories);
plan.FramePolicy = framePolicy;
plan.Logging = loggingPlan;
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
    'FramePolicy', framePolicy, ...
    'Logging', loggingPlan, ...
    'RuntimeTruth', truth, ...
    'RuntimePlanVersion', plan.Version, ...
    'ConfigFingerprint', plan.ConfigFingerprint);
end

function localRejectDeprecatedRawFields(config)
    % localRejectDeprecatedRawFields - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isfield(config, 'Log')
    error('CSRD:RuntimePlan:DeprecatedRawField', ...
        'Top-level Log is forbidden after Phase 35; use top-level Logging.');
end
if isfield(config.Runner, 'Log')
    error('CSRD:RuntimePlan:DeprecatedRawField', ...
        'Runner.Log is forbidden after Phase 35; use top-level Logging.');
end
if isfield(config.Runner, 'FixedFrameLength')
    error('CSRD:RuntimePlan:DeprecatedRawField', ...
        'Runner.FixedFrameLength is forbidden; use Factories.Scenario.FramePolicy.');
end
if isfield(config.Factories, 'Scenario') && ...
        isfield(config.Factories.Scenario, 'Global') && ...
        isstruct(config.Factories.Scenario.Global)
    globalConfig = config.Factories.Scenario.Global;
    forbiddenGlobalFields = {'FrameNumSamples', 'FrameLength', ...
        'NumFramesPerScenario', 'NumFrames', 'FrameDuration', ...
        'ObservationDuration', 'TimeResolution'};
    for k = 1:numel(forbiddenGlobalFields)
        field = forbiddenGlobalFields{k};
        if isfield(globalConfig, field) && ~isempty(globalConfig.(field))
            error('CSRD:RuntimePlan:DeprecatedRawField', ...
                ['Factories.Scenario.Global.%s is forbidden after Phase 33; ', ...
                 'use Factories.Scenario.FramePolicy.'], field);
        end
    end
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

function config = localCapReceiverToSdr(config)
    % localCapReceiverToSdr - Cap the receiver authority to the SDR capability.
    % Inputs: full config struct.
    % Outputs: config whose CommunicationBehavior.Receiver SampleRate and
    %   NumAntennas are capped to the selected SDR model's instantaneous
    %   bandwidth and channel count. This must happen before the frame
    %   contract and the scenario plan read the receiver sample rate, so the
    %   planned frame shape matches the rate actually used at generation time.
    if ~isfield(config.Factories, 'Scenario') || ...
            ~isfield(config.Factories.Scenario, 'CommunicationBehavior') || ...
            ~isfield(config.Factories.Scenario.CommunicationBehavior, 'Receiver')
        return;
    end
    rx = config.Factories.Scenario.CommunicationBehavior.Receiver;
    if ~isfield(rx, 'Sdr') || ~isstruct(rx.Sdr) || ...
            ~isfield(rx.Sdr, 'Model') || isempty(rx.Sdr.Model)
        return;
    end
    profile = csrd.catalog.receiver.SdrReceiverCatalog.load(rx.Sdr.Model);
    if isfield(rx, 'SampleRate') && ~isempty(rx.SampleRate) && ...
            rx.SampleRate > profile.MaxInstantaneousBandwidthHz
        rx.SampleRate = profile.MaxInstantaneousBandwidthHz;
    end
    if isfield(rx, 'NumAntennas') && ~isempty(rx.NumAntennas) && ...
            rx.NumAntennas > profile.NumChannels
        rx.NumAntennas = profile.NumChannels;
    end
    config.Factories.Scenario.CommunicationBehavior.Receiver = rx;
end

function loggingPlan = localBuildLoggingPlan(config)
    % localBuildLoggingPlan - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
raw = struct();
if isfield(config, 'Logging') && isstruct(config.Logging)
    raw = config.Logging;
end

policyName = 'Standard';
if isfield(raw, 'Policy') && ~isempty(raw.Policy)
    policyName = char(string(raw.Policy));
end
policy = csrd.runtime.logger.policy.LogPolicy(policyName);
desc = policy.describe();

loggingPlan = struct();
loggingPlan.Policy = desc.Level;
loggingPlan.ConsoleThreshold = desc.ConsoleThreshold;
loggingPlan.FileThreshold = desc.FileThreshold;
loggingPlan.ConsoleEnabled = localOptionalLogical(raw, {'Console', 'Enabled'}, true);
loggingPlan.FileEnabled = localOptionalLogical(raw, {'File', 'Enabled'}, true);
loggingPlan.ProgressMode = localProgressMode(raw);
loggingPlan.Name = localOptionalText(raw, 'Name', 'CSRD');
loggingPlan.TimestampFormat = localOptionalText(raw, ...
    'TimestampFormat', 'yyyy-MM-dd HH:mm:ss.SSS');
loggingPlan.IncludeStackTrace = localOptionalLogical(raw, ...
    {'IncludeStackTrace'}, false);
loggingPlan.Fingerprint = sprintf('fnv1a32:%08x', ...
    localFnv1a32(uint8(jsonencode(localCanonicalize(raw)))));
loggingPlan.Source = 'config.Logging';
end

function value = localOptionalText(source, fieldName, defaultValue)
    % localOptionalText - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
value = char(defaultValue);
if isstruct(source) && isfield(source, fieldName) && ~isempty(source.(fieldName))
    value = char(string(source.(fieldName)));
end
end

function value = localOptionalLogical(source, pathParts, defaultValue)
    % localOptionalLogical - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
value = logical(defaultValue);
if ~isstruct(source)
    return;
end
current = source;
for idx = 1:numel(pathParts)
    part = pathParts{idx};
    if ~isstruct(current) || ~isfield(current, part)
        return;
    end
    current = current.(part);
end
if islogical(current) && isscalar(current)
    value = current;
elseif isnumeric(current) && isscalar(current) && isfinite(current)
    value = current ~= 0;
elseif ischar(current) || (isstring(current) && isscalar(current))
    value = any(strcmpi(char(string(current)), {'true', 'on', 'yes', '1'}));
end
end

function mode = localProgressMode(raw)
    % localProgressMode - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
mode = 'Summary';
if isfield(raw, 'Progress') && isstruct(raw.Progress) && ...
        isfield(raw.Progress, 'Mode') && ~isempty(raw.Progress.Mode)
    mode = char(string(raw.Progress.Mode));
end
allowed = {'Detailed', 'Summary'};
idx = find(strcmpi(mode, allowed), 1, 'first');
if isempty(idx)
    error('CSRD:RuntimePlan:InvalidLoggingPolicy', ...
        'Logging.Progress.Mode must be Detailed or Summary.');
end
mode = allowed{idx};
end

function framePolicy = localBuildFramePolicy(factoryConfigs)
    % localBuildFramePolicy - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if ~isfield(factoryConfigs, 'Scenario') || ~isstruct(factoryConfigs.Scenario)
    error('CSRD:RuntimePlan:MissingScenarioConfig', ...
        'Factories.Scenario is required to build RuntimePlan.FramePolicy.');
end
scenario = factoryConfigs.Scenario;
if ~isfield(scenario, 'FramePolicy') || ~isstruct(scenario.FramePolicy)
    error('CSRD:RuntimePlan:MissingFramePolicy', ...
        'Factories.Scenario.FramePolicy is required.');
end
policy = scenario.FramePolicy;
if ~isfield(policy, 'FrameNumSamples') || ~isstruct(policy.FrameNumSamples)
    error('CSRD:RuntimePlan:MissingFramePolicy', ...
        'Factories.Scenario.FramePolicy.FrameNumSamples is required.');
end
if ~isfield(policy, 'NumFramesPerScenario') || ...
        ~isstruct(policy.NumFramesPerScenario)
    error('CSRD:RuntimePlan:MissingFramePolicy', ...
        'Factories.Scenario.FramePolicy.NumFramesPerScenario is required.');
end

framePolicy = struct();
framePolicy.FrameNumSamples = localNormalizeFrameSamplesPolicy( ...
    policy.FrameNumSamples);
framePolicy.NumFramesPerScenario = localNormalizeNumFramesPolicy( ...
    policy.NumFramesPerScenario);
framePolicy.SampleRateAuthority = ...
    'Factories.Scenario.CommunicationBehavior.Receiver.SampleRate';
framePolicy.Scope = 'Scenario';
end

function policy = localNormalizeFrameSamplesPolicy(raw)
    % localNormalizeFrameSamplesPolicy - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
policy = struct();
policy.Mode = localRequireMode(raw, {'Fixed', 'Choice'}, ...
    'FramePolicy.FrameNumSamples.Mode');
switch lower(policy.Mode)
    case 'fixed'
        value = localRequirePositiveInteger(raw, 'Value', ...
            'FramePolicy.FrameNumSamples.Value');
        policy.Value = value;
        policy.Values = value;
        policy.Weights = 1;
    case 'choice'
        values = localRequirePositiveIntegerVector(raw, 'Values', ...
            'FramePolicy.FrameNumSamples.Values');
        policy.Values = values(:).';
        policy.Weights = localNormalizeWeights(raw, numel(policy.Values), ...
            'FramePolicy.FrameNumSamples.Weights');
end
end

function policy = localNormalizeNumFramesPolicy(raw)
    % localNormalizeNumFramesPolicy - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
policy = struct();
policy.Mode = localRequireMode(raw, {'Fixed', 'IntegerRange'}, ...
    'FramePolicy.NumFramesPerScenario.Mode');
switch lower(policy.Mode)
    case 'fixed'
        value = localRequirePositiveInteger(raw, 'Value', ...
            'FramePolicy.NumFramesPerScenario.Value');
        policy.Value = value;
        policy.Min = value;
        policy.Max = value;
    case 'integerrange'
        minValue = localRequirePositiveInteger(raw, 'Min', ...
            'FramePolicy.NumFramesPerScenario.Min');
        maxValue = localRequirePositiveInteger(raw, 'Max', ...
            'FramePolicy.NumFramesPerScenario.Max');
        if maxValue < minValue
            error('CSRD:RuntimePlan:InvalidFramePolicy', ...
                'FramePolicy.NumFramesPerScenario.Max must be >= Min.');
        end
        policy.Min = minValue;
        policy.Max = maxValue;
end
end

function mode = localRequireMode(raw, allowedModes, label)
    % localRequireMode - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if ~isfield(raw, 'Mode') || isempty(raw.Mode)
    error('CSRD:RuntimePlan:InvalidFramePolicy', '%s is required.', label);
end
mode = char(string(raw.Mode));
if ~any(strcmpi(mode, allowedModes))
    error('CSRD:RuntimePlan:InvalidFramePolicy', ...
        '%s must be one of: %s.', label, strjoin(allowedModes, ', '));
end
canonical = allowedModes{find(strcmpi(mode, allowedModes), 1, 'first')};
mode = canonical;
end

function value = localRequirePositiveInteger(raw, fieldName, label)
    % localRequirePositiveInteger - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if ~isfield(raw, fieldName) || isempty(raw.(fieldName)) || ...
        ~isnumeric(raw.(fieldName)) || ~isscalar(raw.(fieldName)) || ...
        ~isfinite(raw.(fieldName)) || raw.(fieldName) <= 0
    error('CSRD:RuntimePlan:InvalidFramePolicy', ...
        '%s must be a positive finite integer scalar.', label);
end
value = double(raw.(fieldName));
rounded = round(value);
if abs(value - rounded) > 0
    error('CSRD:RuntimePlan:InvalidFramePolicy', ...
        '%s must be an integer scalar.', label);
end
value = rounded;
end

function values = localRequirePositiveIntegerVector(raw, fieldName, label)
    % localRequirePositiveIntegerVector - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if ~isfield(raw, fieldName) || isempty(raw.(fieldName)) || ...
        ~isnumeric(raw.(fieldName)) || any(~isfinite(raw.(fieldName)(:))) || ...
        any(raw.(fieldName)(:) <= 0)
    error('CSRD:RuntimePlan:InvalidFramePolicy', ...
        '%s must be a nonempty positive finite integer vector.', label);
end
values = double(raw.(fieldName)(:));
if any(abs(values - round(values)) > 0)
    error('CSRD:RuntimePlan:InvalidFramePolicy', ...
        '%s must contain integer values.', label);
end
values = round(values);
end

function weights = localNormalizeWeights(raw, count, label)
    % localNormalizeWeights - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isfield(raw, 'Weights') && ~isempty(raw.Weights)
    weights = double(raw.Weights(:));
    if numel(weights) ~= count || any(~isfinite(weights)) || ...
            any(weights < 0) || sum(weights) <= 0
        error('CSRD:RuntimePlan:InvalidFramePolicy', ...
            '%s must match Values length and have positive sum.', label);
    end
    weights = weights ./ sum(weights);
else
    weights = ones(count, 1) ./ count;
end
weights = weights(:).';
end

function tf = localHasFieldRecursive(value, fieldName)
    % localHasFieldRecursive - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
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

function value = localCanonicalize(value)
    % localCanonicalize - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isstruct(value)
    if isempty(value)
        value = struct();
        return;
    end
    for idx = 1:numel(value)
        names = sort(fieldnames(value(idx)));
        out = struct();
        for k = 1:numel(names)
            out.(names{k}) = localCanonicalize(value(idx).(names{k}));
        end
        if idx == 1
            canonical = repmat(out, size(value));
        end
        canonical(idx) = out; %#ok<AGROW>
    end
    value = canonical;
elseif iscell(value)
    for k = 1:numel(value)
        value{k} = localCanonicalize(value{k});
    end
elseif isstring(value)
    value = cellstr(value);
elseif isa(value, 'datetime')
    value = char(value);
end
end

function hash = localFnv1a32(bytes)
    % localFnv1a32 - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
hash = uint32(2166136261);
prime = uint32(16777619);
for idx = 1:numel(bytes)
    hash = bitxor(hash, uint32(bytes(idx)));
    hash = uint32(mod(uint64(hash) * uint64(prime), uint64(2^32)));
end
end

function seedPlan = localBuildSeedPlan(runnerConfig)
    % localBuildSeedPlan - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
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
    % localBuildMapPlan - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
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
