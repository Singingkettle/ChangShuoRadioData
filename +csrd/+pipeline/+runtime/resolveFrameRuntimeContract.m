function contract = resolveFrameRuntimeContract(factoryConfigs, runnerConfig, varargin)
%RESOLVEFRAMERUNTIMECONTRACT Resolve the canonical frame/time contract.
% Inputs / 输入: see signature arguments and local validation.
% 输出 / Outputs: see signature return values and contract fields.
% 中文说明：集中解析运行期帧合同，避免 Runner、Scenario 和执行层各自解释帧长。
%
% Canonical input:
%   FactoryConfigs.Scenario.Global.FrameNumSamples
%
% Legacy aliases are rejected here:
%   FactoryConfigs.Scenario.Global.FrameLength
%   RunnerConfig.FixedFrameLength
%
% Units:
%   FrameNumSamples          samples per receiver frame
%   FrameDurationSec         seconds per receiver frame
%   ObservationDurationSec   seconds per scenario

opts = localParseOptions(varargin{:});
if nargin < 2 || isempty(runnerConfig)
    runnerConfig = struct();
end

scenarioConfig = localScenarioConfig(factoryConfigs);
if ~isfield(scenarioConfig, 'Global') || ~isstruct(scenarioConfig.Global)
    error('CSRD:Frame:MissingGlobalConfig', ...
        'FactoryConfigs.Scenario.Global is required for frame runtime contract resolution.');
end
globalConfig = scenarioConfig.Global;

sampleRateHz = opts.SampleRate;
if isempty(sampleRateHz)
    sampleRateHz = localReceiverSampleRate(scenarioConfig);
end
sampleRateHz = localRequirePositiveScalar(sampleRateHz, ...
    'FactoryConfigs.Scenario.CommunicationBehavior.Receiver.SampleRate', ...
    'CSRD:Frame:MissingSampleRate');

numFrames = localResolveNumFrames(globalConfig);

[frameNumSamples, source] = localResolveFrameSamples(globalConfig);

if isfield(runnerConfig, 'FixedFrameLength') && ~isempty(runnerConfig.FixedFrameLength)
    error('CSRD:Frame:DeprecatedRunnerFixedFrameLength', ...
        ['Runner.FixedFrameLength is deprecated and forbidden. ', ...
         'Use Factories.Scenario.Global.FrameNumSamples as the only frame-length authority.']);
end

frameDurationSec = frameNumSamples / sampleRateHz;
if isfield(globalConfig, 'FrameDuration') && ~isempty(globalConfig.FrameDuration)
    declaredFrameDuration = localRequirePositiveScalar(globalConfig.FrameDuration, ...
        'Factories.Scenario.Global.FrameDuration', ...
        'CSRD:Frame:InvalidFrameDuration');
    localAssertDurationMatchesSamples(declaredFrameDuration, frameNumSamples, ...
        sampleRateHz, 'Factories.Scenario.Global.FrameDuration');
    frameDurationSec = declaredFrameDuration;
end

observationDurationSec = frameDurationSec * numFrames;
if isfield(globalConfig, 'ObservationDuration') && ~isempty(globalConfig.ObservationDuration)
    declaredObservationDuration = localRequirePositiveScalar( ...
        globalConfig.ObservationDuration, ...
        'Factories.Scenario.Global.ObservationDuration', ...
        'CSRD:Frame:InvalidObservationDuration');
    expectedSamples = declaredObservationDuration * sampleRateHz;
    canonicalSamples = frameNumSamples * numFrames;
    if opts.StrictObservationDuration && abs(expectedSamples - canonicalSamples) > 1
        error('CSRD:Frame:InconsistentObservationDuration', ...
            ['ObservationDuration*SampleRate=%g but ', ...
             'FrameNumSamples*NumFramesPerScenario=%g.'], ...
            expectedSamples, canonicalSamples);
    end
    observationDurationSec = declaredObservationDuration;
end

if ~isempty(opts.FrameWindow)
    frameWindow = double(opts.FrameWindow(1:2));
    if any(~isfinite(frameWindow)) || frameWindow(2) <= frameWindow(1)
        error('CSRD:Frame:InvalidFrameWindow', ...
            'FrameWindow must be a finite 1x2 [start end] vector in seconds.');
    end
    localAssertDurationMatchesSamples(frameWindow(2) - frameWindow(1), ...
        frameNumSamples, sampleRateHz, 'SignalComponents.FrameWindow');
else
    frameWindow = [0, frameDurationSec];
end

contract = struct( ...
    'FrameNumSamples', frameNumSamples, ...
    'FrameDurationSec', frameDurationSec, ...
    'FrameWindowSec', frameWindow, ...
    'SampleRateHz', sampleRateHz, ...
    'NumFramesPerScenario', numFrames, ...
    'ObservationDurationSec', observationDurationSec, ...
    'Source', source, ...
    'LegacyAliasUsed', false);
end

function opts = localParseOptions(varargin)
    % localParseOptions - Production declaration in CSRD.
    % 中文说明：localParseOptions 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
opts = struct( ...
    'SampleRate', [], ...
    'FrameWindow', [], ...
    'StrictObservationDuration', true);
if mod(numel(varargin), 2) ~= 0
    error('CSRD:Frame:InvalidOptions', ...
        'resolveFrameRuntimeContract options must be name-value pairs.');
