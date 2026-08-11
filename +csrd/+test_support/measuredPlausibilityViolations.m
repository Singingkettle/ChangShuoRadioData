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
%   With `context` supplied, one cross-plane bound is added:
%
%       OccupiedBandwidthHz <= PROPAGATION_INFLATION_LIMIT * context.ExecutionBwHz
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
%   NOTE on the cross-plane bound, and on what it can and cannot prove. Both
%   planes now run ONE kernel (occupiedBandwidthCore) on clean, per-emitter,
%   per-antenna buffers; they differ only in WHICH buffer. So this ratio polices
%   exactly one stage -- propagation -- and it structurally CANNOT detect a wrong
%   bandwidth DEFINITION, because a wrong definition moves both planes together.
%   That blind spot is not hypothetical: it is how a -3 dB-down width shipped for
%   several releases under the name "occupied bandwidth" while this gate stayed
%   green. Definitional correctness is proved elsewhere, against an EXTERNAL
%   analytic prediction (a root-raised-cosine single carrier measures
%   OBW = 1.100 * Rs at beta = 0.25, and can never exceed (1+beta) * Rs because the
%   pulse is strictly bandlimited) -- never against the other plane.
%
%   The limit is derived from measurement, not chosen: over 1413 sources spanning
%   AWGN / Rayleigh / Rician the ratio is 1.0000 at the median, with a maximum of
%   1.0002 for AWGN (pure bin-grid quantisation) and 1.0175 for Rayleigh. Rician
%   reaches 13.67, and that tail is understood: short bursts clipped at a frame
%   boundary, where a hard-gated burst of duration T genuinely occupies ~10/T at
%   the 99 % power level. That is a TRUE statement about an unphysically gated
%   signal, so it must not be masked by widening this bound. Such sources are
%   caught by the resolution test instead, which names the real problem.
%
%   The former 0.25x lower bound is GONE. It was calibrated against a
%   peak-relative estimator's internal collapse-guard trip point, and that
%   estimator no longer exists; a power integral has no guard to self-trip. A
%   collapse now shows up as a resolution-cell count near 1, checked directly.
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

% Propagation is the ONLY stage between Truth.Execution and Truth.Measured, so the
% ratio between them is a fading/Doppler bound. Measured over 1413 sources: AWGN
% max 1.0002, Rayleigh max 1.0175, Rician p95 1.304. 1.6 leaves headroom for a
% deeper multipath profile than the registered statistical models produce while
% still rejecting the order-of-magnitude excursions.
PROPAGATION_INFLATION_LIMIT = 1.6;

% Minimum analysis cells for the reported width to be a bandwidth statement at
% all. ITU-R SM.443 wants a measurement RBW at ~1-3 % of the occupied bandwidth
% (>= ~33 cells). 8 sits deliberately far below that: this bound is for values
% that are not bandwidths, not for values measured coarsely. The gap between 8 and
% 33 is a quality signal for the consumer, published as BandwidthResolutionCells,
% not a failure here.
MIN_RESOLUTION_CELLS = 8;

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

    % A reading spanning only a handful of analysis cells is a resolution floor,
    % not a bandwidth -- and it is also the mechanism behind the widest
    % propagation-ratio outliers. Test it FIRST so such a source is reported for
    % what it is instead of being blamed on propagation.
    resolvedBandwidth = true;
    if localFiniteScalar(sourcePlane, 'BandwidthResolutionCells')
        cells = sourcePlane.BandwidthResolutionCells;
        if cells < MIN_RESOLUTION_CELLS
            resolvedBandwidth = false;
            violations{end + 1} = sprintf( ...
                ['%s OccupiedBandwidthHz=%.4g spans only %.2f analysis cells ', ...
                 '(RBW=%.4g Hz): a resolution floor, not a measured bandwidth'], ...
                tag, ob, cells, localFieldOrNaN(sourcePlane, 'BandwidthResolutionHz'));
        end
    end

    if claimsMeasurement && resolvedBandwidth && ...
            localFiniteScalar(context, 'ExecutionBwHz') && context.ExecutionBwHz > 0
        execBw = context.ExecutionBwHz;
        ratio = ob / execBw;
        if ratio > PROPAGATION_INFLATION_LIMIT
            % Report the burst length with the ratio. Propagation is the only
            % PIPELINE stage between the planes, but it is not the only cause: a
            % burst clipped at a frame boundary is hard-gated, and a hard-gated
            % burst of duration T genuinely occupies ~10/T at the 99 % power level.
            % Naming the sample count here stops a gating artefact from being
            % misread as a fading defect.
            violations{end + 1} = sprintf( ...
                ['%s OccupiedBandwidthHz=%.4g is %.3fx its own ExecutionBw=%.4g ', ...
                 '(>%.2fx) on %g active samples at RBW=%.4g Hz; propagation is ', ...
                 'the only pipeline stage between the two planes, so either ', ...
                 'fading reshaped the spectrum or the burst was hard-gated short'], ...
                tag, ob, ratio, execBw, PROPAGATION_INFLATION_LIMIT, ...
                localFieldOrNaN(sourcePlane, 'ActiveSampleCount'), ...
                localFieldOrNaN(sourcePlane, 'BandwidthResolutionHz'));
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


function v = localFieldOrNaN(s, f)
v = NaN;
if localFiniteScalar(s, f)
    v = double(s.(f));
end
end


function tf = localFiniteScalar(s, f)
tf = isstruct(s) && isfield(s, f) && isnumeric(s.(f)) ...
    && isscalar(s.(f)) && isfinite(s.(f));
end
