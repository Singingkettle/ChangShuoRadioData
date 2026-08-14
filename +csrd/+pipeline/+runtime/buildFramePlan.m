function framePlan = buildFramePlan(scenarioPlan, frameId)
%BUILDFRAMEPLAN Resolve one frame window from a frozen ScenarioPlan.
% Inputs: scenarioPlan - frozen plan whose .Frame carries the contract;
%         frameId - positive integer frame index.
% Outputs: framePlan - struct with FrameId, ScenarioId, FrameNumSamples,
%          SampleRateHz, FrameDurationSec, start/end times and Source.

if nargin < 1 || ~isstruct(scenarioPlan) || ...
        ~isfield(scenarioPlan, 'Frame') || ~isstruct(scenarioPlan.Frame)
    error('CSRD:FramePlan:MissingScenarioFrame', ...
        'ScenarioPlan.Frame is required to build a FramePlan.');
end
if nargin < 2 || isempty(frameId) || ~isnumeric(frameId) || ...
        ~isscalar(frameId) || ~isfinite(frameId) || frameId < 1 || ...
        abs(frameId - round(frameId)) > 0
    error('CSRD:FramePlan:InvalidFrameId', ...
        'frameId must be a positive integer scalar.');
end

frame = scenarioPlan.Frame;
localRequirePositiveInteger(frame, 'FrameNumSamples');
localRequirePositiveInteger(frame, 'NumFramesPerScenario');
localRequirePositiveScalar(frame, 'SampleRateHz');
localRequirePositiveScalar(frame, 'FrameDurationSec');

if frameId > frame.NumFramesPerScenario
    error('CSRD:FramePlan:FrameOutOfRange', ...
        'frameId %d exceeds ScenarioPlan.Frame.NumFramesPerScenario=%d.', ...
        frameId, frame.NumFramesPerScenario);
end

frameStartSec = (double(frameId) - 1) * double(frame.FrameDurationSec);
frameEndSec = double(frameId) * double(frame.FrameDurationSec);

framePlan = struct( ...
    'FrameId', double(frameId), ...
    'FrameWindowSec', [frameStartSec, frameEndSec], ...
    'StartTimeSec', frameStartSec, ...
    'EndTimeSec', frameEndSec, ...
    'DurationSec', double(frame.FrameDurationSec), ...
    'FrameNumSamples', double(frame.FrameNumSamples), ...
    'SampleRateHz', double(frame.SampleRateHz), ...
    'ScenarioId', localScenarioId(scenarioPlan), ...
    'Source', 'ScenarioPlan.Frame');
end

function localRequirePositiveInteger(s, fieldName)
    % localRequirePositiveInteger - positive-scalar check plus integer-valued check.
localRequirePositiveScalar(s, fieldName);
if abs(double(s.(fieldName)) - round(double(s.(fieldName)))) > 0
    error('CSRD:FramePlan:InvalidFrameContract', ...
        'ScenarioPlan.Frame.%s must be integer-valued.', fieldName);
end
end

function localRequirePositiveScalar(s, fieldName)
    % localRequirePositiveScalar - error unless the field is a positive finite scalar.
if ~isfield(s, fieldName) || isempty(s.(fieldName)) || ...
        ~isnumeric(s.(fieldName)) || ~isscalar(s.(fieldName)) || ...
        ~isfinite(s.(fieldName)) || s.(fieldName) <= 0
    error('CSRD:FramePlan:InvalidFrameContract', ...
        'ScenarioPlan.Frame.%s must be a positive finite scalar.', fieldName);
end
end

function scenarioId = localScenarioId(scenarioPlan)
    % localScenarioId - the plan scenario id as a double, NaN when absent.
scenarioId = NaN;
if isfield(scenarioPlan, 'ScenarioId') && isnumeric(scenarioPlan.ScenarioId) && ...
        isscalar(scenarioPlan.ScenarioId)
    scenarioId = double(scenarioPlan.ScenarioId);
end
end
