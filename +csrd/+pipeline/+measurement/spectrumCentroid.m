function fcHz = spectrumCentroid(signal, sampleRate)
%SPECTRUMCENTROID Center-of-mass frequency (Hz) of |FFT(signal)|^2.
% Inputs: see signature arguments and local validation.
% Outputs: see signature return values and contract fields.
%
% Phase 4 §3.1 measurement helper. Computes the energy-weighted mean
% frequency over the two-sided spectrum [-Fs/2, Fs/2). For complex baseband
% signals this is the spectral centroid relative to baseband 0 Hz; the
% caller is responsible for shifting by the receiver's CenterFrequency to
% obtain absolute RF Hz.
%
% Inputs:
%   signal      : complex column vector (or [N x M]); multi-antenna is
%                 collapsed by sum across columns.
%   sampleRate  : positive scalar (Hz)
%
% Outputs:
%   fcHz        : scalar centroid (Hz) in [-Fs/2, Fs/2)
%
% Throws:
%   CSRD:Measurement:EmptySignal       - empty input
%   CSRD:Measurement:InvalidSampleRate - sampleRate <= 0 or non-finite
%   CSRD:Measurement:InvalidSignal     - signal contains NaN/Inf
%
% See also: csrd.pipeline.measurement.obwActual

    if isempty(signal)
        error('CSRD:Measurement:EmptySignal', ...
            'spectrumCentroid: input signal is empty.');
    end

    if ~isnumeric(sampleRate) || ~isscalar(sampleRate) || ...
            ~isfinite(sampleRate) || sampleRate <= 0
        error('CSRD:Measurement:InvalidSampleRate', ...
            'spectrumCentroid: sampleRate must be positive finite scalar (got %s).', ...
            mat2str(sampleRate));
    end

    if any(~isfinite(signal(:)))
        error('CSRD:Measurement:InvalidSignal', ...
            'spectrumCentroid: signal contains NaN or Inf.');
    end

    if size(signal, 2) > 1
        signalCol = sum(signal, 2);
    else
        signalCol = signal(:);
    end

    N = length(signalCol);
    spec = fftshift(fft(double(signalCol)));
    psd = abs(spec) .^ 2;
    fAxis = ((0:N - 1)' - floor(N / 2)) * (double(sampleRate) / N);
    % Smooth the raw periodogram to suppress per-bin noise variance before the
    % threshold/collapse logic, so the decision sees the signal's spectral
    % envelope rather than noise spikes (matches the pwelch-smoothed OBW
    % estimator). A box average preserves the energy-weighted mean.
    if N >= 256
        psd = movmean(psd, 2 * round(N / 512) + 1);   % odd window -> symmetric
    end
    % Float the integration threshold with the signal peak (matching the
    % peak-relative OBW estimator) so broadband AWGN -- symmetric about 0 Hz --
    % does not pull the measured center frequency toward baseband. Clipping
    % bins below peak*10^(-3/10) tracks the signal peak instead of the noise
    % floor; a clean single tone keeps its main lobe intact.
    peakVal = max(psd);
    if peakVal <= 0
        fcHz = 0;
        return;
    end
    % Collapse guard (mirrors obwActual / measureSignalSummary). When a
    % localized spectral spike sits a few dB above an otherwise-flat occupied
    % band, the peak-relative clip keeps only the spike and biases the centroid
    % toward it. If the peak-relative retained band is far narrower than a
    % noise-floor-relative band (25th-percentile floor + 6 dB, which keeps the
    % whole occupied band), integrate over the floor-relative band instead.
    peakThreshold = peakVal * 10 ^ (-3 / 10);
    floorThreshold = prctile(psd, 25) * 10 ^ (6 / 10);
    peakClipped = psd;
    peakClipped(peakClipped < peakThreshold) = 0;
    floorClipped = psd;
    floorClipped(floorClipped < floorThreshold) = 0;
    floorSpan = localEnergySpan(floorClipped, fAxis);
    if floorSpan > 0 && localEnergySpan(peakClipped, fAxis) < 0.3 * floorSpan
        psd = floorClipped;
    else
        psd = peakClipped;
    end
    totalPower = sum(psd);
    if totalPower <= 0
        fcHz = 0;
        return;
    end

    fcHz = sum(fAxis .* psd) / totalPower;
end

function spanHz = localEnergySpan(psd, fAxis)
    % localEnergySpan - width (Hz) of the NARROWEST contiguous band holding 99%
    % of the energy. Robust to scattered low-energy noise tails (which a simple
    % percentile span would let push the edges to the band limits): a genuine
    % broadband signal yields a wide band, a narrow tone plus scattered noise
    % yields a narrow band. fAxis is ascending.
    total = sum(psd);
    if total <= 0
        spanHz = 0;
        return;
    end
    target = 0.99 * total;
    n = numel(psd);
    cumE = cumsum(psd);
    best = inf;
    rIdx = 1;
    for lIdx = 1:n
        if rIdx < lIdx
            rIdx = lIdx;
        end
        while rIdx < n && (cumE(rIdx) - cumE(lIdx) + psd(lIdx)) < target
            rIdx = rIdx + 1;
        end
        if (cumE(rIdx) - cumE(lIdx) + psd(lIdx)) >= target
            best = min(best, fAxis(rIdx) - fAxis(lIdx));
        end
    end
    if ~isfinite(best)
        spanHz = fAxis(end) - fAxis(1);
    else
        spanHz = best;
    end
end
