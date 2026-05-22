function signalStruct = gateToDuration(signalStruct, durationSec, stageName, varargin)
%GATETODURATION Align a signal struct to an explicit duration.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
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
    minPositiveSamples = false;
    if ~isempty(varargin)
        for argIdx = 1:2:numel(varargin)
            name = char(string(varargin{argIdx}));
            if argIdx + 1 > numel(varargin)
                error('CSRD:Signal:GatingInvalidOption', ...
                    'gateToDuration option "%s" is missing a value.', name);
            end
            switch lower(name)
                case 'minpositivesamples'
                    minPositiveSamples = logical(varargin{argIdx + 1});
                otherwise
                    error('CSRD:Signal:GatingInvalidOption', ...
                        'Unsupported gateToDuration option "%s".', name);
            end
        end
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
    requestedSamples = max(0, round(double(durationSec) * sampleRate));

    x = signalStruct.Signal;
    if isempty(x)
        inputSamples = 0;
        numCols = 1;
        x = complex(zeros(0, 1));
    else
        inputSamples = size(x, 1);
        numCols = size(x, 2);
    end
    targetSamples = requestedSamples;
    minimumPositiveSamplesApplied = false;
    if targetSamples == 0 && durationSec > 0 && minPositiveSamples && ...
            inputSamples > 0
        targetSamples = 1;
        minimumPositiveSamplesApplied = true;
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
        'RequestedSamples', requestedSamples, ...
        'TargetSamples', targetSamples, ...
        'InputSamples', inputSamples, ...
        'OutputSamples', size(y, 1), ...
        'SampleRate', sampleRate, ...
        'Action', action, ...
        'MinimumPositiveSamplesApplied', minimumPositiveSamplesApplied);

    if ~isfield(signalStruct, 'SignalGating') || ...
            ~isstruct(signalStruct.SignalGating)
        signalStruct.SignalGating = struct();
    end
    fieldName = matlab.lang.makeValidName(char(string(stageName)));
    signalStruct.SignalGating.(fieldName) = info;
end
