function [bwHz, info] = occupiedBandwidthCore(signalCol, sampleRate, pct)
%OCCUPIEDBANDWIDTHCORE ITU-R SM.328 occupied bandwidth on a prepared spectrum.
% Inputs: see signature arguments and local validation.
% Outputs: see signature return values and contract fields.
%
% DEFINITION (this is the quantity the field name OccupiedBandwidthHz promises)
%   ITU-R SM.328 / Radio Regulations No. 1.153: the width of the frequency band
%   such that below the lower and above the upper limit the mean powers emitted
%   are each equal to a specified percentage beta/2 of the total mean power.
%   Unless stated otherwise beta/2 = 0.5 %, i.e. the band holds 99 % of the mean
%   power. So `pct` = 99 excludes 0.5 % at each edge.
%
% WHY THIS REPLACED THE PEAK-RELATIVE ESTIMATOR
%   The former kernel clipped at -3 dBc and then took the narrowest contiguous
%   band holding 99 % of the SURVIVING energy. That is a different quantity:
%   ITU-R SM.443 requires x ~ 26 dB for an x-dB-down width to approximate OBW, and
%   at x = 3 dB the result is the main-lobe footprint. For a root-raised-cosine
%   signal that footprint is ~1.0*Rs REGARDLESS OF ROLL-OFF -- measured at
%   0.897 / 0.901 / 0.803 Rs for beta = 0.1 / 0.25 / 0.5 while the true occupied
%   bandwidth rises 1.027 -> 1.096 -> 1.266 Rs. The old label was therefore
%   effectively the baud rate and was blind to a parameter it was meant to
%   reflect.
%
%   The peak-relative form existed for exactly one reason: a power-integral
%   definition is unusable on a NOISY waveform, because the noise contributes
%   power across the whole band (obw() returns 7.13*Rs at 10 dB SNR). The
%   measurement now runs before noise injection, so that reason is gone -- and
%   with it the collapse guard, the blueprint prior window and the window growth
%   loop, all of which were noise-robustness scaffolding rather than definitional
%   choices. ECC/REC/(06)01 states the same limit from the metrology side: 99 %
%   OBW measurement requires the peak at least 30 dB above the noise floor, so on
%   a noisy buffer at the bottom of our SNR range the quantity is not imprecise,
%   it is undefined.
%
% WHY THE INTEGRAL LIVES HERE RATHER THAN DELEGATING TO obw()
%   obw() implements the same definition and agrees with the analytic RRC result
%   to 0.64 %, but it has no equivalent of this kernel's spectrum preparation, and
%   four contracts depend on that preparation:
%     - the +/-Fs/2 circular recentre, without which an emitter placed near the
%       band edge is inflated (our emitters do sit near the edge);
%     - the whole-signal periodogram fallback for a burst that lands inside the
%       trailing segment Welch's method discards;
%     - a one-sample impulse occupying the full observable band;
%     - an all-zero buffer reporting zero rather than a fabricated width.
%   Reusing the preparation and replacing only the threshold rule keeps all four.
%
% Inputs:
%   signalCol  - complex column vector; antenna handling is the caller's
%                responsibility (the GT is measured per emitter and per antenna,
%                never on an antenna sum, because summed antennas report the
%                interference pattern between independently faded copies rather
%                than the emitter's own occupied bandwidth).
%   sampleRate - positive finite scalar (Hz).
%   pct        - power percentage inside the band, in (0, 100]. Default 99.
%
% Outputs:
%   bwHz - occupied bandwidth in Hz (>= 0). Zero means the buffer carried no
%          power at all; callers surface that as an explicit measurement failure
%          rather than propagating Nyquist.
%   info - diagnostics: .LowerEdgeHz / .UpperEdgeHz (on the analysis axis, which
%          for an edge-straddling emitter is the recentred one), .TotalPowerW,
%          .SpectrumSource ('pwelch' | 'periodogram'), .BandwidthDefinition and
%          .BandwidthEstimator. The last two travel with the value because a bare
%          number is not a sufficient specification of a measured quantity
%          (JCGM 200:2012 VIM 2.3).
%
% See also: csrd.pipeline.measurement.obwActual
%           csrd.pipeline.measurement.measureSignalSummary

if nargin < 3 || isempty(pct)
    pct = 99;
end

info = struct( ...
    'LowerEdgeHz', NaN, ...
    'UpperEdgeHz', NaN, ...
    'TotalPowerW', 0, ...
    'SpectrumSource', 'pwelch', ...
    'ResolutionBandwidthHz', NaN, ...
    'ActiveSampleCount', 0, ...
    'BandwidthDefinition', ...
        csrd.pipeline.measurement.bandwidthDefinitionString(pct), ...
    'BandwidthEstimator', 'csrd.pipeline.measurement.occupiedBandwidthCore');

N = length(signalCol);
% The count of samples that actually carry energy, which is what sets this
% measurement's resolution. A burst gated into a long frame has N samples of span
% but only a few of content, and a hard-gated burst of duration T genuinely
% spreads to ~10/T at the 99 % level -- so this number is not bookkeeping, it is
% the reason two identical bandwidth readings can mean entirely different things.
info.ActiveSampleCount = sum(abs(double(signalCol)) > 0);
if N < 8
    % Too short for pwelch's default 8-segment split; a single-segment
    % periodogram keeps short-signal semantics well defined.
    spec = abs(fftshift(fft(double(signalCol)))) .^ 2;
    fAxis = ((0:N - 1)' - floor(N / 2)) * (sampleRate / N);
    info.SpectrumSource = 'periodogram';
else
    winLen = max(64, 2 ^ floor(log2(N / 8)));
    if winLen >= N
        winLen = max(8, floor(N / 2));
    end
    overlap = floor(winLen / 2);
    nfft = max(256, 2 ^ nextpow2(winLen));
    [pxx, fAxis] = pwelch(double(signalCol), hamming(winLen), ...
        overlap, nfft, sampleRate, 'centered');
    spec = pxx(:);
    fAxis = fAxis(:);
end

% Welch's method discards the trailing partial segment. A short burst sitting
% entirely inside that tail yields an all-zero windowed estimate even though the
% buffer carries energy, which would report zero occupied bandwidth for a real
% emission. Fall back to a whole-signal periodogram so every sample counts.
if (isempty(spec) || sum(spec) <= 0) && sum(abs(double(signalCol)) .^ 2) > 0
    spec = abs(fftshift(fft(double(signalCol)))) .^ 2;
    fAxis = ((0:N - 1)' - floor(N / 2)) * (sampleRate / N);
    info.SpectrumSource = 'periodogram';
end

if isempty(spec) || sum(spec) <= 0
    bwHz = 0;
    return;
end

% Recentre a band that wraps the +/-Fs/2 Nyquist edge. The occupied bandwidth is
% a SPAN and a span is invariant under a circular shift, so nothing is added back
% -- but without the shift the cumulative-power walk would start inside the
% emitter and place the 0.5 % edges on the wrong side of the wrap, inflating the
% result toward Fs for an edge-placed emitter.
spec = csrd.pipeline.measurement.circularRecenterSpectrum(spec, sampleRate);

nBins = numel(spec);
if nBins == 1
    % A single spectral bin means a single nonzero sample, i.e. an impulse on the
    % sample grid. Its discrete spectrum occupies the full observable Nyquist
    % span.
    bwHz = sampleRate;
    info.TotalPowerW = sum(spec);
    info.LowerEdgeHz = fAxis(1);
    info.UpperEdgeHz = fAxis(1);
    info.ResolutionBandwidthHz = sampleRate;
    return;
end

totalPower = sum(spec);
info.TotalPowerW = totalPower;

% ITU definition: exclude (100 - pct)/2 of the mean power at EACH edge. The
% cumulative walk is interpolated within the crossing bin so the answer is not
% quantised to the analysis grid -- that sub-bin refinement is what brings this
% within a fraction of a percent of the analytic result.
excludedFraction = (100 - pct) / 200;
lowerTarget = excludedFraction * totalPower;
upperTarget = (1 - excludedFraction) * totalPower;

cumPower = cumsum(spec);
binWidthHz = abs(median(diff(fAxis)));
% The resolution this answer was actually produced at. Two limits apply and the
% COARSER one wins:
%   - the analysis grid, binWidthHz;
%   - Fs / ActiveSampleCount, the resolution the burst length can support.
% The second matters because a burst gated into a long frame gets a fine analysis
% grid it has not earned: zero padding interpolates a spectrum, it never adds
% information. Reporting only binWidthHz would claim a 64-sample burst was
% measured at the same resolution as a 32768-sample one.
%
% ITU-R SM.443 puts a usable measurement RBW at roughly 1-3 % of the occupied
% bandwidth, so publishing the RBW beside the width lets a consumer apply that test
% instead of trusting every reading equally. VIM 2.3: a measured value without its
% conditions is not a sufficient specification of the quantity.
burstResolutionHz = Inf;
if info.ActiveSampleCount > 0
    burstResolutionHz = sampleRate / double(info.ActiveSampleCount);
end
info.ResolutionBandwidthHz = max(binWidthHz, min(burstResolutionHz, sampleRate));

lowerEdgeHz = localInterpolatedCrossing(cumPower, fAxis, lowerTarget, binWidthHz);
upperEdgeHz = localInterpolatedCrossing(cumPower, fAxis, upperTarget, binWidthHz);

info.LowerEdgeHz = lowerEdgeHz;
info.UpperEdgeHz = upperEdgeHz;
bwHz = max(0, upperEdgeHz - lowerEdgeHz);
end

function edgeHz = localInterpolatedCrossing(cumPower, fAxis, target, binWidthHz)
    % localInterpolatedCrossing - frequency at which the cumulative power first
    % reaches `target`, interpolated inside the crossing bin.
    % Inputs: cumPower - cumulative spectrum; fAxis - matching frequency axis;
    %         target - cumulative power level to locate; binWidthHz - analysis bin
    %         width, used to place the edge at the bin's leading boundary.
    % Outputs: edgeHz - the interpolated crossing frequency (Hz).
    %
    % Each bin is treated as holding its power uniformly across its width, so the
    % crossing lands a fractional bin into the bin that contains it. Without this
    % the edges snap to the grid and a narrowband emitter measured on a coarse
    % analysis grid picks up a full bin of quantisation error at each edge.
    idx = find(cumPower >= target, 1, 'first');
    if isempty(idx)
        edgeHz = fAxis(end);
        return;
    end
    if idx == 1
        priorPower = 0;
    else
        priorPower = cumPower(idx - 1);
    end
    binPower = cumPower(idx) - priorPower;
    if binPower > 0
        fractionIntoBin = (target - priorPower) / binPower;
    else
        fractionIntoBin = 0;
    end
    fractionIntoBin = min(1, max(0, fractionIntoBin));
    % fAxis(idx) is the bin centre, so the bin spans +/- binWidthHz/2 around it.
    edgeHz = fAxis(idx) - binWidthHz / 2 + fractionIntoBin * binWidthHz;
end
