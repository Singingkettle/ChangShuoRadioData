function signalStruct = gateToDuration(signalStruct, durationSec, stageName)
%GATETODURATION Align a signal struct to an explicit duration.
% 中文说明：把信号结构体显式裁剪或补零到指定持续时间，并记录 gating 元数据。
% Inputs / 输入: signalStruct is a signal struct; durationSec is seconds; stageName names the caller stage.
% Outputs / 输出: signalStruct is the aligned signal struct with GatingMetadata.
%
%   signalStruct = csrd.pipeline.signal.gateToDuration(signalStruct,
%       durationSec, stageName)
%
% The helper preserves columns/antennas and records whether the stage
% padded, trimmed, or left the signal unchanged. Duration is in seconds;
% samples are computed on signalStruct.SampleRate.

    if nargin < 3 || isempty(stageName)
        stageName = 'unspecified';
    end

    if ~isstruct(signalStruct) || ~isfield(signalStruct, 'Signal')
        error('CSRD:Signal:GatingMissingSignal', ...
            'gateToDuration requires a struct with a Signal field.');
    end
    if ~isfield(signalStruct, 'SampleRate') || isempty(signalStruct.SampleRate) || ...
            ~isnumeric(signalStruct.SampleRate) || ~isscalar(signalStruct.SampleRate) || ...
            ~isfinite(signalStruct.SampleRate) || signalStruct.SampleRate <= 0
        error('CSRD:Signal:GatingMissingSampleRate', ...
            'gateToDuration requires a positive scalar SampleRate.');
    end
    if isempty(durationSec) || ~isnumeric(durationSec) || ~isscalar(durationSec) || ...
            ~isfinite(durationSec) || durationSec < 0
        error('CSRD:Signal:GatingInvalidDuration', ...
            'gateToDuration requires a finite non-negative durationSec.');
    end

    sampleRate = double(signalStruct.SampleRate);
    targetSamples = max(0, round(double(durationSec) * sampleRate));

    x = signalStruct.Signal;
    if isempty(x)
        inputSamples = 0;
        numCols = 1;
        x = complex(zeros(0, 1));
    else
        inputSamples = size(x, 1);
        if isvector(x)
            x = x(:);
        end
        numCols = size(x, 2);
    end

    action = 'none';
    if inputSamples > targetSamples
        y = x(1:targetSamples, :);
        action = 'trim';
    elseif inputSamples < targetSamples
        pad = complex(zeros(targetSamples - inputSamples, numCols));
        y = [x; pad];
        action = 'pad';
    else
        y = x;
    end

    signalStruct.Signal = y;
    signalStruct.SignalSampleCount = targetSamples;
    signalStruct.SignalDurationSec = targetSamples / sampleRate;

    info = struct( ...
        'Stage', char(string(stageName)), ...
        'TargetDurationSec', double(durationSec), ...
        'TargetSamples', targetSamples, ...
        'InputSamples', inputSamples, ...
        'OutputSamples', size(y, 1), ...
        'SampleRate', sampleRate, ...
        'Action', action);

    if ~isfield(signalStruct, 'SignalGating') || ...
            ~isstruct(signalStruct.SignalGating)
        signalStruct.SignalGating = struct();
    end
    fieldName = matlab.lang.makeValidName(char(string(stageName)));
    signalStruct.SignalGating.(fieldName) = info;
end
