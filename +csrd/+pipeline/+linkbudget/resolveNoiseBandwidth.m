function noiseBW = resolveNoiseBandwidth(configuredBW, rxBW, txBW)
%RESOLVENOISEBANDWIDTH Pick the noise bandwidth used in the link-budget SNR.
% 中文说明：提供 CSRD 生产链路中的 resolveNoiseBandwidth 实现。
%
%   noiseBW = csrd.pipeline.linkbudget.resolveNoiseBandwidth(configuredBW, ...
%       rxBW, txBW)
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
%   the contract fails fast. A link-budget SNR label without a declared
%   noise bandwidth is not a simulated fact.
%
%   Inputs may be empty arrays or NaN; only finite, positive values are
%   considered.

    candidates = [configuredBW(:); rxBW(:); txBW(:)];
    candidates = candidates(isfinite(candidates) & candidates > 0);

    if isempty(candidates)
        error('CSRD:LinkBudget:MissingNoiseBandwidth', ...
            ['Noise bandwidth cannot be resolved. Provide at least one ', ...
             'finite positive value from LinkBudget.NoiseBandwidth, ', ...
             'receiver observable bandwidth, or segment bandwidth.']);
    end

    noiseBW = min(candidates);
end
