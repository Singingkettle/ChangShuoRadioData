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
%      + 6 dB) AND that wider band holds materially more energy (i.e. real
%      occupied spectrum was clipped away), fall back to the floor-relative
%      span. The energy test is what stops the guard firing on emitters that
%      are narrow simply because they are narrow.
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
%            .PriorWindowGrowths - how many times the window had to be doubled
%                                  before the measurement stopped growing.
%                                  Non-zero means the realization ran past the
%                                  blueprint (or the blueprint was misplaced),
%                                  which is a plan-quality signal, not a
%                                  measurement fault
%            .PriorWindowConverged - true when growth converged rather than
%                                  hitting the attempt cap
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
    'PriorWindowGrowths', 0, ...
    'PriorWindowConverged', false);

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

% Plan-as-prior, with the PLAN NEVER BOUNDING THE ANSWER.
%
% The ground truth must reflect what was actually realized, not what was planned:
% execution legitimately deviates from the blueprint, and a label clipped to a
% plan-derived window would be reporting the plan. So the window is used only to
% LOCATE the emitter -- it keeps the span search from bridging to energy that is
% not this emitter's -- and it is GROWN whenever the measured band reaches its
% edge, because touching the edge is the signature of the window, not the signal,
% having set the answer. Growth continues until the answer is interior or the
% window covers the whole capture, at which point the result is exactly the
% historical full-band measurement.
specFull = spec;
searchWindowHz = [];
if ~isempty(priorWindowHz) && numel(priorWindowHz) == 2 && ...
        all(isfinite(priorWindowHz)) && priorWindowHz(2) > priorWindowHz(1)
    % The recentre above circularly shifted `spec` while leaving fAxis untouched.
    % A SPAN is invariant under that shift (which is why nothing is added back for
    % bwHz) but an ABSOLUTE window is not, so map the window onto the shifted
    % axis. Getting this wrong would mask the wrong bins for exactly the
    % edge-straddling emitters the recentre exists to handle.
    searchWindowHz = [priorWindowHz(1), priorWindowHz(2)] - fcShiftHz;
end

% Grow the window until the ANSWER STOPS GROWING. That, not an edge test, is the
% operational definition of "the data set the extent": if doubling the window
% still widens the measurement, the window was the binding constraint, so it must
% not be the one reported. Convergence means the emitter's own spectrum ended
% before the window did.
%
% This also repairs a misplaced prior. A window that happens to sit on sidelobe
% leakage away from the emitter would otherwise return a fabricated narrow label;
% under growth the answer keeps increasing until the real lobe is inside, and the
% converged value is the honest full-band one.
MAX_WINDOW_GROWTHS = 10;
GROWTH_TOLERANCE = 0.02;   % <2% change counts as converged

bwHz = 0;
converged = false;
for growth = 0:MAX_WINDOW_GROWTHS
    [candidateBw, candidateInfo, windowWidthHz] = localMeasureInWindow( ...
        specFull, fAxis, sampleRate, pct, peakRelDb, searchWindowHz, fcShiftHz);
    if candidateBw <= 0 && growth == 0
        bwHz = 0;
        info = localMergeWindowInfo(info, candidateInfo, growth);
        return;
    end
    grew = candidateBw > bwHz * (1 + GROWTH_TOLERANCE);
    bwHz = max(bwHz, candidateBw);
    info = localMergeWindowInfo(info, candidateInfo, growth);
    if ~grew
        converged = true;
        break;
    end
    if isempty(searchWindowHz) || windowWidthHz >= sampleRate
        % Already the whole capture; there is nothing left to grow into and the
        % answer is the historical full-band measurement.
        converged = true;
        break;
    end
    centreHz = 0.5 * (searchWindowHz(1) + searchWindowHz(2));
    halfHz = min(windowWidthHz, sampleRate / 2);
    searchWindowHz = [centreHz - halfHz, centreHz + halfHz];
end
info.PriorWindowConverged = converged;

info.OccupiedFraction = bwHz / sampleRate;
end

