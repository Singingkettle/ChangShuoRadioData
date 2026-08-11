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
addParameter(p, 'EnvelopeOptions', struct(), @(x) isempty(x) || isstruct(x));
% NOTE: there is deliberately no threshold or search-window parameter. A power
% integral has no threshold to tune and no window to bound, so there is nothing
% here a caller could set that would change WHICH QUANTITY is reported. The plan
% is still the right cross-check on the result (measuredPlausibilityViolations),
% just not an input to it -- which keeps the measured plane independent of the
% planner, as a blind-detection reference must be.
parse(p, varargin{:});

signalCol = localValidateAndCollapse(signal, sampleRate);
sampleRate = double(sampleRate);

summary = struct();
% OccupiedBandwidthHz is the ITU-R SM.328 / RR No. 1.153 quantity: the band that
% excludes 0.5 % of the mean power at each edge, i.e. the 99 %-power bandwidth.
% That is what the field NAME promises, and MATLAB's obw() implements exactly it
% (verified against the analytic RRC result to 0.64 %).
%
% This replaces the former peak-relative (-3 dBc) estimate, which was a DIFFERENT
% quantity: ITU-R SM.443 requires x ~ 26 dB for an x-dB-down width to approximate
% OBW, and at x = 3 dB the result is the main-lobe footprint. For RRC that width
% is ~1.0*Rs and is INDEPENDENT OF THE ROLL-OFF -- measured here at 0.897 / 0.901
% / 0.803 Rs for beta = 0.1 / 0.25 / 0.5 while the true OBW rises 1.027 -> 1.096
% -> 1.266 Rs. So the old label was effectively the baud rate and was blind to a
% parameter it was supposed to reflect.
%
% The peak-relative form existed for ONE reason: obw() is unusable on a noisy
% waveform (7.13*Rs at 10 dB SNR). Now that the measurement runs before noise
% injection that reason is gone, and with it the need for the collapse guard and
% the blueprint prior window -- both were noise-robustness scaffolding, not
% definitional choices. ECC/REC/(06)01 makes the same point from the metrology
% side: measuring 99 % OBW requires the peak at least 30 dB above the noise
% floor, so on the noisy buffer the quantity is not merely imprecise, it is
% undefined at the bottom of our SNR range.
[summary.OccupiedBandwidthHz, obwInfo] = ...
    csrd.pipeline.measurement.occupiedBandwidthCore( ...
        signalCol, sampleRate, double(p.Results.Percentage));
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
% Quantity provenance. A bare number is not a sufficient specification of a
% measured quantity (JCGM 200:2012 VIM 2.3): the definition and the instrument
% belong with the value, so a consumer never has to guess which bandwidth
% convention a label follows.
summary.BandwidthDefinition = obwInfo.BandwidthDefinition;
summary.BandwidthEstimator = obwInfo.BandwidthEstimator;
% Measurement conditions, published so the label carries its own uncertainty. The
% same 15 MHz reading means one thing on a 32768-sample buffer and something else
% on a 64-sample burst: a hard-gated burst of duration T genuinely occupies ~10/T
% at the 99 % power level, so a wide reading on a short burst is a true statement
% about a signal that should not have been built that way -- not a measurement
% error. Without these fields a consumer cannot tell those two cases apart, and a
% spectrum-sensing model trained on the mixture learns the artefact as signal.
%
% BandwidthResolutionCells is the actionable one: it is how many analysis cells the
% reported width spans. ITU-R SM.443 puts a usable measurement RBW at ~1-3 % of the
% occupied bandwidth, i.e. >= ~33 cells; below that the number is a resolution
% floor rather than a bandwidth.
summary.BandwidthResolutionHz = obwInfo.ResolutionBandwidthHz;
summary.ActiveSampleCount = obwInfo.ActiveSampleCount;
if isfinite(obwInfo.ResolutionBandwidthHz) && obwInfo.ResolutionBandwidthHz > 0
    summary.BandwidthResolutionCells = ...
        summary.OccupiedBandwidthHz / obwInfo.ResolutionBandwidthHz;
else
    summary.BandwidthResolutionCells = NaN;
end
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
% Float the integration threshold with the signal peak before forming the
% energy-weighted mean.
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
% Collapse guard for the CENTROID only. This is a different quantity from the
% occupied bandwidth above and keeps its own peak-relative logic: a centroid is an
% energy-weighted mean, so unlike a power-integral width it is genuinely pulled
% toward a dominant spike and needs the fallback. Reviewed and left unchanged when
% the bandwidth switched to the ITU power integral -- changing two quantities at
% once would make either one unattributable. When a localized spectral
% spike sits a few dB above an otherwise-flat occupied band, the peak-relative
% clip keeps only the spike and biases the centroid toward it. If the
% peak-relative retained band is far narrower than a noise-floor-relative band
% (25th-percentile floor + 6 dB, which keeps the whole occupied band),
% integrate over the floor-relative band instead so the center tracks the true
% occupied band rather than the spike.
peakThreshold = peakVal * 10 ^ (-3 / 10);
% 10th-percentile floor (not 25th): an emitter may occupy up to 80% of the
% band, so a 25th-percentile floor would land inside a wideband occupied band
% and defeat the guard.
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
