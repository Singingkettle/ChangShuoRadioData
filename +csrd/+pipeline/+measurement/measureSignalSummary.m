function summary = measureSignalSummary(signal, sampleRate, observableBwHz, varargin)
%MEASURESIGNALSUMMARY Compute receiver-view measurements in one pass.
% 中文说明：一次完成 OBW、频谱质心、包络和频率占用测量，减少重复校验和数据整理。

if nargin < 3 || isempty(observableBwHz)
    observableBwHz = NaN;
end

p = inputParser();
p.FunctionName = 'measureSignalSummary';
p.CaseSensitive = false;
addParameter(p, 'Percentage', 99, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0 && x <= 100);
addParameter(p, 'PeakRelativeDb', -3, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x < 0);
addParameter(p, 'EnvelopeOptions', struct(), @(x) isempty(x) || isstruct(x));
parse(p, varargin{:});

signalCol = localValidateAndCollapse(signal, sampleRate);
sampleRate = double(sampleRate);

summary = struct();
summary.OccupiedBandwidthHz = localPeakRelativeObw( ...
    signalCol, sampleRate, double(p.Results.Percentage), ...
    double(p.Results.PeakRelativeDb));
summary.CenterFrequencyHz = localSpectrumCentroid(signalCol, sampleRate);
envInfo = localDetectEnvelope(signalCol, sampleRate, p.Results.EnvelopeOptions);
summary.TimeOccupancy = envInfo.TimeOccupancy;
summary.Envelope = envInfo;
if isfinite(observableBwHz)
    summary.FrequencyOccupancy = csrd.pipeline.measurement.frequencyOccupancy( ...
        summary.OccupiedBandwidthHz, double(observableBwHz));
else
    summary.FrequencyOccupancy = NaN;
end
summary.MeasurementStatus = 'Measured';
summary.MeasurementSemantics = '';
end

function signalCol = localValidateAndCollapse(signal, sampleRate)
if isempty(signal)
    error('CSRD:Measurement:EmptySignal', ...
        'measureSignalSummary: input signal is empty.');
end
if ~isnumeric(sampleRate) || ~isscalar(sampleRate) || ...
        ~isfinite(sampleRate) || sampleRate <= 0
    error('CSRD:Measurement:InvalidSampleRate', ...
        'measureSignalSummary: sampleRate must be positive finite scalar.');
end
if any(~isfinite(signal(:)))
    error('CSRD:Measurement:InvalidSignal', ...
        'measureSignalSummary: signal contains NaN or Inf.');
end
if size(signal, 2) > 1
    signalCol = sum(signal, 2);
else
    signalCol = signal(:);
end
end

function bwHz = localPeakRelativeObw(signalCol, sampleRate, pct, peakRelDb)
N = length(signalCol);
if N < 8
    spec = abs(fftshift(fft(double(signalCol)))).^2;
    fAxis = ((0:N-1)' - floor(N/2)) * (sampleRate / N);
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

if isempty(spec) || sum(spec) <= 0
    bwHz = 0;
    return;
end
peakVal = max(spec);
if peakVal <= 0
    bwHz = 0;
    return;
end

threshold = peakVal * 10^(peakRelDb / 10);
denoised = spec;
denoised(denoised < threshold) = 0;

totalEnergy = sum(denoised);
if totalEnergy <= 0
    bwHz = 0;
    return;
end

targetMass = totalEnergy * (pct / 100);
nBins = numel(denoised);
cumEnergy = cumsum(denoised);
bestSpan = nBins;
lBest = 1;
rBest = nBins;
rIdx = 1;
for lIdx = 1:nBins
    if rIdx < lIdx
        rIdx = lIdx;
    end
    while rIdx < nBins && localRangeMass(cumEnergy, lIdx, rIdx) < targetMass
        rIdx = rIdx + 1;
    end
    if localRangeMass(cumEnergy, lIdx, rIdx) >= targetMass
        span = rIdx - lIdx + 1;
        if span < bestSpan
            bestSpan = span;
            lBest = lIdx;
            rBest = rIdx;
        end
    end
end

if nBins == 1
    bwHz = sampleRate;
else
    binWidth = median(diff(fAxis));
    bwHz = max(0, (fAxis(rBest) - fAxis(lBest)) + abs(binWidth));
end
end

function mass = localRangeMass(cumEnergy, lIdx, rIdx)
if lIdx <= 1
    mass = cumEnergy(rIdx);
else
    mass = cumEnergy(rIdx) - cumEnergy(lIdx - 1);
end
end

function fcHz = localSpectrumCentroid(signalCol, sampleRate)
N = length(signalCol);
spec = fftshift(fft(double(signalCol)));
psd = abs(spec) .^ 2;
totalPower = sum(psd);
if totalPower <= 0
    fcHz = 0;
    return;
end
fAxis = ((0:N - 1)' - floor(N / 2)) * (sampleRate / N);
fcHz = sum(fAxis .* psd) / totalPower;
end

function info = localDetectEnvelope(signalCol, sampleRate, options)
if nargin < 3 || isempty(options)
    options = struct();
end
useDefaultWindow = ~isfield(options, 'WindowSec') || isempty(options.WindowSec);
if ~isfield(options, 'ThresholdDb') || isempty(options.ThresholdDb)
    options.ThresholdDb = -20;
end

totalDurationSec = length(signalCol) / sampleRate;
if useDefaultWindow
    options.WindowSec = min(1e-4, totalDurationSec);
end
if options.WindowSec <= 0 || options.WindowSec > totalDurationSec
    error('CSRD:Measurement:InvalidWindow', ...
        ['measureSignalSummary envelope: WindowSec=%g must be in ', ...
         '(0, total=%.6g] s.'], options.WindowSec, totalDurationSec);
end

windowSamples = max(1, round(options.WindowSec * sampleRate));
numWindows = floor(length(signalCol) / windowSamples);
if numWindows == 0
    info = localEmptyEnvelope(options);
    return;
end

trimmed = signalCol(1:(numWindows * windowSamples));
powerMatrix = reshape(abs(trimmed) .^ 2, windowSamples, numWindows);
powerPerWindow = mean(powerMatrix, 1).';

peakPower = max(powerPerWindow);
if peakPower <= 0
    info = localEmptyEnvelope(options);
    return;
end
thresholdLinear = peakPower * 10^(options.ThresholdDb / 10);
onMask = powerPerWindow >= thresholdLinear;

edges = diff([false; onMask; false]);
burstStartIdx = find(edges == 1);
burstStopIdx  = find(edges == -1) - 1;
info = struct( ...
    'TimeOccupancy', sum(onMask) / numWindows, ...
    'NumBursts', length(burstStartIdx), ...
    'BurstStartSec', ((burstStartIdx - 1) * windowSamples / sampleRate).', ...
    'BurstStopSec', (burstStopIdx * windowSamples / sampleRate).', ...
    'WindowSec', options.WindowSec, ...
    'ThresholdDb', options.ThresholdDb);
end

function info = localEmptyEnvelope(options)
info = struct( ...
    'TimeOccupancy', 0, ...
    'NumBursts', 0, ...
    'BurstStartSec', zeros(1, 0), ...
    'BurstStopSec', zeros(1, 0), ...
    'WindowSec', options.WindowSec, ...
    'ThresholdDb', options.ThresholdDb);
end
