function scs = snapSpacingForTractableResample(scs, N, receiverRate)
%SNAPSPACINGFORTRACTABLERESAMPLE Nudge a multicarrier spacing so it can be resampled.
%
%   scs = csrd.pipeline.signal.snapSpacingForTractableResample(scs, N, receiverRate)
%
%   A multicarrier modulator (OFDM / SCFDMA / OTFS) emits at scs*N, where N is the
%   FFT length (OFDM, SCFDMA) or the delay length (OTFS).
%   csrd.blocks.physical.txRadioFront.TRFSimulator.resampleToTarget resolves
%   receiverRate / (scs*N) into an EXACT rational p/q and REFUSES it when
%   max(p,q) > 50000, because such a resample is intractable -- and that refusal
%   loses the whole scenario, not just the emitter.
%
%   The subcarrier spacing is derived from the planned bandwidth as an arbitrary
%   real, so scs*N and the receiver rate routinely share no small factor. An OFDM
%   emitter at 15140.144 Hz x 2048 = 31.007 MHz against a 50 MHz receiver resolves
%   to 1902671/1179923 and fails -- measured at 1 scenario in 24 (4.2 %) before
%   this nudge existed.
%
%   This returns the scs closest to the input for which receiverRate/(scs*N) is an
%   exact small rational, trying the tightest tolerance first so the spacing moves
%   as little as possible. For the case above it moves 1.4e-8 relative, far below
%   any observable effect on the occupied bandwidth (= usableBins*scs, the only
%   quantity scs controls). A spacing that is ALREADY tractable has small factors,
%   so it snaps to a value within tolerance of itself and is never made worse.
%
%   Contrast with the single-carrier snapNarrowSymbolRateToReceiverGrid, which
%   forces an exact receiver SUBMULTIPLE and can therefore shift a rate by up to
%   2 %. Here the modulator rate need only be a small RATIONAL of the receiver
%   rate, not an integer submultiple, because the resampler handles p/q -- so the
%   spacing is kept essentially fixed.
%
%   MAX_FACTOR (50000) and the rat tolerances mirror
%   TRFSimulator.resampleToTarget deliberately: a spacing accepted here must not be
%   refused there. If those constants diverge, this becomes a lie and scenarios
%   fail again with no planner-side warning.
%
%   Inputs:
%     scs          - raw subcarrier spacing (Hz), positive.
%     N            - FFT length or delay length (samples per modulator symbol grid).
%     receiverRate - receiver sample rate (Hz). NaN/absent leaves scs unchanged.
%
%   Outputs:
%     scs - nudged spacing, or the input unchanged when no tractable rational
%           exists within 0.1 % (the caller then hits TRFSimulator's rate-naming
%           CSRD:TRF:UnsupportedResampleRatio rather than a silently distorted
%           emitter).
%
%   See also: csrd.blocks.physical.txRadioFront.TRFSimulator

if ~(scs > 0) || ~(N > 0) || ~isnumeric(receiverRate) || ~isscalar(receiverRate) ...
        || ~isfinite(receiverRate) || ~(receiverRate > 0)
    return;
end

MAX_FACTOR = 50000;
modRate = scs * N;
ratio = receiverRate / modRate;
for relTol = [1e-8, 1e-7, 1e-6, 1e-5, 1e-4, 1e-3]
    [p, q] = rat(ratio, relTol * ratio);
    if p > 0 && q > 0 && p <= MAX_FACTOR && q <= MAX_FACTOR
        scs = (receiverRate * q / p) / N;
        return;
    end
end
end
