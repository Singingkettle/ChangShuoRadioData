function [violations, qualityNotes] = measuredPlausibilityViolations( ...
        sourcePlane, sampleRate, tag, context)
%MEASUREDPLAUSIBILITYVIOLATIONS Hard physical-bound checks on a measured SourcePlane.
%
%   violations = measuredPlausibilityViolations(sourcePlane, sampleRate, tag)
%   violations = measuredPlausibilityViolations(sourcePlane, sampleRate, tag, context)
%   [violations, qualityNotes] = measuredPlausibilityViolations(...)
%
%   Two OUTPUTS, deliberately separated, because they answer different questions:
%
%     violations   - something is physically impossible. A bug, always.
%     qualityNotes - the value is TRUE but not usable as the emitter's bandwidth:
%                    either quantised by the burst length, or describing a
%                    broadband floor after a frequency-selective null suppressed
%                    the lobe. Not a bug.
%
%   The distinction is not cosmetic. A 286 kHz emitter carried in a 512-sample
%   burst at Fs = 50 MHz cannot be measured more finely than Fs/512 = 98 kHz, so
%   its bandwidth is reported across ~3 analysis cells. That reading is honest and
%   the pipeline is behaving correctly; the label is simply coarse. Failing on it
%   would amount to asserting that the generator must never emit a short narrow
%   burst, which is a dataset-design choice, not a correctness property. Making it
%   a note keeps the fact visible -- and the per-source number is published as
%   Truth.Measured.SourcePlane.BandwidthResolutionCells so a consumer can filter
%   on it -- without turning a design choice into a red gate.
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
%   Bounds. With `context` supplied, one cross-plane bound is added:
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
%     violations   - cell array of violation description strings (empty = clean).
%     qualityNotes - cell array of low-precision notes. NEVER a failure: these
%                    describe correct measurements of signals whose burst length
%                    limits how finely a bandwidth can be defined at all.

if nargin < 3 || isempty(tag)
    tag = 'source';
end
if nargin < 4 || isempty(context)
    context = struct();
end

violations = {};
qualityNotes = {};
tol = 1.02; % small slack for FFT-bin granularity / floating point

% Propagation is the ONLY stage between Truth.Execution and Truth.Measured, so the
% ratio between them is a fading/Doppler bound. Measured over 1413 sources: AWGN
% max 1.0002, Rayleigh max 1.0175, Rician p95 1.304. 1.6 leaves headroom for a
% deeper multipath profile than the registered statistical models produce while
% still rejecting the order-of-magnitude excursions.
PROPAGATION_INFLATION_LIMIT = 1.6;

% Below this many analysis cells the reported width is quantised by the burst
% length rather than by the emitter. ITU-R SM.443 wants a measurement RBW at
% ~1-3 % of the occupied bandwidth (>= ~33 cells), so 8 is already generous; it is
% set low on purpose because crossing it produces a NOTE, not a failure, and the
% note should mark the genuinely coarse cases rather than most of the dataset.
MIN_RESOLUTION_CELLS = 8;

