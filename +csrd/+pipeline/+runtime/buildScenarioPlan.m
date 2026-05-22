function scenarioPlan = buildScenarioPlan(runtimePlan, scenarioConfig, runtimeContext)
%BUILDSCENARIOPLAN Resolve per-scenario execution facts from run policies.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.

if nargin < 1 || isempty(runtimePlan) || ~isstruct(runtimePlan)
    error('CSRD:ScenarioPlan:MissingRuntimePlan', ...
        'RuntimePlan with run-level policies is required.');
end
if nargin < 2 || isempty(scenarioConfig) || ~isstruct(scenarioConfig)
    error('CSRD:ScenarioPlan:MissingScenarioConfig', ...
        'Scenario config is required to build ScenarioPlan.');
end
if nargin < 3 || isempty(runtimeContext) || ~isstruct(runtimeContext)
    runtimeContext = struct();
end
if ~isfield(runtimePlan, 'FramePolicy') || ...
        ~isstruct(runtimePlan.FramePolicy)
    error('CSRD:ScenarioPlan:MissingFramePolicy', ...
        'RuntimePlan.FramePolicy is required.');
end

scenarioId = localPositiveInteger(runtimeContext, 'ScenarioId', 1);
scenarioSeed = localScenarioSeed(runtimeContext, scenarioId);
sampleRateHz = localReceiverSampleRate(scenarioConfig);
frame = localResolveScenarioFrame(runtimePlan.FramePolicy, ...
    sampleRateHz, scenarioSeed, scenarioId);

scenarioPlan = struct();
scenarioPlan.Version = 'ScenarioPlan.v1';
scenarioPlan.ScenarioId = scenarioId;
scenarioPlan.Seed = scenarioSeed;
scenarioPlan.Frame = frame;
scenarioPlan.Map = struct();
scenarioPlan.Entities = struct();
scenarioPlan.Receivers = [];
scenarioPlan.Transmitters = [];
scenarioPlan.Communication = struct();
scenarioPlan.DatasetAccounting = struct( ...
    'NumReceivers', 0, ...
    'NumFramesPerScenario', frame.NumFramesPerScenario, ...
    'NumReceiverFrames', 0);
end

function frame = localResolveScenarioFrame(framePolicy, sampleRateHz, seed, scenarioId)
    % localResolveScenarioFrame - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
frameSamples = localSelectFrameSamples(framePolicy.FrameNumSamples, seed, scenarioId);
numFrames = localSelectNumFrames(framePolicy.NumFramesPerScenario, seed, scenarioId);
frameDuration = frameSamples / sampleRateHz;
frame = struct( ...
    'FrameNumSamples', frameSamples, ...
    'NumFramesPerScenario', numFrames, ...
    'SampleRateHz', sampleRateHz, ...
    'FrameDurationSec', frameDuration, ...
    'ObservationDurationSec', frameDuration * numFrames, ...
    'Scope', 'Scenario', ...
    'Source', 'ScenarioPlan.Frame');
end

function frameSamples = localSelectFrameSamples(policy, seed, scenarioId)
    % localSelectFrameSamples - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
switch lower(char(string(policy.Mode)))
    case 'fixed'
        frameSamples = double(policy.Value);
    case 'choice'
        values = double(policy.Values(:));
        weights = double(policy.Weights(:));
        weights = weights ./ sum(weights);
        u = localDeterministicUnit(seed, scenarioId, 101);
        edges = cumsum(weights);
        idx = find(u <= edges, 1, 'first');
        if isempty(idx)
            idx = numel(values);
        end
        frameSamples = values(idx);
    otherwise
        error('CSRD:ScenarioPlan:InvalidFramePolicy', ...
            'Unsupported FrameNumSamples policy mode "%s".', policy.Mode);
end
frameSamples = round(frameSamples);
end

function numFrames = localSelectNumFrames(policy, seed, scenarioId)
    % localSelectNumFrames - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
switch lower(char(string(policy.Mode)))
    case 'fixed'
        numFrames = double(policy.Value);
    case 'integerrange'
        minValue = double(policy.Min);
        maxValue = double(policy.Max);
        span = maxValue - minValue + 1;
        u = localDeterministicUnit(seed, scenarioId, 211);
        numFrames = minValue + floor(u * span);
        numFrames = min(max(numFrames, minValue), maxValue);
    otherwise
        error('CSRD:ScenarioPlan:InvalidFramePolicy', ...
            'Unsupported NumFramesPerScenario policy mode "%s".', policy.Mode);
end
numFrames = round(numFrames);
end

function sampleRateHz = localReceiverSampleRate(scenarioConfig)
    % localReceiverSampleRate - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if ~isfield(scenarioConfig, 'CommunicationBehavior') || ...
        ~isstruct(scenarioConfig.CommunicationBehavior) || ...
        ~isfield(scenarioConfig.CommunicationBehavior, 'Receiver') || ...
        ~isstruct(scenarioConfig.CommunicationBehavior.Receiver) || ...
        ~isfield(scenarioConfig.CommunicationBehavior.Receiver, 'SampleRate')
    error('CSRD:ScenarioPlan:MissingSampleRate', ...
        'CommunicationBehavior.Receiver.SampleRate is required.');
end
sampleRateHz = scenarioConfig.CommunicationBehavior.Receiver.SampleRate;
if ~isnumeric(sampleRateHz) || ~isscalar(sampleRateHz) || ...
        ~isfinite(sampleRateHz) || sampleRateHz <= 0
    error('CSRD:ScenarioPlan:InvalidSampleRate', ...
        'CommunicationBehavior.Receiver.SampleRate must be positive.');
end
sampleRateHz = double(sampleRateHz);
end

function scenarioId = localPositiveInteger(runtimeContext, fieldName, defaultValue)
    % localPositiveInteger - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
scenarioId = defaultValue;
if isfield(runtimeContext, fieldName) && ~isempty(runtimeContext.(fieldName))
    candidate = runtimeContext.(fieldName);
    if isnumeric(candidate) && isscalar(candidate) && isfinite(candidate) && ...
            candidate >= 1
        scenarioId = floor(double(candidate));
    end
end
end

function seed = localScenarioSeed(runtimeContext, scenarioId)
    % localScenarioSeed - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isfield(runtimeContext, 'ScenarioSeed') && ...
        isnumeric(runtimeContext.ScenarioSeed) && ...
        isscalar(runtimeContext.ScenarioSeed) && ...
        isfinite(runtimeContext.ScenarioSeed)
    seed = double(runtimeContext.ScenarioSeed);
elseif isfield(runtimeContext, 'RandomSeed') && ...
        isnumeric(runtimeContext.RandomSeed) && ...
        isscalar(runtimeContext.RandomSeed) && ...
        isfinite(runtimeContext.RandomSeed)
    seed = double(runtimeContext.RandomSeed) + scenarioId * 1000003;
else
    seed = scenarioId * 1000003;
end
seed = mod(abs(floor(seed)), 2^31 - 2) + 1;
end

function u = localDeterministicUnit(seed, scenarioId, salt)
    % localDeterministicUnit - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
state = uint64(seed) + uint64(scenarioId) * uint64(1103515245) + ...
    uint64(salt) * uint64(12345);
state = mod(state, uint64(2147483647));
state = mod(state * uint64(48271), uint64(2147483647));
u = double(state) / double(uint64(2147483647));
if u <= 0
    u = eps;
elseif u >= 1
    u = 1 - eps;
end
end
