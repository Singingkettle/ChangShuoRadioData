function [psd, fShiftHz] = circularRecenterSpectrum(psd, sampleRate)
%CIRCULARRECENTERSPECTRUM Circularly recentre a wrapped emitter band.
% Inputs: see signature arguments and local validation.
% Outputs: see signature return values and contract fields.
%
% The complex-baseband emitter placement (frequencyTranslate by a per-emitter
% offset at the receiver sample rate) is a CIRCULAR frequency shift, so any
% realized spectral content pushed past +/-Fs/2 wraps to the opposite Nyquist
% edge. The downstream OBW span search and spectral centroid are LINEAR (they
% walk an ascending frequency axis), so a band split across the two extremes
% is mis-measured: the contiguous-span search bridges the empty middle and
% inflates the OBW toward Fs, and the energy-weighted centroid of the two
% split lobes collapses toward baseband.
%
% This helper finds the energy-weighted CIRCULAR mean of the (periodic) power
% spectrum and circularly shifts the band to the centre bin, so the linear
% estimators see one contiguous band. The occupied-bandwidth SPAN is invariant
% under the shift (callers add nothing back). A centroid measured on the
% shifted spectrum must add back `fShiftHz` to recover the absolute centre.
%
% Inputs:
%   psd         : column vector, two-sided power spectrum over [-Fs/2, Fs/2)
%                 (fftshift/'centered' order), non-negative.
%   sampleRate  : positive scalar (Hz).
%
% Outputs:
%   psd         : the circularly shifted power spectrum (same length/order).
%   fShiftHz    : frequency (Hz) to ADD to a centroid measured on the shifted
%                 spectrum to recover the absolute centre. Zero when no shift
%                 was applied.
%
% See also: csrd.pipeline.measurement.obwActual,
%           csrd.pipeline.measurement.spectrumCentroid

    fShiftHz = 0;
    psd = psd(:);
    N = numel(psd);
    if N < 4
        return;
    end
    total = sum(psd);
    if ~(total > 0)
        return;
    end
    % Energy-weighted circular mean of the bin index (period N). Bin k maps to
    % angle 2*pi*k/N; the resultant's magnitude collapses to ~0 only when the
    % energy is spread around the whole circle (no localized band to recentre).
    k = (0:N - 1)';
    resultant = sum(psd .* exp(1i * 2 * pi * k / N));
    if abs(resultant) <= eps(total)
        return;
    end
    centroidBin = mod(angle(resultant) / (2 * pi) * N, N);
    zeroHzBin = floor(N / 2);   % index (0-based) of the 0 Hz bin in centered order
    shift = round(zeroHzBin - centroidBin);
    if shift == 0
        return;
    end
    psd = circshift(psd, shift);
    fShiftHz = -shift * (double(sampleRate) / N);
end
