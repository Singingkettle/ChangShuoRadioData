function [bwHz, info] = peakRelativeObwCore(signalCol, sampleRate, pct, peakRelDb, priorWindowHz)
%PEAKRELATIVEOBWCORE Shared peak-relative occupied-bandwidth kernel.
% Inputs: see signature arguments and local validation.
% Outputs: see signature return values and contract fields.
%
% Single implementation of the peak-relative occupied-bandwidth estimator
% used by BOTH measurement entry points:
%
%   - csrd.pipeline.measurement.obwActual          (Truth.Execution plane)
%   - csrd.pipeline.measurement.measureSignalSummary (Truth.Measured planes)
%
% Both callers previously carried byte-equivalent copies of this algorithm,
% each commenting that it "mirrors" the other. Keeping one kernel is what
% makes the equivalence a structural property instead of a maintenance
% promise (see tests/unit/MeasurementSpectrumCacheEquivalenceTest.m).
%
% ALGORITHM (unchanged from the two former copies)
%   1. Smoothed two-sided PSD via pwelch (Hamming window, ~8 segments with
%      50 % overlap), or a whole-signal periodogram for very short inputs
%      and for the Welch-discarded-tail case.
%   2. Recentre a band that wraps the +/-Fs/2 Nyquist edge so the linear
%      narrowest-contiguous-span search does not bridge the empty middle.
%   3. Primary estimate: clip every bin below `peak * 10^(peakRelDb/10)`,
%      then take the narrowest contiguous band holding `pct` % of the
%      surviving energy.
%   4. Collapse guard: when the peak-relative result is implausibly narrow
%      relative to a noise-floor-relative estimate (10th-percentile floor
%      + 6 dB), fall back to the floor-relative span.
%
% Inputs:
%   signalCol  - complex column vector (antenna collapsing is the caller's
%                responsibility: obwActual and measureSignalSummary both
%                sum across columns before calling in).
%   sampleRate - positive finite scalar (Hz).
%   pct        - energy percentage in (0, 100].
%   peakRelDb  - peak-relative clip in dB, strictly negative (default -3).
%   priorWindowHz - optional [lowerHz upperHz] search window, in the same
%                frequency frame as the spectrum (receiver baseband, 0 Hz at the
%                receiver centre). When supplied, every bin outside the window is
%                excluded BEFORE the peak and both thresholds are computed, so
%                the estimate can neither be driven by out-of-window energy nor
%                bridge across it. Omit or leave empty for the historical
%                full-band search.
%
%                This is the plan-as-prior mechanism: the blueprint says where the
%                emitter was placed and roughly how wide it is, so the estimator
%                is pointed at that band instead of searching the whole capture --
%                the same thing a spectrum-analyser operator does by setting
%                centre and span from the drawings before reading the occupied
%                bandwidth off the instrument. The VALUE still comes entirely
%                from the data; the prior only decides where to look.
%
% Outputs:
%   bwHz - occupied bandwidth in Hz (>= 0). Zero means every bin fell below
%          the threshold, i.e. the signal is indistinguishable from the
%          receiver-band noise floor; callers surface that as an explicit
%          measurement failure rather than propagating Nyquist.
%   info - diagnostic struct describing HOW the estimate was reached. It is
%          reporting-only in this revision; no caller changes behaviour on
%          it yet. Fields:
%            .BwPeakHz           - step-3 estimate before the collapse guard
%            .BwFloorHz          - floor-relative estimate used by the guard
%            .PeakToNoiseFloorDb - 10*log10(peak / 10th-percentile floor);
%                                  low values mean the noise floor has risen
%                                  into the clip and the estimate is at risk
%            .OccupiedFraction   - bwHz / sampleRate
%            .CollapseGuardFired - true when step 4 replaced the estimate
%            .SpectrumSource     - 'pwelch' | 'periodogram'
%            .PriorWindowApplied - true when a prior window was used
%            .PriorWindowHz      - the window actually applied ([] when none)
%            .PriorWindowFillRatio - bwHz / window width; a value near 1 means
%                                  the estimate filled the whole prior, which is
%                                  the plan-relative signal that the measurement
%                                  was clipped by its own window rather than by
%                                  the signal
%            .TouchesPriorEdge   - true when the retained band reaches a window
%                                  edge bin
%
% See also: csrd.pipeline.measurement.obwActual
%           csrd.pipeline.measurement.measureSignalSummary

if nargin < 5
    priorWindowHz = [];
end

info = struct( ...
    'BwPeakHz', 0, ...
    'BwFloorHz', 0, ...
    'PeakToNoiseFloorDb', NaN, ...
    'OccupiedFraction', 0, ...
    'CollapseGuardFired', false, ...
    'SpectrumSource', 'pwelch', ...
    'PriorWindowApplied', false, ...
    'PriorWindowHz', [], ...
    'PriorWindowFillRatio', NaN, ...
    'TouchesPriorEdge', false);

