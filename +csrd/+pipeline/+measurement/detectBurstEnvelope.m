function info = detectBurstEnvelope(signal, sampleRate, options)
%DETECTBURSTENVELOPE Envelope-based burst detection over time.
% 中文说明：提供 CSRD 生产链路中的 detectBurstEnvelope 实现。
%
% Phase 4 §3.1 measurement helper. Slides a non-overlapping power window
% across the signal magnitude, marks windows whose power exceeds a
% peak-relative threshold as "on", and returns aggregate occupancy +
% per-burst start/stop times (seconds).
%
% Inputs:
%   signal      : complex column vector (or [N x M]); multi-antenna is
%                 collapsed by sum across columns prior to envelope.
%   sampleRate  : positive scalar (Hz)
%   options     : optional struct with fields (all optional)
%       .WindowSec    (double) window length in seconds (default 1e-4)
%       .ThresholdDb  (double) peak-relative threshold in dB (default -20)
%
% Outputs:
%   info        : struct with fields
%       .TimeOccupancy   double in [0,1] (fraction of windows above threshold)
%       .NumBursts       non-negative integer (count of contiguous on-runs)
%       .BurstStartSec   row vector of burst start times (seconds)
%       .BurstStopSec    row vector of burst stop times (seconds)
%       .WindowSec       echoed effective window length
%       .ThresholdDb     echoed effective threshold
%
% Throws:
%   CSRD:Measurement:EmptySignal       - empty input
%   CSRD:Measurement:InvalidSampleRate - sampleRate <= 0 or non-finite
%   CSRD:Measurement:InvalidSignal     - signal contains NaN/Inf
%   CSRD:Measurement:InvalidWindow     - WindowSec <= 0 or > total duration
%
% Notes:
%   - Returns TimeOccupancy=0 / NumBursts=0 for an all-zero signal.
%   - Threshold is computed against the per-window peak power, so a fully
%     constant-amplitude signal yields TimeOccupancy=1.

    if nargin < 3 || isempty(options)
        options = struct();
    end
    if ~isfield(options, 'WindowSec')   || isempty(options.WindowSec)
        options.WindowSec = 1e-4;
    end
    if ~isfield(options, 'ThresholdDb') || isempty(options.ThresholdDb)
        options.ThresholdDb = -20;
    end

    if isempty(signal)
        error('CSRD:Measurement:EmptySignal', ...
            'detectBurstEnvelope: input signal is empty.');
    end

    if ~isnumeric(sampleRate) || ~isscalar(sampleRate) || ...
            ~isfinite(sampleRate) || sampleRate <= 0
        error('CSRD:Measurement:InvalidSampleRate', ...
            'detectBurstEnvelope: sampleRate must be positive finite scalar (got %s).', ...
            mat2str(sampleRate));
    end

    if any(~isfinite(signal(:)))
        error('CSRD:Measurement:InvalidSignal', ...
            'detectBurstEnvelope: signal contains NaN or Inf.');
    end

    if size(signal, 2) > 1
        signalCol = sum(signal, 2);
    else
        signalCol = signal(:);
    end

    totalDurationSec = length(signalCol) / double(sampleRate);
    if options.WindowSec <= 0 || options.WindowSec > totalDurationSec
        error('CSRD:Measurement:InvalidWindow', ...
            ['detectBurstEnvelope: WindowSec=%g must be in (0, total=%.6g] s.'], ...
            options.WindowSec, totalDurationSec);
    end

    windowSamples = max(1, round(options.WindowSec * double(sampleRate)));
    numWindows = floor(length(signalCol) / windowSamples);

    if numWindows == 0
        info = makeEmptyInfo(options);
        return;
    end

    powerPerWindow = zeros(numWindows, 1);
    for w = 1:numWindows
        idx = (w - 1) * windowSamples + (1:windowSamples);
        powerPerWindow(w) = mean(abs(signalCol(idx)) .^ 2);
    end

    peakPower = max(powerPerWindow);
    if peakPower <= 0
        info = makeEmptyInfo(options);
        return;
    end

    thresholdLinear = peakPower * 10^(options.ThresholdDb / 10);
    onMask = powerPerWindow >= thresholdLinear;

    timeOccupancy = sum(onMask) / numWindows;

    edges = diff([false; onMask; false]);
    burstStartIdx = find(edges == 1);
    burstStopIdx  = find(edges == -1) - 1;

    burstStartSec = ((burstStartIdx - 1) * windowSamples) / double(sampleRate);
    burstStopSec  = (burstStopIdx * windowSamples) / double(sampleRate);

    info = struct( ...
        'TimeOccupancy', timeOccupancy, ...
        'NumBursts',     length(burstStartIdx), ...
        'BurstStartSec', burstStartSec(:)', ...
        'BurstStopSec',  burstStopSec(:)', ...
        'WindowSec',     options.WindowSec, ...
        'ThresholdDb',   options.ThresholdDb);
end

% =====================================================================
function info = makeEmptyInfo(options)
    % makeEmptyInfo - Production declaration in CSRD.
    % 中文说明：makeEmptyInfo 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    info = struct( ...
        'TimeOccupancy', 0, ...
        'NumBursts',     0, ...
        'BurstStartSec', zeros(1, 0), ...
        'BurstStopSec',  zeros(1, 0), ...
        'WindowSec',     options.WindowSec, ...
        'ThresholdDb',   options.ThresholdDb);
end
