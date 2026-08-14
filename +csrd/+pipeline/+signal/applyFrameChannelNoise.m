function [noisySignal, info] = applyFrameChannelNoise(components, cleanCombined)
%APPLYFRAMECHANNELNOISE One channel-noise realization per receiver frame.
%
%   [noisySignal, info] = applyFrameChannelNoise(components, cleanCombined)
%
%   Selects the frame's REFERENCE noise descriptor -- the first component in
%   construction order that owes channel noise (a PendingChannelNoise struct
%   planned by ChannelFactory.planChannelNoise) -- and realizes it ONCE over
%   the WHOLE combined frame buffer via realizeChannelNoise.
%
%   WHY ONE REALIZATION, WHOLE FRAME
%   The previous per-component injection added each link's owed noise on that
%   component's burst slice only. Physically a receiver has ONE front-end noise
%   floor; the per-component sum realized K independent noise floors wherever K
%   bursts overlapped (labels optimistic by ~10*log10(K) dB, correlated with the
%   hidden overlap count), and samples outside every burst carried NO channel
%   noise at all -- the saved frame's noise floor was a step function of the
%   instantaneous overlap count, a directly learnable leak of the GT burst
%   timing. One whole-frame realization removes both: the floor is flat across
%   gaps and independent of K.
%
%   REFERENCE CHOICE. First-in-construction-order is deterministic under the
%   scenario seed and requires no power comparison (a "strongest emitter" rule
%   would couple the frame's noise floor to fading realizations). The chosen
%   component's descriptor carries the frame-salted Seed and its link's
%   requested PowerW; the per-emitter SNR labels are then RE-MEASURED against
%   the realized frame noise (see localMeasuredReceivedSnr), so emitters other
%   than the reference get honest, emergent SNR labels rather than their own
%   requested targets -- the owner-approved GT-reflects-realization trade.
%
%   Inputs:
%     components    - cell array of component structs in construction order
%                     (each may carry .PendingChannelNoise).
%     cleanCombined - the combined, antenna-collapsed, frame-length clean
%                     buffer the noise is added to.
%
%   Outputs:
%     noisySignal - cleanCombined plus one whole-frame noise realization (or
%                   unchanged when no component owes noise).
%     info        - realizeChannelNoise's info struct plus:
%                     .ReferenceComponentIndex - index into components of the
%                       descriptor used (NaN when none).
%
%   See also: csrd.pipeline.signal.realizeChannelNoise,
%             csrd.factories.ChannelFactory.planChannelNoise

descriptor = [];
referenceIdx = NaN;
if iscell(components)
    for k = 1:numel(components)
        comp = components{k};
        if isstruct(comp) && isfield(comp, 'PendingChannelNoise') && ...
                isstruct(comp.PendingChannelNoise) && ...
                ~isempty(comp.PendingChannelNoise)
            descriptor = comp.PendingChannelNoise;
            referenceIdx = k;
            break;
        end
    end
end

[noisySignal, info] = csrd.pipeline.signal.realizeChannelNoise( ...
    descriptor, cleanCombined);
info.ReferenceComponentIndex = referenceIdx;
end
