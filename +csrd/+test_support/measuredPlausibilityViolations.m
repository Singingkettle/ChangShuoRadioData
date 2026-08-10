function violations = measuredPlausibilityViolations(sourcePlane, sampleRate, tag, context)
%MEASUREDPLAUSIBILITYVIOLATIONS Hard physical-bound checks on a measured SourcePlane.
%
%   violations = measuredPlausibilityViolations(sourcePlane, sampleRate, tag)
%   violations = measuredPlausibilityViolations(sourcePlane, sampleRate, tag, context)
%
%   Returns a cell array of human-readable violation strings; empty means every
%   bound holds. Unlike a finiteness/shape check, these are PHYSICAL bounds a
%   receiver capturing at `sampleRate` cannot break, so a breach is a definitive
%   bug (the finite-but-physically-impossible class), not measurement variance:
%
%       0   <  OccupiedBandwidthHz <= 0.85 * SampleRate  (see note below)
%       |CenterFrequencyHz|        <= SampleRate / 2  (must sit in the captured
%                                                      passband)
%       0  <= TimeOccupancy        <= 1               (a fraction)
%       0  <= FrequencyOccupancy   <= 1               (a fraction)
%       -100 <= SNRdB              <= 200             (no infinite/absurd SNR)
%
%   With `context` supplied, two cross-plane bounds are added:
%
%       OccupiedBandwidthHz <= 2.5 * context.ExecutionBwHz   (inflation)
%       OccupiedBandwidthHz >= 0.25 * context.ExecutionBwHz  (collapse)
%
%   NOTE on the 0.85*Fs absolute bound. The generator caps an emitter at
%   Regulatory.MaxBandwidthFractionOfSampleRate = 0.8 of the receiver sample
%   rate, so a SourcePlane (single-emitter) measurement above 0.85*Fs is not a
%   wide emitter -- it is the peak-relative estimator having lost the noise
%   floor and bridged the whole capture band. The former `<= Fs` bound could
%   not catch that: a 7.3 MHz emitter measured at 45.4 MHz on a 50 MHz grid
%   passed cleanly. 0.85 = the 0.8 cap plus ~6 % slack for FFT-bin
%   granularity, Doppler and rolloff on a maximally wide emitter.
%
%   NOTE on the cross-plane ratios. Truth.Execution.ModulatedBandwidthHz is
%   the same estimator run on the clean pre-channel waveform, so the two
%   agree to ~1 % at usable SNR (release baseline P95 = 0.0222). The worst
%   physically explainable low-SNR ratio is ~1.7x; catastrophic bridging runs
%   3.2x-6.6x. 2.5 sits between them. The 0.25 lower bound sits just below
%   the estimator's internal collapse guard trip point (0.3) so a legitimate
%   guard fallback can never self-trip.
%
%   Only finite scalar fields are checked; missing or NaN fields are left to the
%   separate coverage gate. A source explicitly marked unresolvable or silent
%   (MeasurementStatus other than 'Measured') is exempt from the cross-plane
%   bounds, since its scalars are not claimed to be labels.
%
%   Inputs:
%     sourcePlane - Truth.Measured.SourcePlane struct for one source.
%     sampleRate  - receiver sample rate in Hz (positive finite scalar).
%     tag         - short label used in the violation strings.
%     context     - optional struct. Recognised fields:
%                     .ExecutionBwHz     - Truth.Execution.ModulatedBandwidthHz
%                     .MeasurementStatus - status string, when known
%
%   Outputs:
%     violations - cell array of violation description strings (empty = clean).

if nargin < 3 || isempty(tag)
    tag = 'source';
end
if nargin < 4 || isempty(context)
    context = struct();
end

violations = {};
tol = 1.02; % small slack for FFT-bin granularity / floating point

% Emitters are capped at MaxBandwidthFractionOfSampleRate (0.8) of Fs; anything
% materially above that is the estimator bridging the capture band, not a wide
% emitter.
maxOccupiedFraction = 0.85;

claimsMeasurement = true;
if isfield(context, 'MeasurementStatus') && ~isempty(context.MeasurementStatus)
    claimsMeasurement = strcmpi(char(string(context.MeasurementStatus)), 'Measured');
end

if localFiniteScalar(sourcePlane, 'OccupiedBandwidthHz')
    ob = sourcePlane.OccupiedBandwidthHz;
    if ob <= 0 || ob > sampleRate * maxOccupiedFraction * tol
        violations{end + 1} = sprintf( ...
            '%s OccupiedBandwidthHz=%.4g out of (0, %.2f*Fs=%.4g]', ...
            tag, ob, maxOccupiedFraction, sampleRate * maxOccupiedFraction);
    end

    if claimsMeasurement && localFiniteScalar(context, 'ExecutionBwHz') && ...
            context.ExecutionBwHz > 0
        execBw = context.ExecutionBwHz;
        ratio = ob / execBw;
        if ratio > 2.5
            violations{end + 1} = sprintf( ...
                '%s OccupiedBandwidthHz=%.4g is %.2fx its own ExecutionBw=%.4g (>2.5x)', ...
                tag, ob, ratio, execBw);
        elseif ratio < 0.25
            violations{end + 1} = sprintf( ...
                '%s OccupiedBandwidthHz=%.4g is %.2fx its own ExecutionBw=%.4g (<0.25x)', ...
                tag, ob, ratio, execBw);
        end
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
