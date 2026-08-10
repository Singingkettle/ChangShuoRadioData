function [bwHz, status, info] = resolveOccupiedBandwidth(signalCol, sampleRate, pct, peakRelDb, isSingleEmitter)
%RESOLVEOCCUPIEDBANDWIDTH Three-tier occupied-bandwidth resolution.
% Inputs: see signature arguments and local validation.
% Outputs: see signature return values and contract fields.
%
% Decides between the two estimators in the measurement package and, where
% neither can resolve the band, says so instead of publishing a number.
%
% WHY TWO ESTIMATORS ARBITRATE EACH OTHER
% Their failure modes are opposite, and that is what removes the need for a
% precise "is this reading inflated?" detector:
%   - peakRelativeObwCore only ever INFLATES (it bridges the band once the noise
%     floor crosses the -3 dBc clip), and it has the finer frequency resolution,
%     so it must stay the primary estimate.
%   - lowSnrObw only ever UNDER-measures when it fails (it collapses toward 0),
%     never over-measures: across a 510-sample calibration its worst
%     over-estimate was 1.02x. It also self-reports whether it can be trusted,
%     and that report was one-sided-perfect: never true for a collapsed answer.
% So a large disagreement in which the robust value is much SMALLER, from a
% robust estimator that certifies itself, can only mean the fine estimate was
% inflated.
%
% TIERS
%   1. Take the peak-relative estimate.
%   2. If the robust estimator certifies itself AND reports a materially
%      narrower band (< 0.70x), the fine estimate had bridged the noise floor;
%      publish the robust value. A collapsed robust answer never reaches this
%      test: lowSnrObw withholds its own certification when the span it found is
%      only a couple of its analysis bins wide.
%   3. If the robust estimator RAN and could not certify itself, the fine
%      estimate has saturated (>= 0.85 of the sample rate, above the 0.8 emitter
%      cap the generator enforces), and the fine estimate did not come from its
%      own collapse guard, then neither estimator resolved the band; report
%      'Unresolved' and let the caller null the affected scalars.
%   Otherwise the two agree, or the robust one is dead while the fine one looks
%   physically sane; publish the fine estimate.
%
% CALIBRATED OUTCOME (6 families x 17 SNRs x 5 seeds, 510 samples, error
% measured against each family's clean-signal reference):
%   absolute relative error  P50      P95      MAX
%     peak-relative alone    0.038    5.579    26.121
%     this resolution        0.007    0.112     1.157
%   Every sample at SNR >= 6 dB took tier 1 unchanged, which is what keeps the
%   frozen release gate (ExecutionVsMeasuredBwAbsRelDiffP95) untouched.
%
% Inputs:
%   signalCol  - complex column vector (antenna collapsing is the caller's job).
%   sampleRate - positive finite scalar (Hz).
%   pct        - energy percentage in (0, 100].
%   peakRelDb  - peak-relative clip in dB, strictly negative.
%   isSingleEmitter - optional logical, default true. The saturation test in
%            tier 3 assumes ONE emitter, which the generator caps at 0.8 of the
%            sample rate; a reading near Fs therefore means the estimator
%            bridged the band. That reasoning does not hold for a COMBINED
%            multi-emitter frame, which legitimately spans the whole capture.
%            Pass false for such a plane so tier 3 is skipped (tier 2 recovery
%            still applies).
%
% Outputs:
%   bwHz   - resolved occupied bandwidth in Hz, or NaN when status is
%            'Unresolved'.
%   status - 'Measured' | 'Unresolved'. 'Unresolved' means the waveform carried
%            energy but its occupied bandwidth could not be separated from the
%            noise floor, so bwHz must NOT be used as a label.
%   info   - struct with .Estimator ('peak-relative' | 'lowsnr'),
%            .UnresolvedBwHz (the rejected fine estimate when status is
%            'Unresolved', NaN otherwise), .PeakRelative (peakRelativeObwCore
%            diagnostics) and .LowSnr (lowSnrObw diagnostics).
%
% See also: csrd.pipeline.measurement.peakRelativeObwCore
%           csrd.pipeline.measurement.lowSnrObw

% A robust value below this fraction of the fine value is a disagreement, not
% resolution noise. Calibration: agreement cases sit at 0.83..1.18x; genuine
% inflation recoveries drive the fraction to 0.04..0.37x (the low end being a
% very narrow emitter whose fine estimate bridged the whole capture band).
%
% There is deliberately NO lower bound here. Rejecting a collapsed robust value
% is lowSnrObw's own job, via its minimum-resolved-bins self-assessment: a ratio
% floor at this level cannot separate "narrow emitter recovered from a bridged
% fine estimate" (0.04x, legitimate) from "robust estimator collapsed" (0.01x),
% because both are small for the same arithmetic reason.
DISAGREEMENT_FRACTION = 0.70;
% Emitters are capped at Regulatory.MaxBandwidthFractionOfSampleRate = 0.8, so a
% single-emitter reading at or above this fraction is the estimator having
% bridged the capture band. Calibration: healthy readings peaked at 0.79,
% bridged ones started at 0.86.
SATURATION_FRACTION = 0.85;

if nargin < 5 || isempty(isSingleEmitter)
    isSingleEmitter = true;
end

[bwPeak, peakInfo] = csrd.pipeline.measurement.peakRelativeObwCore( ...
    signalCol, sampleRate, pct, peakRelDb);

info = struct( ...
    'Estimator', 'peak-relative', ...
    'UnresolvedBwHz', NaN, ...
    'PeakRelative', peakInfo, ...
    'LowSnr', []);

status = 'Measured';
bwHz = bwPeak;

if bwPeak <= 0
    % No bin survived even the fine estimator's threshold. The caller already
    % treats a non-positive bandwidth as a measurement failure; leave that path
    % untouched rather than reinterpreting it here.
    info.LowSnr = localEmptyLowSnrInfo();
    return;
end

[bwRobust, lowSnrInfo] = csrd.pipeline.measurement.lowSnrObw( ...
    signalCol, sampleRate, pct, peakRelDb);
info.LowSnr = lowSnrInfo;

if lowSnrInfo.Trustworthy && bwRobust > 0 && ...
        bwRobust < DISAGREEMENT_FRACTION * bwPeak
    bwHz = bwRobust;
    info.Estimator = 'lowsnr';
    return;
end

% Tier 3 needs positive evidence AGAINST the fine estimate, not merely the
% absence of a robust one. Two cases must keep their wide fine value:
%   - the robust estimator declined to run (input too short to average), so it
%     has said nothing. A one-sample impulse legitimately occupies the whole
%     observable band, and that is a documented contract.
%   - the fine estimator's own collapse guard produced the wide value. That is a
%     deliberate floor-relative fallback for a flat occupied band under a
%     localized spike, not a noise-bridging artifact, and tier 3 must not
%     overrule it.
robustWasEvaluated = ~strcmp(lowSnrInfo.ThresholdSource, 'not-evaluated');
if isSingleEmitter && robustWasEvaluated && ~lowSnrInfo.Trustworthy && ...
        ~peakInfo.CollapseGuardFired && ...
        bwPeak >= SATURATION_FRACTION * sampleRate
    info.UnresolvedBwHz = bwPeak;
    bwHz = NaN;
    status = 'Unresolved';
end
end

function info = localEmptyLowSnrInfo()
    % localEmptyLowSnrInfo - placeholder diagnostics when the robust estimator
    % was not consulted.
    % Inputs: none.
    % Outputs: struct matching lowSnrObw's info contract, all-inactive.
info = struct( ...
    'Trustworthy', false, ...
    'MarginDb', NaN, ...
    'SurvivingFraction', 0, ...
    'ThresholdSource', 'not-evaluated', ...
    'NoiseFloorPsd', NaN, ...
    'NumSegments', 0);
end
