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
parse(p, varargin{:});

signalCol = localValidateAndCollapse(signal, sampleRate);
sampleRate = double(sampleRate);

summary = struct();
summary.OccupiedBandwidthHz = localPeakRelativeObw( ...
    signalCol, sampleRate, double(p.Results.Percentage), ...
    double(p.Results.PeakRelativeDb));
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

function bwHz = localPeakRelativeObw(signalCol, sampleRate, pct, peakRelDb)
    % localPeakRelativeObw - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
N = length(signalCol);
if N < 8
    spec = abs(fftshift(fft(double(signalCol)))).^2;
    fAxis = ((0:N-1)' - floor(N/2)) * (sampleRate / N);
else
    winLen = max(64, 2 ^ floor(log2(N / 8)));
    if winLen >= N
        winLen = max(8, floor(N / 2));
    end
    overlap = floor(winLen / 2);
    nfft = max(256, 2 ^ nextpow2(winLen));
    [pxx, fAxis] = pwelch(double(signalCol), hamming(winLen), ...
        overlap, nfft, sampleRate, 'centered');
    spec = pxx(:);
    fAxis = fAxis(:);
end

% pwelch (Welch's method) discards the trailing partial segment of the
% signal. A short burst that sits entirely in that discarded tail yields an
% all-zero windowed estimate even though the signal carries energy, which
% would mis-measure the occupied bandwidth as zero. Fall back to a
% whole-signal periodogram so every sample (including a late frame-tail
% burst) is counted.
if (isempty(spec) || sum(spec) <= 0) && sum(abs(double(signalCol)) .^ 2) > 0
    spec = abs(fftshift(fft(double(signalCol)))) .^ 2;
    fAxis = ((0:N - 1)' - floor(N / 2)) * (sampleRate / N);
end

if isempty(spec) || sum(spec) <= 0
    bwHz = 0;
    return;
end

% Recentre a band that wraps the +/-Fs/2 Nyquist edge so the linear
% narrowest-contiguous-span search does not bridge the empty middle and
% inflate the OBW toward Fs. The span is invariant under the circular shift
% (mirrors obwActual so the two estimators stay equivalent).
spec = csrd.pipeline.measurement.circularRecenterSpectrum(spec, sampleRate);

peakVal = max(spec);
if peakVal <= 0
    bwHz = 0;
    return;
end

% Primary estimate: narrowest band holding `pct` of the energy that survives a
% peak-relative -3 dB clip. Tracks the signal and rejects the noise floor for
% the common flat-spectrum case.
bwHz = localSpanForThreshold(spec, fAxis, sampleRate, ...
    peakVal * 10 ^ (peakRelDb / 10), pct);

% Collapse guard. When a signal has a flat occupied band a few dB below a
% single localized spectral spike -- short bursts (low time-bandwidth product,
% high spectral variance) or a frequency-selective channel peak -- the
% peak-relative threshold sits ABOVE the flat band and clips it away,
% collapsing the measured width to the spike's neighbourhood (e.g. a realized
% ~17 MHz QAM measured at ~1.5 MHz). Detect that against a noise-floor-relative
% estimate (threshold a fixed +6 dB above a robust low-percentile floor, which
% keeps the whole occupied band) and fall back to it only when the
% peak-relative result is implausibly narrow, so the common case is unchanged.
% The floor percentile must stay BELOW the minimum noise fraction: an emitter
% may occupy up to MaxBandwidthFractionOfSampleRate (=0.8) of the band, leaving
% >=20% noise bins, so a 25th-percentile floor would land INSIDE a wideband
% occupied band and defeat the guard (the floor estimate then collapses to the
% spike just like the peak-relative one). The 10th percentile stays in the
% noise floor for occupancies up to 90%.
floorThreshold = prctile(spec, 10) * 10 ^ (6 / 10);
bwFloor = localSpanForThreshold(spec, fAxis, sampleRate, floorThreshold, pct);
if bwFloor > 0 && bwHz < 0.3 * bwFloor
    bwHz = bwFloor;
end
end

function bwHz = localSpanForThreshold(spec, fAxis, sampleRate, threshold, pct)
    % localSpanForThreshold - narrowest contiguous band holding pct% of the
    % energy left after zeroing bins below `threshold`.
denoised = spec;
denoised(denoised < threshold) = 0;

totalEnergy = sum(denoised);
if totalEnergy <= 0
    bwHz = 0;
    return;
end

targetMass = totalEnergy * (pct / 100);
nBins = numel(denoised);
cumEnergy = cumsum(denoised);
bestSpan = nBins;
lBest = 1;
rBest = nBins;
rIdx = 1;
for lIdx = 1:nBins
    if rIdx < lIdx
        rIdx = lIdx;
    end
    while rIdx < nBins && localRangeMass(cumEnergy, lIdx, rIdx) < targetMass
        rIdx = rIdx + 1;
    end
    if localRangeMass(cumEnergy, lIdx, rIdx) >= targetMass
        span = rIdx - lIdx + 1;
        if span < bestSpan
            bestSpan = span;
            lBest = lIdx;
            rBest = rIdx;
        end
    end
end

if nBins == 1
    bwHz = sampleRate;
else
    binWidth = median(diff(fAxis));
    bwHz = max(0, (fAxis(rBest) - fAxis(lBest)) + abs(binWidth));
end
end

function mass = localRangeMass(cumEnergy, lIdx, rIdx)
    % localRangeMass - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if lIdx <= 1
    mass = cumEnergy(rIdx);
else
    mass = cumEnergy(rIdx) - cumEnergy(lIdx - 1);
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
% Collapse guard (mirrors localPeakRelativeObw). When a localized spectral
% spike sits a few dB above an otherwise-flat occupied band, the peak-relative
% clip keeps only the spike and biases the centroid toward it. If the
% peak-relative retained band is far narrower than a noise-floor-relative band
% (25th-percentile floor + 6 dB, which keeps the whole occupied band),
% integrate over the floor-relative band instead so the center tracks the true
% occupied band rather than the spike.
peakThreshold = peakVal * 10 ^ (-3 / 10);
% 10th-percentile floor (not 25th): an emitter may occupy up to 80% of the
% band, so a 25th-percentile floor would land inside a wideband occupied band
% and defeat the guard (mirrors localPeakRelativeObw / obwActual).
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
