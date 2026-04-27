function diag_phase4_obw_invariance()
%DIAG_PHASE4_OBW_INVARIANCE Probe whether obwActual depends on the
%   sample rate at which the same band-limited signal is observed.
%
%   This is the working hypothesis behind the C8 outliers: pre-channel
%   ModulatedBandwidthHz is measured at the modulator's native fs, but
%   post-channel SourcePlane.OccupiedBandwidthHz is measured at the
%   receiver's fs. Same algorithm, same signal envelope, different fs
%   -> different OBW.

addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), '..'));

rng(42);

modBwHz   = 5e6;
fsLow     = 12.5e6;
fsHigh    = 50e6;
N         = 2^14;

t = (0:N-1)' / fsLow;
% Synthesize a 5 MHz wide complex baseband signal: a band-limited Gaussian
% multiplied by a rectangular window.  Use FFT-based filtering for cleanliness.
x = randn(N, 1) + 1i * randn(N, 1);
X = fftshift(fft(x));
freqs = linspace(-fsLow/2, fsLow/2, N).';
mask = abs(freqs) <= modBwHz / 2;
X = X .* mask;
sigLow = ifft(ifftshift(X));
sigLow = sigLow / std(sigLow);

[P, Q] = rat(fsHigh / fsLow, 1e-6);
sigHigh = resample(sigLow, P, Q);

snrDb = 10;
sigPow = mean(abs(sigHigh).^2);
% AppliedSNRdB is in-band SNR.  Noise is full-band white at fsHigh; in-band
% noise power = total noise power * (modBw / fsHigh).
inBandFraction = modBwHz / fsHigh;
noiseFullBand = sigPow / 10^(snrDb / 10) / inBandFraction;
noise = sqrt(noiseFullBand / 2) * (randn(numel(sigHigh), 1) + 1i * randn(numel(sigHigh), 1));
sigHighNoisy = sigHigh + noise;

bwCleanLow   = csrd.utils.measurement.obwActual(sigLow,       fsLow);
bwCleanHigh  = csrd.utils.measurement.obwActual(sigHigh,      fsHigh);
bwNoisyHigh  = csrd.utils.measurement.obwActual(sigHighNoisy, fsHigh);

fprintf('OBW invariance probe (true band-limit = %.0f Hz, in-band SNR = %.1f dB):\n', ...
    modBwHz, snrDb);
fprintf('  obwActual(clean, fs=%.0f)  = %.0f Hz\n', fsLow,  bwCleanLow);
fprintf('  obwActual(clean, fs=%.0f)  = %.0f Hz\n', fsHigh, bwCleanHigh);
fprintf('  obwActual(noisy, fs=%.0f)  = %.0f Hz\n', fsHigh, bwNoisyHigh);
fprintf('  Clean low vs high  ratio   = %.3f\n', bwCleanHigh / bwCleanLow);
fprintf('  Noisy high vs clean ratio  = %.3f\n', bwNoisyHigh / bwCleanHigh);
fprintf('  Noisy high vs clean low    = %.3f (this drives C8)\n', bwNoisyHigh / bwCleanLow);
end
