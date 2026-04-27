function diag_phase4_rrc_obw()
%DIAG_PHASE4_RRC_OBW Probe obwActual on RRC-shaped PSK and OFDM signals
%   to understand how the rolloff sidelobes interact with denoising.

rng(42);

% --- 1. RRC-shaped QPSK ---
sps = 4;
nSym = 2048;
beta = 0.35;
fs = 50e6;
Rs = 5e6;     % symbol rate -> raw BW = (1+beta)*Rs = 6.75 MHz
sps = round(fs / Rs);
fs = sps * Rs;
sym = (2*randi([0,1], nSym, 1) - 1) + 1j * (2*randi([0,1], nSym, 1) - 1);
sym = sym / sqrt(2);
% RRC pulse shaping: rcosdesign + filter
h = rcosdesign(beta, 16, sps, 'sqrt');
upsampled = zeros(nSym * sps, 1);
upsampled(1:sps:end) = sym;
sigClean = filter(h, 1, upsampled);
sigClean = sigClean / std(sigClean);

snrSweep = [6, 9, 12, 15, 20];
fprintf('--- RRC QPSK (beta=%.2f, Rs=%.1f MHz, fs=%.1f MHz) ---\n', ...
    beta, Rs/1e6, fs/1e6);
fprintf('%-7s  %-12s  %-12s  %-12s  %-7s\n', 'SNR', 'Clean OBW', 'Noisy OBW', 'AnalyticBW', 'rel');
analyticBw = (1 + beta) * Rs;
for snrDb = snrSweep
    sigPow = mean(abs(sigClean).^2);
    inBandFraction = analyticBw / fs;
    noiseFullBand = sigPow / 10^(snrDb / 10) / inBandFraction;
    n = sqrt(noiseFullBand / 2) * (randn(numel(sigClean), 1) + 1i * randn(numel(sigClean), 1));
    sigNoisy = sigClean + n;
    a  = peakOnlyObw(sigClean, fs, -3);
    b  = peakOnlyObw(sigNoisy, fs, -3);
    a2 = peakOnlyObw(sigClean, fs, -6);
    b2 = peakOnlyObw(sigNoisy, fs, -6);
    a3 = peakOnlyObw(sigClean, fs, -10);
    b3 = peakOnlyObw(sigNoisy, fs, -10);
    fprintf('%-7.1f  -3dBc cl=%.0f no=%.0f r=%.3f | -6dBc cl=%.0f no=%.0f r=%.3f | -10dBc cl=%.0f no=%.0f r=%.3f\n', ...
        snrDb, a, b, b/a, a2, b2, b2/a2, a3, b3, b3/a3);
end

% --- 2. OFDM ---
fprintf('\n--- OFDM (1024 active SC, 1.4 MHz signal in fs=50 MHz) ---\n');
nFFT = 2048;
nActive = 1024;
nSym = 64;
mapping = false(nFFT, 1);
mapping((1+nFFT/2-nActive/2):(nFFT/2+nActive/2)) = true;
ofdmSig = [];
for k = 1:nSym
    X = zeros(nFFT, 1);
    X(mapping) = (2*randi([0,1], nActive, 1) - 1) + 1j * (2*randi([0,1], nActive, 1) - 1);
    X = ifftshift(X);
    x = ifft(X) * sqrt(nFFT);
    ofdmSig = [ofdmSig; x];  %#ok<AGROW>
end
fs = 50e6;
sigClean = ofdmSig / std(ofdmSig);
analyticBw = nActive * (fs / nFFT);
fprintf('%-7s  %-12s  %-12s  %-12s  %-7s\n', 'SNR', 'Clean OBW', 'Noisy OBW', 'AnalyticBW', 'rel');
for snrDb = snrSweep
    sigPow = mean(abs(sigClean).^2);
    inBandFraction = analyticBw / fs;
    noiseFullBand = sigPow / 10^(snrDb / 10) / inBandFraction;
    n = sqrt(noiseFullBand / 2) * (randn(numel(sigClean), 1) + 1i * randn(numel(sigClean), 1));
    sigNoisy = sigClean + n;
    a  = peakOnlyObw(sigClean, fs, -3);
    b  = peakOnlyObw(sigNoisy, fs, -3);
    a2 = peakOnlyObw(sigClean, fs, -6);
    b2 = peakOnlyObw(sigNoisy, fs, -6);
    a3 = peakOnlyObw(sigClean, fs, -10);
    b3 = peakOnlyObw(sigNoisy, fs, -10);
    fprintf('%-7.1f  -3dBc cl=%.0f no=%.0f r=%.3f | -6dBc cl=%.0f no=%.0f r=%.3f | -10dBc cl=%.0f no=%.0f r=%.3f\n', ...
        snrDb, a, b, b/a, a2, b2, b2/a2, a3, b3, b3/a3);
end
end


function bw = peakOnlyObw(sig, fs, dbcRel)
sig = double(sig(:));
N = numel(sig);
winLen = max(64, 2^floor(log2(N / 8)));
if winLen >= N, winLen = max(8, floor(N/2)); end
overlap = floor(winLen / 2);
nfft = max(256, 2 ^ nextpow2(winLen));
[pxx, fAxis] = pwelch(sig, hamming(winLen), overlap, nfft, fs, 'centered');
spec = pxx(:);
fAxis = fAxis(:);
peakVal = max(spec);
threshold = peakVal * 10^(dbcRel / 10);
denoised = spec;
denoised(denoised < threshold) = 0;
totalEnergy = sum(denoised);
if totalEnergy <= 0, bw = 0; return; end
targetMass = totalEnergy * 0.99;
nBins = numel(denoised);
cumEnergy = cumsum(denoised);
bestSpan = nBins;
lBest = 1; rBest = nBins; rIdx = 1;
for lIdx = 1:nBins
    if rIdx < lIdx, rIdx = lIdx; end
    while rIdx < nBins
        spanEnergy = cumEnergy(rIdx) - cumEnergy(lIdx) + denoised(lIdx);
        if spanEnergy >= targetMass, break; end
        rIdx = rIdx + 1;
    end
    spanEnergy = cumEnergy(rIdx) - cumEnergy(lIdx) + denoised(lIdx);
    if spanEnergy >= targetMass
        span = rIdx - lIdx + 1;
        if span < bestSpan, bestSpan = span; lBest = lIdx; rBest = rIdx; end
    end
end
binWidth = mean(diff(fAxis));
bw = double((rBest - lBest + 1) * binWidth);
end
