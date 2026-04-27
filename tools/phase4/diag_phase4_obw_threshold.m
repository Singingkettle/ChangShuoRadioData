function diag_phase4_obw_threshold()
%DIAG_PHASE4_OBW_THRESHOLD Compare OBW estimators on a known band-limited
%   noisy signal at SNR=10 dB.

snrSweep   = [6, 9, 15, 30];
ratioSweep = [0.05, 0.10, 0.25, 0.50, 0.70, 0.85, 0.95];
fsHigh = 50e6;
N      = 2^15;
configs = struct( ...
    'name',   {'pct25_x5', 'pct10_x5',  'pct10_x10'}, ...
    'pct',    {25,         10,           10}, ...
    'margin', {5.0,        5.0,          10.0});

for c = 1:numel(configs)
    cfg = configs(c);
    fprintf('\n=== %s (pct=%d, margin=%.1f) =====================\n', ...
        cfg.name, cfg.pct, cfg.margin);
    for snrDb = snrSweep
        fprintf('  SNR=%4.1f  ', snrDb);
        for ratio = ratioSweep
            [a, b, t] = probeOnce(N, fsHigh, ratio, snrDb, cfg.margin, cfg.pct, 42);
            if a > 0
                fprintf(' r=%.2f cl=%.2f no=%.2f r=%.2f |', ratio, a/t, b/t, b/a);
            else
                fprintf(' r=%.2f FAIL                |', ratio);
            end
        end
        fprintf('\n');
    end
end
end


function [bwClean, bwNoisy, trueBwHz] = probeOnce(N, fs, ratio, snrDb, margin, pct, seed)
rng(seed);
trueBwHz = ratio * fs;
x = randn(N, 1) + 1i * randn(N, 1);
X = fftshift(fft(x));
freqs = linspace(-fs/2, fs/2, N).';
mask  = abs(freqs) <= trueBwHz / 2;
X = X .* mask;
sigClean = ifft(ifftshift(X));
sigClean = sigClean / std(sigClean);

sigPow = mean(abs(sigClean).^2);
inBandFraction = trueBwHz / fs;
noiseFullBand = sigPow / 10^(snrDb / 10) / inBandFraction;
noise = sqrt(noiseFullBand / 2) * ...
    (randn(N, 1) + 1i * randn(N, 1));
sigNoisy = sigClean + noise;

bwClean = percentileFloor(sigClean, fs, pct, margin);
bwNoisy = percentileFloor(sigNoisy, fs, pct, margin);
end


function bw = percentileFloor(sig, fs, floorPct, margin)
[spec, fAxis] = computePsd(sig, fs);
floorVal = prctile(spec, floorPct);
threshold = floorVal * margin;
bw = obwFromMaskedSpec(spec, fAxis, threshold);
end


function bw = peakRelativeDbc(sig, fs, dbcRel)
[spec, fAxis] = computePsd(sig, fs);
peakVal = max(spec);
threshold = peakVal * 10^(dbcRel / 10);
bw = obwFromMaskedSpec(spec, fAxis, threshold);
end


function bw = hybridPeakFloor(sig, fs, dbcRel, floorPct, margin)
[spec, fAxis] = computePsd(sig, fs);
peakVal = max(spec);
peakThr = peakVal * 10^(dbcRel / 10);
floorVal = prctile(spec, floorPct);
floorThr = floorVal * margin;
threshold = max(peakThr, floorThr);
bw = obwFromMaskedSpec(spec, fAxis, threshold);
end


function [spec, fAxis] = computePsd(sig, fs)
sig = double(sig(:));
N = numel(sig);
winLen = max(64, 2^floor(log2(N / 8)));
if winLen >= N
    winLen = max(8, floor(N / 2));
end
overlap = floor(winLen / 2);
nfft = max(256, 2 ^ nextpow2(winLen));
[pxx, fAxis] = pwelch(sig, hamming(winLen), overlap, nfft, fs, 'centered');
spec = pxx(:);
fAxis = fAxis(:);
end


function bw = obwFromMaskedSpec(spec, fAxis, threshold)
denoised = spec;
denoised(denoised < threshold) = 0;
totalEnergy = sum(denoised);
if totalEnergy <= 0
    bw = 0;
    return;
end
targetMass = totalEnergy * 0.99;
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
    while rIdx < nBins
        spanEnergy = cumEnergy(rIdx) - cumEnergy(lIdx) + denoised(lIdx);
        if spanEnergy >= targetMass
            break;
        end
        rIdx = rIdx + 1;
    end
    spanEnergy = cumEnergy(rIdx) - cumEnergy(lIdx) + denoised(lIdx);
    if spanEnergy >= targetMass
        span = rIdx - lIdx + 1;
        if span < bestSpan
            bestSpan = span;
            lBest = lIdx;
            rBest = rIdx;
        end
    end
end
binWidth = mean(diff(fAxis));
bw = double((rBest - lBest + 1) * binWidth);
end