function [bwHz, info, windowWidthHz] = localMeasureInWindow(specFull, fAxis, ...
        sampleRate, pct, peakRelDb, windowHz, fcShiftHz)
    % A peak-relative band holding less than this fraction of the floor-relative
    % band's energy means real occupied spectrum was clipped away, which is the
    % only situation the collapse guard exists for.
    COLLAPSE_ENERGY_FRACTION = 0.5;
    % localMeasureInWindow - one peak-relative measurement inside `windowHz`.
    % Inputs: specFull - unmasked (already Nyquist-recentred) spectrum;
    %         fAxis - the shifted frequency axis; sampleRate, pct, peakRelDb -
    %         estimator settings; windowHz - [lo hi] on the shifted axis or [];
    %         fcShiftHz - the recentre shift, used to report the window in true
    %         frequency.
    % Outputs: bwHz - the estimate; info - per-attempt diagnostics;
    %          windowWidthHz - width of the window that took effect (Inf when
    %          none, so the caller stops growing).
    info = struct('BwPeakHz', 0, 'BwFloorHz', 0, 'PeakToNoiseFloorDb', NaN, ...
        'CollapseGuardFired', false, 'PriorWindowApplied', false, ...
        'PriorWindowHz', [], 'PriorWindowFillRatio', NaN);
    [spec, inWindow, applied, appliedWindowHz] = ...
        localApplyWindow(specFull, fAxis, windowHz);
    info.PriorWindowApplied = applied;
    if applied
        info.PriorWindowHz = appliedWindowHz + fcShiftHz;
        windowWidthHz = appliedWindowHz(2) - appliedWindowHz(1);
    else
        windowWidthHz = Inf;
    end

    peakVal = max(spec);
    if peakVal <= 0
        bwHz = 0;
        return;
    end

    bwHz = csrd.pipeline.measurement.narrowestEnergySpan(spec, fAxis, ...
        sampleRate, peakVal * 10 ^ (peakRelDb / 10), pct);
    info.BwPeakHz = bwHz;

    % Collapse guard. A flat occupied band a few dB below a single localized
    % spike (short bursts, or a frequency-selective channel peak) puts the
    % peak-relative threshold ABOVE the flat band and clips it away, collapsing
    % the width to the spike's neighbourhood (e.g. a realized ~17 MHz QAM
    % measured at ~1.5 MHz). Fall back to a noise-floor-relative span only when
    % the peak-relative result is implausibly narrow, so the common case is
    % unchanged. The floor percentile is taken over IN-WINDOW bins only -- the
    % zeroed out-of-window bins would drag the 10th percentile to zero and make
    % the floor-relative span meaningless. It must also stay BELOW the minimum
    % noise fraction: an emitter may occupy up to
    % MaxBandwidthFractionOfSampleRate (=0.8) of the band, leaving >=20% noise
    % bins, so a 25th-percentile floor would land INSIDE a wideband occupied band
    % and defeat the guard.
    floorVal = prctile(spec(inWindow), 10);
    floorThreshold = floorVal * 10 ^ (6 / 10);
    peakThreshold = peakVal * 10 ^ (peakRelDb / 10);
    bwFloor = csrd.pipeline.measurement.narrowestEnergySpan(spec, fAxis, ...
        sampleRate, floorThreshold, pct);
    info.BwFloorHz = bwFloor;
    if floorVal > 0
        info.PeakToNoiseFloorDb = 10 * log10(peakVal / floorVal);
    end
    % The guard needs an ENERGY test, not just a width test. "The floor-relative
    % band is much wider" is true for ANY narrow emitter in a leaky spectrum, so
    % width alone made the guard fire on signals that were narrow simply because
    % they ARE narrow. Observed consequence: a 0.586 MHz emitter on a
    % 1024-sample frame (nfft 256, so the signal is ~3 bins wide) was published
    % at 48.2 MHz -- the guard replaced the correct answer with the full-band
    % floor-relative span, 81x too wide.
    %
    % The guard's actual premise is that a flat occupied band was CLIPPED AWAY by
    % a threshold sitting above it. If that happened, the floor-relative band
    % holds materially more energy than the peak-relative one. If instead the
    % peak-relative band already holds nearly all the in-window energy, nothing
    % was clipped and there is nothing to rescue.
    peakEnergy = sum(spec(spec >= peakThreshold));
    floorEnergy = sum(spec(spec >= floorThreshold));
    energyWasClipped = floorEnergy > 0 && ...
        peakEnergy < COLLAPSE_ENERGY_FRACTION * floorEnergy;
    if bwFloor > 0 && bwHz < 0.3 * bwFloor && energyWasClipped
        bwHz = bwFloor;
        info.CollapseGuardFired = true;
    end
    if applied && windowWidthHz > 0
        info.PriorWindowFillRatio = bwHz / windowWidthHz;
    end
end

function info = localMergeWindowInfo(info, attempt, growth)
    % localMergeWindowInfo - copy one attempt's diagnostics onto the output info.
    % Inputs: info - accumulating diagnostics; attempt - localMeasureInWindow
    %         diagnostics; growth - how many doublings had been applied.
    % Outputs: info - updated diagnostics.
    info.BwPeakHz = attempt.BwPeakHz;
    info.BwFloorHz = attempt.BwFloorHz;
    info.PeakToNoiseFloorDb = attempt.PeakToNoiseFloorDb;
    info.CollapseGuardFired = attempt.CollapseGuardFired;
    info.PriorWindowApplied = attempt.PriorWindowApplied;
    info.PriorWindowHz = attempt.PriorWindowHz;
    info.PriorWindowFillRatio = attempt.PriorWindowFillRatio;
    info.PriorWindowGrowths = growth;
end

function [spec, inWindow, applied, appliedWindowHz] = localApplyWindow(specFull, fAxis, windowHz)
    % localApplyWindow - zero the bins outside `windowHz` (shifted-axis Hz).
    % Inputs: specFull - unmasked spectrum; fAxis - shifted frequency axis;
    %         windowHz - [lo hi] on that same shifted axis, or [] for no window.
    % Outputs: spec - masked spectrum; inWindow - logical mask;
    %          applied - whether a window actually took effect;
    %          appliedWindowHz - the window in effect ([] when none).
    %
    % A window that excludes every bin, or that contains no energy at all, is NOT
    % applied: forcing a measurement inside a window the signal is not in would
    % turn a plan-versus-realization mismatch into a fabricated narrow label. The
    % honest answer there is the full-band measurement plus a diagnostic recording
    % that no window took effect.
    spec = specFull;
    inWindow = true(size(specFull));
    applied = false;
    appliedWindowHz = [];
    if isempty(windowHz)
        return;
    end
    candidate = fAxis >= windowHz(1) & fAxis <= windowHz(2);
    if ~any(candidate) || ~any(specFull(candidate) > 0)
        return;
    end
    inWindow = candidate;
    spec(~inWindow) = 0;
    applied = true;
    appliedWindowHz = [windowHz(1), windowHz(2)];
end
