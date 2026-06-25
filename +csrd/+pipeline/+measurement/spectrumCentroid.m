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
    % Float the integration threshold with the signal peak (matching the
    % peak-relative OBW estimator) so broadband AWGN -- symmetric about 0 Hz --
    % does not pull the measured center frequency toward baseband. Clipping
    % bins below peak*10^(-3/10) tracks the signal peak instead of the noise
    % floor; a clean single tone keeps its main lobe intact.
    peakVal = max(psd);
    if peakVal > 0
        psd(psd < peakVal * 10 ^ (-3 / 10)) = 0;
    end
    totalPower = sum(psd);
    if totalPower <= 0
        fcHz = 0;
        return;
    end

    fAxis = ((0:N - 1)' - floor(N / 2)) * (double(sampleRate) / N);
    fcHz = sum(fAxis .* psd) / totalPower;
end
