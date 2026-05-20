function cfg = applyCanonicalFrameContract(cfg, observationDurationSec, numFrames)
%APPLYCANONICALFRAMECONTRACT Write the strict Phase 30 frame authority.
% 中文说明：测试辅助函数；只写 raw config 权威字段，不写派生字段。

if nargin < 3
    error('CSRD:TestSupport:FrameContractArgs', ...
        'observationDurationSec and numFrames are required.');
end
if ~isnumeric(observationDurationSec) || ~isscalar(observationDurationSec) || ...
        ~isfinite(observationDurationSec) || observationDurationSec <= 0
    error('CSRD:TestSupport:InvalidObservationDuration', ...
        'observationDurationSec must be a positive finite scalar.');
end
if ~isnumeric(numFrames) || ~isscalar(numFrames) || ...
        ~isfinite(numFrames) || numFrames <= 0 || numFrames ~= round(numFrames)
    error('CSRD:TestSupport:InvalidNumFrames', ...
        'numFrames must be a positive integer scalar.');
end

[scenarioConfig, target] = localScenarioConfig(cfg);
sampleRateHz = localReceiverSampleRate(scenarioConfig);
frameSamples = round((double(observationDurationSec) / double(numFrames)) * ...
    sampleRateHz);
if frameSamples <= 0
    error('CSRD:TestSupport:InvalidFrameSamples', ...
        'Resolved FrameNumSamples must be positive.');
end
scenarioConfig.Global.NumFramesPerScenario = double(numFrames);
scenarioConfig.Global.FrameNumSamples = frameSamples;

switch target
    case 'master'
        cfg.Factories.Scenario = scenarioConfig;
    case 'scenario'
        cfg = scenarioConfig;
end
end

function [scenarioConfig, target] = localScenarioConfig(cfg)
if isfield(cfg, 'Factories') && isstruct(cfg.Factories) && ...
        isfield(cfg.Factories, 'Scenario') && isstruct(cfg.Factories.Scenario)
    scenarioConfig = cfg.Factories.Scenario;
    target = 'master';
elseif isfield(cfg, 'Global') && isstruct(cfg.Global)
    scenarioConfig = cfg;
    target = 'scenario';
else
    error('CSRD:TestSupport:MissingScenarioConfig', ...
        'cfg must be a master config or a Scenario config struct.');
end
if ~isfield(scenarioConfig, 'Global') || ~isstruct(scenarioConfig.Global)
    scenarioConfig.Global = struct();
end
end

function sampleRateHz = localReceiverSampleRate(scenarioConfig)
if ~isfield(scenarioConfig, 'CommunicationBehavior') || ...
        ~isstruct(scenarioConfig.CommunicationBehavior) || ...
        ~isfield(scenarioConfig.CommunicationBehavior, 'Receiver') || ...
        ~isstruct(scenarioConfig.CommunicationBehavior.Receiver) || ...
        ~isfield(scenarioConfig.CommunicationBehavior.Receiver, 'SampleRate')
    error('CSRD:TestSupport:MissingSampleRate', ...
        'Scenario.CommunicationBehavior.Receiver.SampleRate is required.');
end
sampleRateHz = scenarioConfig.CommunicationBehavior.Receiver.SampleRate;
if ~isnumeric(sampleRateHz) || ~isscalar(sampleRateHz) || ...
        ~isfinite(sampleRateHz) || sampleRateHz <= 0
    error('CSRD:TestSupport:InvalidSampleRate', ...
        'Scenario.CommunicationBehavior.Receiver.SampleRate must be positive.');
end
sampleRateHz = double(sampleRateHz);
end
