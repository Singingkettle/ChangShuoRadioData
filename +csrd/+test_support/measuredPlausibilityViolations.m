function violations = measuredPlausibilityViolations(sourcePlane, sampleRate, tag)
%MEASUREDPLAUSIBILITYVIOLATIONS Hard physical-bound checks on a measured SourcePlane.
%
%   violations = measuredPlausibilityViolations(sourcePlane, sampleRate, tag)
%
%   Returns a cell array of human-readable violation strings; empty means every
%   bound holds. Unlike a finiteness/shape check, these are PHYSICAL bounds a
%   receiver capturing at `sampleRate` cannot break, so a breach is a definitive
%   bug (the finite-but-physically-impossible class), not measurement variance:
%
%       0   <  OccupiedBandwidthHz <= SampleRate     (cannot occupy more than the
%                                                      captured band)
%       |CenterFrequencyHz|        <= SampleRate / 2  (must sit in the captured
%                                                      passband)
%       0  <= TimeOccupancy        <= 1               (a fraction)
%       0  <= FrequencyOccupancy   <= 1               (a fraction)
%       -100 <= SNRdB              <= 200             (no infinite/absurd SNR)
%
%   Only finite scalar fields are checked; missing or NaN fields are left to the
%   separate coverage gate.

if nargin < 3 || isempty(tag)
    tag = 'source';
end

violations = {};
tol = 1.02; % small slack for FFT-bin granularity / floating point

if localFiniteScalar(sourcePlane, 'OccupiedBandwidthHz')
    ob = sourcePlane.OccupiedBandwidthHz;
    if ob <= 0 || ob > sampleRate * tol
        violations{end + 1} = sprintf( ...
            '%s OccupiedBandwidthHz=%.4g out of (0, Fs=%.4g]', tag, ob, sampleRate);
    end
end

if localFiniteScalar(sourcePlane, 'CenterFrequencyHz')
    ce = sourcePlane.CenterFrequencyHz;
    if abs(ce) > (sampleRate / 2) * tol
        violations{end + 1} = sprintf( ...
            '%s |CenterFrequencyHz|=%.4g > Fs/2=%.4g', tag, abs(ce), sampleRate / 2);
    end
end

if localFiniteScalar(sourcePlane, 'TimeOccupancy')
    to = sourcePlane.TimeOccupancy;
    if to < -1e-3 || to > 1 + 1e-3
        violations{end + 1} = sprintf('%s TimeOccupancy=%.4g out of [0,1]', tag, to);
    end
end

if localFiniteScalar(sourcePlane, 'FrequencyOccupancy')
    fo = sourcePlane.FrequencyOccupancy;
    if fo < -1e-3 || fo > 1 + 1e-3
        violations{end + 1} = sprintf('%s FrequencyOccupancy=%.4g out of [0,1]', tag, fo);
    end
end

if localFiniteScalar(sourcePlane, 'SNRdB')
    sn = sourcePlane.SNRdB;
    if sn < -100 || sn > 200
        violations{end + 1} = sprintf('%s SNRdB=%.4g out of [-100,200]', tag, sn);
    end
end
end


function tf = localFiniteScalar(s, f)
tf = isstruct(s) && isfield(s, f) && isnumeric(s.(f)) ...
    && isscalar(s.(f)) && isfinite(s.(f));
end
