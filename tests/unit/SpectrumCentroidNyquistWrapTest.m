classdef SpectrumCentroidNyquistWrapTest < matlab.unittest.TestCase
    % SpectrumCentroidNyquistWrapTest - keep the measured spectral centroid
    % inside the physical captured band [-Fs/2, Fs/2).
    %
    %   The per-emitter placement is a CIRCULAR frequency shift, so a band can
    %   straddle the +/-Fs/2 Nyquist edge. circularRecenterSpectrum shifts it
    %   to baseband for the linear centroid, then the absolute centre is
    %   recovered by adding back the shift. That add-back could push an
    %   edge-straddling centroid just past +/-Fs/2 (observed up to ~1.09*Fs/2
    %   in production), reporting a CenterFrequencyHz outside the receiver
    %   passband -- a downstream consumer placing it on the receiver frequency
    %   canvas would land off-canvas. Both spectrumCentroid and
    %   measureSignalSummary must wrap the final centre back into the band.

    methods (Test)

        function centroidStaysInBandForEdgeStraddlingSignals(testCase)
            Fs = 1e6;
            N = 4096;
            t = (0:N - 1)' / Fs;
            for shiftFrac = [0.40, 0.45, 0.48, 0.49, 0.495, 0.499]
                base = (1 + 0.5 * cos(2 * pi * 0.05 * Fs * t)) ...
                    .* exp(1i * 2 * pi * 0.02 * Fs * t);
                x = base .* exp(1i * 2 * pi * shiftFrac * Fs * t);

                fc = csrd.pipeline.measurement.spectrumCentroid(x, Fs);
                summary = csrd.pipeline.measurement.measureSignalSummary(x, Fs);

                testCase.verifyLessThanOrEqual(abs(fc), Fs / 2 + 1, ...
                    sprintf(['spectrumCentroid must stay in [-Fs/2, Fs/2) ', ...
                        '(shift = %.3f Fs).'], shiftFrac));
                testCase.verifyLessThanOrEqual(abs(summary.CenterFrequencyHz), Fs / 2 + 1, ...
                    sprintf(['measureSignalSummary CenterFrequencyHz must stay ', ...
                        'in [-Fs/2, Fs/2) (shift = %.3f Fs).'], shiftFrac));
            end
        end

    end

end