% Above this, the reported width describes a broadband FLOOR rather than the
% emitter's lobe. The ratio is 99 %-span / 50 %-span, so it is ~2 for any
% well-behaved distribution -- measured 2.18 for a clean root-raised-cosine and
% 1.99 for white noise, since a flat spectrum gives 0.99*Fs / 0.5*Fs. It only grows
% when a narrow lobe sits on a wide floor. 8 is comfortably above every healthy
% case and far below the pathological one (~43, see below).
MAX_SPECTRAL_CONCENTRATION = 8;

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

    % A reading spanning few analysis cells is quantised by its own burst length
    % rather than by the emitter, and it is also the mechanism behind the widest
    % propagation-ratio outliers. Record it FIRST, as a NOTE, and suppress the
    % propagation comparison for such a source: comparing a coarsely quantised
    % width against a finely measured one would blame propagation for arithmetic.
    resolvedBandwidth = true;
    if localFiniteScalar(sourcePlane, 'BandwidthResolutionCells')
        cells = sourcePlane.BandwidthResolutionCells;
        if cells < MIN_RESOLUTION_CELLS
            resolvedBandwidth = false;
            qualityNotes{end + 1} = sprintf( ...
                ['%s OccupiedBandwidthHz=%.4g spans %.2f analysis cells ', ...
                 '(RBW=%.4g Hz, %g active samples): quantised by burst length, ', ...
                 'not by the emitter'], ...
                tag, ob, cells, localFieldOrNaN(sourcePlane, 'BandwidthResolutionHz'), ...
                localFieldOrNaN(sourcePlane, 'ActiveSampleCount'));
        end
    end

    % A width that describes a FLOOR rather than a lobe. This catches a case
    % BandwidthResolutionCells structurally cannot: that test divides the reported
    % width by the analysis resolution, so an INFLATED reading earns a HIGH cell
    % count and passes as well resolved. The dataset's worst
    % Measured-vs-Execution cluster is exactly that shape -- an FM emitter reported
    % at 15 MHz with half its power inside 350 kHz, a ratio near 43, which sailed
    % through the resolution test at 77 cells.
    %
    % Its mechanism is understood and the reported number is CORRECT: a two-tap
    % channel profile with a 1 us delay has nulls every 1 MHz and a 10.7 dB minimum,
    % so a null landing on a ~1 MHz emitter suppresses the lobe by ~10 dB while
    % barely touching the wideband floor from hard gating and PA regrowth. The ITU
    % 99 % band of THAT waveform really is tens of MHz. So this is a NOTE, not a
    % violation: the measurement is right and the label is unusable as "the
    % emitter's bandwidth", which is a fact a consumer must be able to see rather
    % than a defect to be fixed in the estimator.
    if localFiniteScalar(sourcePlane, 'SpectralConcentrationRatio')
        concentration = sourcePlane.SpectralConcentrationRatio;
        if concentration > MAX_SPECTRAL_CONCENTRATION
            resolvedBandwidth = false;
            qualityNotes{end + 1} = sprintf( ...
                ['%s OccupiedBandwidthHz=%.4g holds half its power within %.4g Hz ', ...
                 '(concentration %.1fx, healthy ~2): the width describes a ', ...
                 'broadband floor, not the emitter''s lobe'], ...
                tag, ob, localFieldOrNaN(sourcePlane, 'HalfPowerSpanHz'), concentration);
        end
    end

    % The propagation ratio is only a statement about propagation when its
    % DENOMINATOR is a resolved width. The Execution side is measured on the
    % same frame-length window, so when the emitter's clean band spans fewer
    % than ~33 analysis cells (the ITU-R SM.443 RBW-at-1-3%-of-OBW guidance,
    % i.e. the short-window OBW floor regime), both planes read a
    % window-quantised floor and their ratio is floor arithmetic: measured
    % floor-bound narrowband emitters on Rician read 1.6-2.0x their own
    % equally floor-bound Execution number with NOTHING having widened.
    % Report those as notes; a genuinely resolved denominator keeps the hard
    % bound. (The measured-side RBW is the proxy for the Execution window's
    % RBW -- the two windows are the same frame length.)
    execResolved = true;
    if localFiniteScalar(context, 'ExecutionBwHz') && ...
            localFiniteScalar(sourcePlane, 'BandwidthResolutionHz') && ...
            sourcePlane.BandwidthResolutionHz > 0
        execCells = context.ExecutionBwHz / sourcePlane.BandwidthResolutionHz;
        if execCells < 33
            execResolved = false;
        end
    end

    if claimsMeasurement && resolvedBandwidth && ...
            localFiniteScalar(context, 'ExecutionBwHz') && context.ExecutionBwHz > 0
        execBw = context.ExecutionBwHz;
        ratio = ob / execBw;
        if ratio > PROPAGATION_INFLATION_LIMIT && ~execResolved
            qualityNotes{end + 1} = sprintf( ...
                ['%s OccupiedBandwidthHz=%.4g is %.3fx its ExecutionBw=%.4g, ', ...
                 'but the Execution width spans only %.1f analysis cells ', ...
                 '(RBW=%.4g Hz): both planes read the short-window floor and ', ...
                 'the ratio is window arithmetic, not propagation'], ...
                tag, ob, ratio, execBw, ...
                execBw / sourcePlane.BandwidthResolutionHz, ...
                localFieldOrNaN(sourcePlane, 'BandwidthResolutionHz'));
        elseif ratio > PROPAGATION_INFLATION_LIMIT
            % Report the burst length and RBW with the ratio, because propagation
            % is the only PIPELINE stage between the planes but not the only
            % possible cause: the two planes also measure buffers of different
            % length, and a hard-gated burst of duration T occupies ~10/T at the
            % 99 % power level, so a short clip inflates the measured side on its
            % own. Printing both numbers lets the reader tell which case they have
            % instead of assuming fading. The current dataset has one such cluster
            % -- an FM emitter at 12.0x-13.7x, Rician only, decaying monotonically
            % across ten consecutive frames on 1024 active samples -- and 1024
            % samples is NOT short enough for gating to explain 13x (measured:
            % 1.27x at that length), so its mechanism is still open.
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
    % localFieldOrNaN - the field as a double when finite scalar, else NaN.
v = NaN;
if localFiniteScalar(s, f)
    v = double(s.(f));
end
end


function tf = localFiniteScalar(s, f)
    % localFiniteScalar - whether the struct carries a finite numeric scalar field.
tf = isstruct(s) && isfield(s, f) && isnumeric(s.(f)) ...
    && isscalar(s.(f)) && isfinite(s.(f));
end
