function [noisySignal, info] = realizeChannelNoise(pendingChannelNoise, cleanSignal)
%REALIZECHANNELNOISE The pipeline's single channel-noise injection point.
%
%   noisySignal = realizeChannelNoise(pendingChannelNoise, cleanSignal)
%   [noisySignal, info] = realizeChannelNoise(...)
%
%   Adds the noise a link owes, described by the `PendingChannelNoise` descriptor
%   that `csrd.factories.ChannelFactory.planChannelNoise` sized but did not add.
%
%   WHY THIS IS A SEPARATE, PUBLIC FUNCTION
%   This is the one place where noise enters the dataset, and it therefore decides
%   the realized SNR of every saved frame. It used to be a local function inside a
%   private method file, where nothing could call it, so the most safety-critical
%   single step in the pipeline had no direct test coverage -- its behaviour was
%   only ever observed through end-to-end statistics that could not distinguish a
%   seeding bug from a power-accounting bug. Extracting it makes the contract
%   assertable on its own terms.
%
%   ORDERING. This runs AFTER both measured planes are taken from the clean
%   buffers. That is not an implementation detail: a power-integral occupied
%   bandwidth is undefined on a noisy buffer, because noise contributes power
%   across the whole band, so measuring first is what makes the labels usable.
%   `csrd.pipeline.signal` is also where the receiver RF chain reads from, and the
%   chain runs after this call, so a buffer that has passed through here carries
%   the channel noise but not yet thermal noise or ADC quantisation.
%
%   POWER SCALE. `PowerW` is at the antenna-COLLAPSED scale, because the buffer
%   this runs on has already been collapsed and frame-clipped. Drawing one
%   collapsed realization at the summed-scale power is statistically identical to
%   summing per-antenna realizations, which is how the noise was realized before
%   the measurement moved ahead of injection -- so the reorder did not change the
%   noise distribution, only when it is applied.
%
%   DETERMINISM. `Seed` is burst-deterministic and frame-salted
%   (`ChannelFactory.frameSaltedNoiseSeed`): the same frame reproduces the same
%   realization, while successive frames get independent ones. Additive noise is
%   i.i.d. per observation window, so a seed that excluded the frame would give
%   every frame of a scenario a byte-identical noise mask -- a per-scenario
%   fingerprint a model can memorise instead of learning the signal. A dedicated
%   RandStream is used rather than the global stream so no caller's random state
%   is disturbed and the result cannot depend on execution order.
%
%   PASS-THROUGH. A missing, malformed, or non-positive descriptor returns the
%   input unchanged with `info.Applied` false. That is a real case, not a defect:
%   a link with a distance-based SNR that resolved to nothing finite owes no
%   channel noise. It is reported rather than silently indistinguishable from a
%   noise power that happened to be tiny.
%
%   Inputs:
%     pendingChannelNoise - struct with fields:
%                             .PowerW      - positive finite scalar, antenna-
%                                            collapsed noise power in watts
%                             .Seed        - finite numeric scalar
%                             .TargetSnrDb - optional, carried through to info
%                           Anything else (including []) means "no noise owed".
%     cleanSignal         - numeric array, the collapsed frame-clipped buffer.
%
%   Outputs:
%     noisySignal - cleanSignal plus the realized noise, or cleanSignal unchanged.
%     info        - struct with:
%                     .Applied       - logical, whether noise was added
%                     .Reason        - char, why it was not applied ('' if it was)
%                     .NoisePowerW   - requested power (0 when not applied)
%                     .RealizedPowerW- measured power of the realization drawn
%                     .TargetSnrDb   - carried through, NaN when absent
%
%   See also: csrd.factories.ChannelFactory.planChannelNoise

noisySignal = cleanSignal;
info = struct('Applied', false, 'Reason', '', 'NoisePowerW', 0, ...
    'RealizedPowerW', 0, 'TargetSnrDb', NaN);

if ~isstruct(pendingChannelNoise) || isempty(pendingChannelNoise)
    info.Reason = 'no descriptor';
    return;
end

if isfield(pendingChannelNoise, 'TargetSnrDb') && ...
        isnumeric(pendingChannelNoise.TargetSnrDb) && ...
        isscalar(pendingChannelNoise.TargetSnrDb)
    info.TargetSnrDb = double(pendingChannelNoise.TargetSnrDb);
end

if ~isfield(pendingChannelNoise, 'PowerW') || ...
        ~isnumeric(pendingChannelNoise.PowerW) || ...
        ~isscalar(pendingChannelNoise.PowerW) || ...
        ~isfinite(pendingChannelNoise.PowerW) || pendingChannelNoise.PowerW <= 0
    info.Reason = 'PowerW absent or not a positive finite scalar';
    return;
end

if ~isfield(pendingChannelNoise, 'Seed') || ...
        ~isnumeric(pendingChannelNoise.Seed) || ...
        ~isscalar(pendingChannelNoise.Seed) || ...
        ~isfinite(pendingChannelNoise.Seed)
    info.Reason = 'Seed absent or not a finite scalar';
    return;
end

if isempty(cleanSignal)
    info.Reason = 'empty signal';
    return;
end

% Split the power equally between the real and imaginary parts: for circularly
% symmetric complex noise, E[|n|^2] = 2 * var(re) so each part carries PowerW/2.
noisePowerW = double(pendingChannelNoise.PowerW);
rs = RandStream('mt19937ar', 'Seed', double(pendingChannelNoise.Seed));
noiseStd = sqrt(noisePowerW / 2);
noise = noiseStd * (randn(rs, size(cleanSignal)) + 1i * randn(rs, size(cleanSignal)));

noisySignal = cleanSignal + noise;
info.Applied = true;
info.NoisePowerW = noisePowerW;
info.RealizedPowerW = mean(abs(noise(:)) .^ 2);
end
