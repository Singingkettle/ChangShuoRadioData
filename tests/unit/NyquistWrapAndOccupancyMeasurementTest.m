classdef NyquistWrapAndOccupancyMeasurementTest < matlab.unittest.TestCase
    % NyquistWrapAndOccupancyMeasurementTest - guards the round-12 measurement
    % fixes:
    %   (1) circular (+/-Fs/2 Nyquist-edge) wrap handling in the OBW span
    %       search and the spectral centroid (circularRecenterSpectrum), and
    %   (2) the occupancy-robust collapse-guard floor (10th- vs 25th-percentile)
    %       so a high-occupancy wideband signal with a localized spectral spike
    %       does not collapse to the spike.

    methods (Test)
        function edgePlacedEmitterMeasuredWithoutWrapInflation(testCase)
            % An emitter placed near +Fs/2 whose realized band overruns the
            % Nyquist edge wraps to -Fs/2. The OBW must stay narrow (not inflate
            % toward Fs by bridging the empty middle) and the centroid must
            % track the placement offset (not collapse toward baseband).
            Fs = 50e6; N = 8192; t = (0:N - 1)' / Fs;
            rng(7);
            b = fir1(220, 0.035);
            x0 = filter(b, 1, complex(randn(N, 1), randn(N, 1)));
            x0 = x0 / sqrt(mean(abs(x0) .^ 2));
            s0 = csrd.pipeline.measurement.measureSignalSummary(x0, Fs, Fs);

            off = 0.49 * Fs;
            xe = x0 .* exp(1j * 2 * pi * off * t);
            se = csrd.pipeline.measurement.measureSignalSummary(xe, Fs, Fs);
            ce = csrd.pipeline.measurement.spectrumCentroid(xe, Fs);

            testCase.verifyLessThan(se.OccupiedBandwidthHz, 3 * s0.OccupiedBandwidthHz, ...
                'Edge-placed emitter OBW inflated by the Nyquist-edge wrap.');
            testCase.verifyLessThan(abs(ce - off), 0.05 * Fs, ...
                'Edge-placed emitter centroid collapsed toward baseband (wrap).');
        end

        function highOccupancyBandWithSpikeDoesNotCollapse(testCase)
            % A ~78%-occupancy wideband signal with a localized spectral spike:
            % a 25th-percentile floor lands inside the occupied band and lets
            % the OBW collapse to the spike; the 10th-percentile floor keeps the
            % whole occupied band.
            Fs = 50e6; N = 8192; t = (0:N - 1)' / Fs;
            rng(11);
            b = fir1(120, 0.78);
            x = filter(b, 1, complex(randn(N, 1), randn(N, 1)));
            x = x / sqrt(mean(abs(x) .^ 2));
            x = x + 1.5 * exp(1j * 2 * pi * 8e6 * t);

            obw = csrd.pipeline.measurement.obwActual(x, Fs);
            summ = csrd.pipeline.measurement.measureSignalSummary(x, Fs, Fs);

            minExpected = 0.5 * 0.78 * Fs;   % half the realized flat band
            testCase.verifyGreaterThan(obw, minExpected, ...
                'obwActual collapsed a high-occupancy band to the spike.');
            testCase.verifyGreaterThan(summ.OccupiedBandwidthHz, minExpected, ...
                'measureSignalSummary collapsed a high-occupancy band to the spike.');
        end

        function centeredSignalsUnaffectedByCircularRecenter(testCase)
            % The circular recentre must be a no-op for non-wrapped signals:
            % off-centre tones keep their true centre frequency.
            Fs = 50e6; N = 8192; t = (0:N - 1)' / Fs;
            for f0 = [0, 5e6, -8e6]
                xt = exp(1j * 2 * pi * f0 * t) + 1e-3 * complex(randn(N, 1), randn(N, 1));
                fc = csrd.pipeline.measurement.spectrumCentroid(xt, Fs);
                testCase.verifyLessThan(abs(fc - f0), 0.02 * Fs, ...
                    sprintf('Non-wrapped tone at %g Hz mis-centred by the recentre.', f0));
            end
        end
    end
end
