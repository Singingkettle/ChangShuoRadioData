function noiseBW = resolveNoiseBandwidth(configuredBW, rxBW, txBW, fallbackBW)
%RESOLVENOISEBANDWIDTH Pick the noise bandwidth used in the link-budget SNR.
%
%   noiseBW = csrd.utils.linkbudget.resolveNoiseBandwidth(configuredBW, ...
%       rxBW, txBW, fallbackBW)
%
%   Returns the smallest *positive* candidate among:
%       - configuredBW : link-budget configured noise bandwidth (Hz)
%       - rxBW         : receiver observation bandwidth (Hz)
%       - txBW         : currently transmitted occupied bandwidth (Hz)
%
%   The clamp prevents narrow-band signals from being annotated with a
%   pessimistic SNR derived from spectrum the Tx is not even using.
%
%   When all of {configuredBW, rxBW, txBW} are missing or non-positive,
%   the function returns ``fallbackBW`` (also expected to be > 0). This
%   is the only place where a "magic number" is allowed to leak in, and
%   even then it must be supplied by the caller; the function never
%   invents one of its own.
%
%   Inputs may be empty arrays or NaN; only finite, positive values are
%   considered.

    if nargin < 4
        fallbackBW = 50e6;
    end

    candidates = [configuredBW(:); rxBW(:); txBW(:)];
    candidates = candidates(isfinite(candidates) & candidates > 0);

    if isempty(candidates)
        noiseBW = fallbackBW;
        return;
    end

    noiseBW = min(candidates);
end