end
for k = 1:2:numel(varargin)
    name = char(string(varargin{k}));
    if ~isfield(opts, name)
        error('CSRD:Frame:InvalidOptions', ...
            'Unknown resolveFrameRuntimeContract option "%s".', name);
    end
    opts.(name) = varargin{k + 1};
end
end

function scenarioConfig = localScenarioConfig(factoryConfigs)
    % localScenarioConfig - Production declaration in CSRD.
    % 中文说明：localScenarioConfig 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
if nargin < 1 || isempty(factoryConfigs) || ~isstruct(factoryConfigs)
    error('CSRD:Frame:MissingFactoryConfigs', ...
        'FactoryConfigs must be a struct containing Scenario.');
end
if isfield(factoryConfigs, 'Scenario') && isstruct(factoryConfigs.Scenario)
    scenarioConfig = factoryConfigs.Scenario;
elseif isfield(factoryConfigs, 'Factories') && isstruct(factoryConfigs.Factories) && ...
        isfield(factoryConfigs.Factories, 'Scenario') && ...
        isstruct(factoryConfigs.Factories.Scenario)
    scenarioConfig = factoryConfigs.Factories.Scenario;
else
    error('CSRD:Frame:MissingScenarioConfig', ...
        'FactoryConfigs.Scenario is required for frame runtime contract resolution.');
end
end

function sampleRateHz = localReceiverSampleRate(scenarioConfig)
    % localReceiverSampleRate - Production declaration in CSRD.
    % 中文说明：localReceiverSampleRate 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
sampleRateHz = [];
if isfield(scenarioConfig, 'CommunicationBehavior') && ...
        isstruct(scenarioConfig.CommunicationBehavior) && ...
        isfield(scenarioConfig.CommunicationBehavior, 'Receiver') && ...
        isstruct(scenarioConfig.CommunicationBehavior.Receiver) && ...
        isfield(scenarioConfig.CommunicationBehavior.Receiver, 'SampleRate')
    sampleRateHz = scenarioConfig.CommunicationBehavior.Receiver.SampleRate;
end
end

function numFrames = localResolveNumFrames(globalConfig)
    % localResolveNumFrames - Production declaration in CSRD.
    % 中文说明：localResolveNumFrames 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
if isfield(globalConfig, 'NumFramesPerScenario') && ...
        ~isempty(globalConfig.NumFramesPerScenario)
    raw = globalConfig.NumFramesPerScenario;
elseif isfield(globalConfig, 'NumFrames') && ~isempty(globalConfig.NumFrames)
    raw = globalConfig.NumFrames;
else
    error('CSRD:Frame:MissingNumFramesPerScenario', ...
        'Factories.Scenario.Global.NumFramesPerScenario is required.');
end
numFrames = localRequirePositiveInteger(raw, ...
    'Factories.Scenario.Global.NumFramesPerScenario', ...
    'CSRD:Frame:InvalidNumFramesPerScenario');
end

function [frameNumSamples, source] = localResolveFrameSamples(globalConfig)
    % localResolveFrameSamples - Production declaration in CSRD.
    % 中文说明：localResolveFrameSamples 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
if isfield(globalConfig, 'FrameNumSamples') && ~isempty(globalConfig.FrameNumSamples)
    frameNumSamples = localRequirePositiveInteger(globalConfig.FrameNumSamples, ...
        'Factories.Scenario.Global.FrameNumSamples', ...
        'CSRD:Frame:InvalidFrameNumSamples');
    source = 'Factories.Scenario.Global.FrameNumSamples';
    return;
end
if isfield(globalConfig, 'FrameLength') && ~isempty(globalConfig.FrameLength)
    error('CSRD:Frame:DeprecatedFrameLengthAlias', ...
        ['Factories.Scenario.Global.FrameLength is forbidden. ', ...
         'Use Factories.Scenario.Global.FrameNumSamples only.']);
end
error('CSRD:Frame:MissingFrameNumSamples', ...
    ['Factories.Scenario.Global.FrameNumSamples is required. ', ...
     'FrameDuration and ObservationDuration are validation fields, not frame-length authorities.']);
end

function value = localRequirePositiveInteger(value, fieldName, errorId)
    % localRequirePositiveInteger - Production declaration in CSRD.
    % 中文说明：localRequirePositiveInteger 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
value = localRequirePositiveScalar(value, fieldName, errorId);
rounded = round(value);
if abs(value - rounded) > 0
    error(errorId, '%s must be a positive integer scalar.', fieldName);
end
value = rounded;
end

function value = localRequirePositiveScalar(value, fieldName, errorId)
    % localRequirePositiveScalar - Production declaration in CSRD.
    % 中文说明：localRequirePositiveScalar 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
    error(errorId, '%s must be a positive finite scalar.', fieldName);
end
value = double(value);
end

function localAssertDurationMatchesSamples(durationSec, frameSamples, sampleRateHz, label)
    % localAssertDurationMatchesSamples - Production declaration in CSRD.
    % 中文说明：localAssertDurationMatchesSamples 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
computedSamples = durationSec * sampleRateHz;
if abs(computedSamples - frameSamples) > 1
    error('CSRD:Frame:InconsistentFrameSamples', ...
        '%s resolves to %g samples but FrameNumSamples is %d.', ...
        label, computedSamples, frameSamples);
end
end
