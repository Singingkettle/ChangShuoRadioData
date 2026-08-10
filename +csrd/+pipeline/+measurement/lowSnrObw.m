function [bwHz, info] = lowSnrObw(signalCol, sampleRate, pct, peakRelDb)
%LOWSNROBW Noise-floor-subtracted occupied bandwidth for low-SNR waveforms.
% Inputs: see signature arguments and local validation.
% Outputs: see signature return values and contract fields.
%
% The peak-relative estimator in peakRelativeObwCore floats its threshold with
% the spectral PEAK, which is what makes clean and noisy measurements of the
% same waveform agree at usable SNR. It fails once the noise-floor PSD rises to
% within |peakRelDb| of the peak: the clip then retains scattered noise bins
% across the whole band and the narrowest-contiguous-span search bridges them,
% so the reported bandwidth saturates toward Fs.
%
% This estimator attacks that regime directly:
%   1. Trade frequency resolution for spectral-estimate VARIANCE. A short
%      window (256 points) yields K ~ N/128 averaged segments instead of ~8, so
%      the per-bin standard deviation falls by ~sqrt(K/8). The breakdown point
%      is set by that variance, not by a hard physical wall, which is why the
%      regime is recoverable at all.
%   2. Estimate the noise floor robustly (median, then three trimmed-mean
%      refinements over bins below 3x the running estimate) and SUBTRACT it, so
%      the threshold is applied to signal-only residual power.
%   3. Threshold at the larger of a peak-relative clip on the residual and a
%      statistical floor 4*N0/sqrt(K). The second term is the level below which
%      a retained bin is more likely a noise fluctuation than signal; it is what
%      stops the estimator from sieving noise back in.
%
% The coarse resolution is a deliberate trade and the reason this is NOT a
% drop-in replacement: on a clean narrowband waveform it reads up to ~18 % wider
% than the fine-resolution estimator. It is only worth using where the fine
% estimator has lost the noise floor.
%
% CALIBRATION (6 signal families x 17 SNRs x 5 pinned seeds, Fs = 50 MHz,
% N = 32768; families spanning 4 %..77 % occupancy incl. a Nyquist-straddling
% band and a 20 %-duty burst):
%   - Where `info.Trustworthy` is true the estimate lands within 0.75x..1.10x of
%     the clean-signal reference in 388 of 388 sampled cases.
%   - `info.Trustworthy` was false for every one of the 122 cases where this
%     estimator collapsed or under-measured, i.e. it never certifies a dead
%     answer. That one-sided property is what makes the three-tier decision in
%     resolveOccupiedBandwidth safe.
%   - `ThresholdSource == 'signal-limited'` was a sufficient condition on its
%     own: 313 such cases, all accurate, zero collapsed.
%
% Inputs:
%   signalCol  - complex column vector (antenna collapsing is the caller's job).
%   sampleRate - positive finite scalar (Hz).
%   pct        - energy percentage in (0, 100].
%   peakRelDb  - peak-relative clip applied to the RESIDUAL, strictly negative.
%
% Outputs:
%   bwHz - occupied bandwidth in Hz, or 0 when the residual carries no bin above
%          the threshold (the band is not resolvable from this waveform).
%   info - struct describing the estimate's own reliability:
%            .Trustworthy       - logical; see the criterion below
%            .MarginDb          - 10*log10(peakResidual / (N0/sqrt(K))), the
%                                 detection margin against the estimate's own
%                                 statistical fluctuation
%            .SurvivingFraction - fraction of bins above the threshold
%            .ThresholdSource   - 'signal-limited' | 'noise-limited' |
%                                 'not-evaluated' (input too short to average)
%            .NoiseFloorPsd     - the robust floor estimate that was subtracted
%            .NumSegments       - K, the number of averaged Welch segments
%
%          Trustworthy = NumSegments >= 8
%                        AND bwHz >= 4 analysis bins
%                        AND (signal-limited
%                             OR (MarginDb >= 8 AND SurvivingFraction >= 0.02)).
%          The 8 dB / 0.02 pair comes from the calibration above: the tightest
%          combination that keeps the most accurate cases (360 of 388) while
%          certifying none of the 122 collapsed ones. The segment and bin floors
%          were added afterwards, from real pipeline evidence that the
%          calibration could not produce - see their comments below.
%
% See also: csrd.pipeline.measurement.peakRelativeObwCore
%           csrd.pipeline.measurement.resolveOccupiedBandwidth

MARGIN_DB_MIN = 8;
SURVIVING_FRACTION_MIN = 0.02;
% NUM_SEGMENTS_MIN guards the one assumption the calibration could not check:
% it used full-frame continuous waveforms, where the segment count is ~255. A
% per-source buffer clipped to a short burst can leave only a handful of
% segments, and then the 4*N0/sqrt(K) term is so large that the answer collapses
% to one or two bins -- while `signal-limited` still certifies it, because a
% strong burst does put the residual peak above that huge threshold. Below this
% many segments the trimmed noise floor and the 1/sqrt(K) term are both too
% coarse to support a verdict. 8 segments matches the averaging the fine
% estimator itself relies on; the calibrated cases all had ~255, so this floor
% does not touch them.
NUM_SEGMENTS_MIN = 8;
% MIN_RESOLVED_BINS is the self-assessment that actually catches the collapse: an
% occupied band narrower than a few of this estimator's OWN analysis bins has not
% been resolved by it, whatever the threshold bookkeeping says. Measured on real
% pipeline sources, collapsed answers were 0.5-2 bins wide (97.7 / 195.3 /
% 390.6 kHz on a 195.3 kHz grid) while genuine low-SNR recoveries were 9-32 bins
% (1.76-6.2 MHz). 4 bins sits between them with margin either way.
%
% This must be an ABSOLUTE bin count, not a fraction of the fine estimate: a very
% narrow emitter legitimately recovers to ~0.04x of a fine value that has bridged
% the whole capture band, so a ratio floor cannot tell that apart from a collapse.
MIN_RESOLVED_BINS = 4;
NOISE_TRIM_FACTOR = 3;
NOISE_TRIM_ITERATIONS = 3;
STATISTICAL_FLOOR_SIGMA = 4;
WINDOW_LENGTH = 256;

info = struct( ...
    'Trustworthy', false, ...
    'MarginDb', NaN, ...
    'SurvivingFraction', 0, ...
    'ThresholdSource', 'noise-limited', ...
    'NoiseFloorPsd', NaN, ...
    'NumSegments', 0);

N = length(signalCol);
if N < 2 * WINDOW_LENGTH
    % Too short to buy meaningful averaging; the fine estimator is the better
    % answer here and the caller keeps it. Report 'not-evaluated' rather than a
    % failed verdict: the caller must be able to tell "this estimator declined to
    % run" from "it ran and could not resolve the band", because only the latter
    % is evidence against the fine estimate.
    bwHz = 0;
    info.ThresholdSource = 'not-evaluated';
    return;
end

winLen = WINDOW_LENGTH;
overlap = floor(winLen / 2);
nfft = winLen;
[pxx, fAxis] = pwelch(double(signalCol), hamming(winLen), overlap, nfft, ...
    sampleRate, 'centered');
spec = csrd.pipeline.measurement.circularRecenterSpectrum(pxx(:), sampleRate);
fAxis = fAxis(:);

if isempty(spec) || sum(spec) <= 0
    bwHz = 0;
    return;
end

numSegments = max(1, floor((N - overlap) / (winLen - overlap)));
info.NumSegments = numSegments;

% Robust noise floor: start from the median (immune to an occupied band up to
% half the span) then refine with trimmed means so a wide emitter does not drag
% the estimate up.
noiseFloor = median(spec);
for iter = 1:NOISE_TRIM_ITERATIONS
    below = spec <= NOISE_TRIM_FACTOR * noiseFloor;
    if any(below)
        noiseFloor = mean(spec(below));
    end
end
info.NoiseFloorPsd = noiseFloor;

residual = max(0, spec - noiseFloor);
peakResidual = max(residual);
if peakResidual <= 0
    bwHz = 0;
    return;
end

signalThreshold = peakResidual * 10 ^ (peakRelDb / 10);
statisticalFloor = STATISTICAL_FLOOR_SIGMA * noiseFloor / sqrt(numSegments);
if signalThreshold >= statisticalFloor
    info.ThresholdSource = 'signal-limited';
end
threshold = max(signalThreshold, statisticalFloor);

info.MarginDb = 10 * log10(peakResidual / max(noiseFloor / sqrt(numSegments), realmin));
info.SurvivingFraction = sum(residual >= threshold) / numel(residual);
bwHz = csrd.pipeline.measurement.narrowestEnergySpan(residual, fAxis, ...
    sampleRate, threshold, pct);

binWidthHz = sampleRate / nfft;
info.Trustworthy = numSegments >= NUM_SEGMENTS_MIN && ...
    bwHz >= MIN_RESOLVED_BINS * binWidthHz && ...
    (strcmp(info.ThresholdSource, 'signal-limited') || ...
     (info.MarginDb >= MARGIN_DB_MIN && ...
      info.SurvivingFraction >= SURVIVING_FRACTION_MIN));
end
