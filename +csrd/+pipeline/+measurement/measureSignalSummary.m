function summary = measureSignalSummary(signal, sampleRate, observableBwHz, varargin)
%MEASURESIGNALSUMMARY Compute receiver-view measurements in one pass.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.

if nargin < 3 || isempty(observableBwHz)
    observableBwHz = NaN;
end

p = inputParser();
p.FunctionName = 'measureSignalSummary';
p.CaseSensitive = false;
addParameter(p, 'Percentage', 99, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0 && x <= 100);
addParameter(p, 'PeakRelativeDb', -3, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x < 0);
addParameter(p, 'EnvelopeOptions', struct(), @(x) isempty(x) || isstruct(x));
% Blueprint prior: [lowerHz upperHz] search window in receiver-baseband
% frequency. Empty means the historical full-band search. The value still comes
% from the data; the window only bounds where the estimator looks.
addParameter(p, 'PriorWindowHz', [], ...
    @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
parse(p, varargin{:});

signalCol = localValidateAndCollapse(signal, sampleRate);
sampleRate = double(sampleRate);

summary = struct();
[summary.OccupiedBandwidthHz, obwInfo] = ...
    csrd.pipeline.measurement.peakRelativeObwCore( ...
        signalCol, sampleRate, double(p.Results.Percentage), ...
        double(p.Results.PeakRelativeDb), p.Results.PriorWindowHz);
summary.CenterFrequencyHz = localSpectrumCentroid(signalCol, sampleRate);
envInfo = localDetectEnvelope(signalCol, sampleRate, p.Results.EnvelopeOptions);
summary.TimeOccupancy = envInfo.TimeOccupancy;
summary.Envelope = envInfo;
if isfinite(observableBwHz)
    summary.FrequencyOccupancy = csrd.pipeline.measurement.frequencyOccupancy( ...
        summary.OccupiedBandwidthHz, double(observableBwHz));
else
    summary.FrequencyOccupancy = NaN;
end
summary.MeasurementStatus = 'Measured';
summary.MeasurementSemantics = '';
% Plan-relative diagnostics. The prior never bounds the reported bandwidth (the
% window grows until the measurement stops growing), so these describe how far
% the REALIZATION departed from the blueprint -- a plan-quality signal, not a
% measurement fault. PriorWindowGrowths > 0 means the realized emitter ran past
% the band the plan placed it in, or the plan was misplaced; Converged == false
% means even the growth cap did not settle it and the value is the full-band
% measurement.
summary.PriorWindowApplied = obwInfo.PriorWindowApplied;
summary.PriorWindowFillRatio = obwInfo.PriorWindowFillRatio;
summary.PriorWindowGrowths = obwInfo.PriorWindowGrowths;
summary.PriorWindowConverged = obwInfo.PriorWindowConverged;
end

function signalCol = localValidateAndCollapse(signal, sampleRate)
    % localValidateAndCollapse - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isempty(signal)
    error('CSRD:Measurement:EmptySignal', ...
        'measureSignalSummary: input signal is empty.');
end
if ~isnumeric(sampleRate) || ~isscalar(sampleRate) || ...
        ~isfinite(sampleRate) || sampleRate <= 0
    error('CSRD:Measurement:InvalidSampleRate', ...
        'measureSignalSummary: sampleRate must be positive finite scalar.');
end
if any(~isfinite(signal(:)))
    error('CSRD:Measurement:InvalidSignal', ...
        'measureSignalSummary: signal contains NaN or Inf.');
end
if size(signal, 2) > 1
    signalCol = sum(signal, 2);
else
    signalCol = signal(:);
end
end

function fcHz = localSpectrumCentroid(signalCol, sampleRate)
    % localSpectrumCentroid - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
N = length(signalCol);
spec = fftshift(fft(double(signalCol)));
psd = abs(spec) .^ 2;
fAxis = ((0:N - 1)' - floor(N / 2)) * (sampleRate / N);
% Recentre a band that wraps the +/-Fs/2 Nyquist edge so the linear
% energy-weighted mean does not collapse the centre toward baseband (mirrors
% spectrumCentroid). fcShiftHz is added back at the end.
[psd, fcShiftHz] = csrd.pipeline.measurement.circularRecenterSpectrum(psd, sampleRate);
% Smooth the raw periodogram to suppress per-bin noise variance before the
% threshold/collapse logic, so the decision sees the signal's spectral envelope
% rather than noise spikes (matches the pwelch-smoothed OBW estimator). A box
% average preserves the energy-weighted mean, so the centroid is unchanged.
if N >= 8
    % Odd window (symmetric) >= 3 for all N, scaling with N. A floor of 3
    % (rather than only smoothing for N >= 256) keeps the centroid continuous
    % across the short-signal boundary.
    psd = movmean(psd, max(3, 2 * round(N / 512) + 1));
end
% Float the integration threshold with the signal peak (matching the
% peak-relative OBW estimator) before forming the energy-weighted mean.
% Broadband AWGN is symmetric about 0 Hz, so integrating the raw PSD pulls the
% measured center toward baseband by signalPower/(signalPower+inBandNoise) --
% biasing the measured CenterFrequencyHz GT by MHz at realistic SNRs, worst for
% edge-of-band emitters. Clipping bins below peak*10^(-3/10) tracks the signal
% peak instead of the noise floor; a clean single tone keeps its main lobe.
peakVal = max(psd);
if peakVal <= 0
    fcHz = 0;
    return;
end
% Collapse guard (mirrors peakRelativeObwCore). When a localized spectral
% spike sits a few dB above an otherwise-flat occupied band, the peak-relative
% clip keeps only the spike and biases the centroid toward it. If the
% peak-relative retained band is far narrower than a noise-floor-relative band
% (25th-percentile floor + 6 dB, which keeps the whole occupied band),
% integrate over the floor-relative band instead so the center tracks the true
% occupied band rather than the spike.
peakThreshold = peakVal * 10 ^ (-3 / 10);
% 10th-percentile floor (not 25th): an emitter may occupy up to 80% of the
% band, so a 25th-percentile floor would land inside a wideband occupied band
% and defeat the guard (mirrors peakRelativeObwCore).
floorThreshold = prctile(psd, 10) * 10 ^ (6 / 10);
peakClipped = psd;
peakClipped(peakClipped < peakThreshold) = 0;
floorClipped = psd;
floorClipped(floorClipped < floorThreshold) = 0;
floorSpan = localEnergySpan(floorClipped, fAxis);
if floorSpan > 0 && localEnergySpan(peakClipped, fAxis) < 0.3 * floorSpan
    psd = floorClipped;
else
    psd = peakClipped;
end
totalPower = sum(psd);
if totalPower <= 0
    fcHz = 0;
    return;
end
fcHz = sum(fAxis .* psd) / totalPower + fcShiftHz;
% The circular add-back (fcShiftHz) can push an edge-straddling centroid just
% past +/-Fs/2; wrap it back into the physical captured band [-Fs/2, Fs/2) so
% the measured CenterFrequencyHz never reports a frequency outside the receiver
% passband (a downstream consumer placing it on the receiver frequency canvas
% would otherwise land off-canvas).
fcHz = mod(fcHz + sampleRate / 2, sampleRate) - sampleRate / 2;
end

function spanHz = localEnergySpan(psd, fAxis)
    % localEnergySpan - width (Hz) of the NARROWEST contiguous band holding 99%
    % of the energy. Robust to scattered low-energy noise tails (which a simple
    % percentile span would let push the edges to the band limits): a genuine
    % broadband signal yields a wide band, a narrow tone plus scattered noise
    % yields a narrow band. fAxis is ascending.
    total = sum(psd);
    if total <= 0
        spanHz = 0;
        return;
    end
    target = 0.99 * total;
    n = numel(psd);
    cumE = cumsum(psd);
    best = inf;
    rIdx = 1;
    for lIdx = 1:n
        if rIdx < lIdx
            rIdx = lIdx;
        end
        while rIdx < n && (cumE(rIdx) - cumE(lIdx) + psd(lIdx)) < target
            rIdx = rIdx + 1;
        end
        if (cumE(rIdx) - cumE(lIdx) + psd(lIdx)) >= target
            best = min(best, fAxis(rIdx) - fAxis(lIdx));
        end
    end
    if ~isfinite(best)
        spanHz = fAxis(end) - fAxis(1);
    else
        spanHz = best;
    end
end

function info = localDetectEnvelope(signalCol, sampleRate, options)
    % localDetectEnvelope - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if nargin < 3 || isempty(options)
    options = struct();
end
useDefaultWindow = ~isfield(options, 'WindowSec') || isempty(options.WindowSec);
if ~isfield(options, 'ThresholdDb') || isempty(options.ThresholdDb)
    options.ThresholdDb = -20;
end

totalDurationSec = length(signalCol) / sampleRate;
if useDefaultWindow
    options.WindowSec = min(1e-4, totalDurationSec);
end
if options.WindowSec <= 0 || options.WindowSec > totalDurationSec
    error('CSRD:Measurement:InvalidWindow', ...
        ['measureSignalSummary envelope: WindowSec=%g must be in ', ...
         '(0, total=%.6g] s.'], options.WindowSec, totalDurationSec);
end

windowSamples = max(1, round(options.WindowSec * sampleRate));
numWindows = floor(length(signalCol) / windowSamples);
if numWindows == 0
    info = localEmptyEnvelope(options);
    return;
end

trimmed = signalCol(1:(numWindows * windowSamples));
powerMatrix = reshape(abs(trimmed) .^ 2, windowSamples, numWindows);
powerPerWindow = mean(powerMatrix, 1).';

peakPower = max(powerPerWindow);
if peakPower <= 0
    % Every analyzed full window is silent. floor() drops the trailing
    % partial window, so a burst sitting entirely in that tail would
    % otherwise report TimeOccupancy=0 for a signal that clearly carries
    % energy (mirrors the OBW whole-signal fallback). Report it as one
    % active tail window instead of zeroing occupancy.
    if sum(abs(double(signalCol)) .^ 2) > 0
        info = struct( ...
            'TimeOccupancy', 1 / (numWindows + 1), ...
            'NumBursts', 1, ...
            'BurstStartSec', (numWindows * windowSamples) / sampleRate, ...
            'BurstStopSec', length(signalCol) / sampleRate, ...
            'WindowSec', options.WindowSec, ...
            'ThresholdDb', options.ThresholdDb);
        return;
    end
    info = localEmptyEnvelope(options);
    return;
end
thresholdLinear = peakPower * 10^(options.ThresholdDb / 10);
onMask = powerPerWindow >= thresholdLinear;

edges = diff([false; onMask; false]);
burstStartIdx = find(edges == 1);
burstStopIdx  = find(edges == -1) - 1;
info = struct( ...
    'TimeOccupancy', sum(onMask) / numWindows, ...
    'NumBursts', length(burstStartIdx), ...
    'BurstStartSec', ((burstStartIdx - 1) * windowSamples / sampleRate).', ...
    'BurstStopSec', (burstStopIdx * windowSamples / sampleRate).', ...
    'WindowSec', options.WindowSec, ...
    'ThresholdDb', options.ThresholdDb);
end

function info = localEmptyEnvelope(options)
    % localEmptyEnvelope - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
info = struct( ...
    'TimeOccupancy', 0, ...
    'NumBursts', 0, ...
    'BurstStartSec', zeros(1, 0), ...
    'BurstStopSec', zeros(1, 0), ...
    'WindowSec', options.WindowSec, ...
    'ThresholdDb', options.ThresholdDb);
end