N = length(signalCol);
if N < 8
    % Too short for pwelch's default 8-segment split; fall back to a single
    % segment FFT magnitude so short-signal semantics stay unchanged.
    spec = abs(fftshift(fft(double(signalCol)))) .^ 2;
    fAxis = ((0:N - 1)' - floor(N / 2)) * (sampleRate / N);
    info.SpectrumSource = 'periodogram';
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

% pwelch (Welch's method) discards the trailing partial segment. A short
% burst that sits entirely in that discarded tail yields an all-zero windowed
% estimate even though the signal carries energy, which would mis-measure the
% occupied bandwidth as zero. Fall back to a whole-signal periodogram so
% every sample (including a late frame-tail burst) is counted.
if (isempty(spec) || sum(spec) <= 0) && sum(abs(double(signalCol)) .^ 2) > 0
    spec = abs(fftshift(fft(double(signalCol)))) .^ 2;
    fAxis = ((0:N - 1)' - floor(N / 2)) * (sampleRate / N);
    info.SpectrumSource = 'periodogram';
end

if isempty(spec) || sum(spec) <= 0
    bwHz = 0;
    return;
end

% Recentre a band that wraps the +/-Fs/2 Nyquist edge so the linear
% narrowest-contiguous-span search does not bridge the empty middle and
% inflate the OBW toward Fs. The span is invariant under the circular shift,
% so nothing is added back (fAxis is left unchanged).
[spec, fcShiftHz] = csrd.pipeline.measurement.circularRecenterSpectrum(spec, sampleRate);

% Restrict the search to the prior window BEFORE the peak is taken, so neither
% the clip level nor the span search can be influenced by energy outside the band
% the blueprint says this emitter occupies.
%
% The window arrives in TRUE receiver-baseband frequency, but the recentre above
% circularly shifted `spec` while leaving `fAxis` untouched. A SPAN is invariant
% under that shift (which is why nothing is added back for bwHz), but an ABSOLUTE
% window is not: true frequency = shifted-axis frequency + fcShiftHz, so the
% window must be moved onto the shifted axis before selecting bins. Getting this
% wrong would silently mask the wrong part of the spectrum for exactly the
% edge-straddling emitters the recentre exists to handle.
inWindow = true(size(spec));
if ~isempty(priorWindowHz) && numel(priorWindowHz) == 2 && ...
        all(isfinite(priorWindowHz)) && priorWindowHz(2) > priorWindowHz(1)
    shiftedWindow = [priorWindowHz(1), priorWindowHz(2)] - fcShiftHz;
    candidate = fAxis >= shiftedWindow(1) & fAxis <= shiftedWindow(2);
    if any(candidate) && any(spec(candidate) > 0)
        inWindow = candidate;
        spec(~inWindow) = 0;
        info.PriorWindowApplied = true;
        info.PriorWindowHz = [priorWindowHz(1), priorWindowHz(2)];
    end
    % A window that excludes every bin, or contains no energy at all, is not
    % applied: that would turn a plan/measurement mismatch into a silent zero
    % instead of a visible one. The full-band answer is reported and the
    % diagnostics record that no window took effect.
end

peakVal = max(spec);
if peakVal <= 0
    bwHz = 0;
    return;
end

% Primary estimate: peak-relative clip then narrowest pct%-energy band.
bwHz = csrd.pipeline.measurement.narrowestEnergySpan(spec, fAxis, ...
    sampleRate, peakVal * 10 ^ (peakRelDb / 10), pct);
info.BwPeakHz = bwHz;

% Collapse guard. When a signal has a flat occupied band a few dB below a
% single localized spectral spike -- short bursts (low time-bandwidth
% product, high spectral variance) or a frequency-selective channel peak --
% the peak-relative threshold sits ABOVE the flat band and clips it away,
% collapsing the measured width to the spike's neighbourhood (e.g. a
% realized ~17 MHz QAM measured at ~1.5 MHz). Detect that against a
% noise-floor-relative estimate (a fixed +6 dB above a robust low-percentile
% floor, which keeps the whole occupied band) and fall back to it only when
% the peak-relative result is implausibly narrow, so the common case is
% unchanged. The floor percentile must stay BELOW the minimum noise
% fraction: an emitter may occupy up to MaxBandwidthFractionOfSampleRate
% (=0.8) of the band, leaving >=20% noise bins, so a 25th-percentile floor
% would land INSIDE a wideband occupied band and defeat the guard (the floor
% estimate then collapses to the spike just like the peak-relative one). The
% 10th percentile stays in the noise floor for occupancies up to 90%.
% The floor percentile must be taken over the WINDOWED bins only; including the
% zeroed out-of-window bins would drag the 10th percentile to zero and make the
% collapse guard's floor-relative span meaningless.
floorVal = prctile(spec(inWindow), 10);
floorThreshold = floorVal * 10 ^ (6 / 10);
bwFloor = csrd.pipeline.measurement.narrowestEnergySpan(spec, fAxis, ...
    sampleRate, floorThreshold, pct);
info.BwFloorHz = bwFloor;
if floorVal > 0
    info.PeakToNoiseFloorDb = 10 * log10(peakVal / floorVal);
end
if bwFloor > 0 && bwHz < 0.3 * bwFloor
    bwHz = bwFloor;
    info.CollapseGuardFired = true;
end

info.OccupiedFraction = bwHz / sampleRate;
if info.PriorWindowApplied
    windowWidthHz = info.PriorWindowHz(2) - info.PriorWindowHz(1);
    if windowWidthHz > 0
        info.PriorWindowFillRatio = bwHz / windowWidthHz;
        % Bin granularity: treat "within one bin of the window width" as having
        % reached the edge, since the span search reports edge-to-edge plus one
        % bin width.
        binWidthHz = abs(median(diff(fAxis)));
        info.TouchesPriorEdge = bwHz >= (windowWidthHz - binWidthHz);
    end
end
end
