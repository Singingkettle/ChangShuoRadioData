classdef MeasurementSpectrumCacheEquivalenceTest < matlab.unittest.TestCase
    %MEASUREMENTSPECTRUMCACHEEQUIVALENCETEST Phase 21 summary helper contract.

    methods (Test)

        function summaryMatchesLegacyMeasurementHelpers(testCase)
            fs = 50e6;
            n = 32768;
            t = (0:n - 1).' / fs;
            rng(2101);
            signal = exp(1j * 2 * pi * 1.8e6 * t) + ...
                0.2 * exp(1j * 2 * pi * -0.9e6 * t) + ...
                0.05 * complex(randn(n, 1), randn(n, 1));
            observableBwHz = 20e6;

            legacyObw = csrd.pipeline.measurement.obwActual(signal, fs, 99);
            legacyCentroid = csrd.pipeline.measurement.spectrumCentroid(signal, fs);
            legacyEnvelope = csrd.pipeline.measurement.detectBurstEnvelope(signal, fs, struct());
            legacyFreqOcc = csrd.pipeline.measurement.frequencyOccupancy( ...
                legacyObw, observableBwHz);

            summary = csrd.pipeline.measurement.measureSignalSummary( ...
                signal, fs, observableBwHz);

            testCase.verifyEqual(summary.OccupiedBandwidthHz, legacyObw, ...
                'AbsTol', max(1, 1e-12 * fs));
            testCase.verifyEqual(summary.CenterFrequencyHz, legacyCentroid, ...
                'AbsTol', max(1, 1e-12 * fs));
            testCase.verifyEqual(summary.TimeOccupancy, legacyEnvelope.TimeOccupancy, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(summary.FrequencyOccupancy, legacyFreqOcc, ...
                'AbsTol', 1e-12);
            testCase.verifyEqual(summary.Envelope.NumBursts, legacyEnvelope.NumBursts);
            testCase.verifyEqual(summary.MeasurementStatus, 'Measured');
        end

        function multiAntennaCollapseMatchesLegacyHelpers(testCase)
            fs = 10e6;
            n = 4096;
            t = (0:n - 1).' / fs;
            signal = [exp(1j * 2 * pi * 0.4e6 * t), ...
                      0.5 * exp(1j * 2 * pi * 0.7e6 * t)];
            collapsed = sum(signal, 2);

            summary = csrd.pipeline.measurement.measureSignalSummary( ...
                signal, fs, 5e6);
            testCase.verifyEqual(summary.OccupiedBandwidthHz, ...
                csrd.pipeline.measurement.obwActual(collapsed, fs, 99), ...
                'AbsTol', max(1, 1e-12 * fs));
            testCase.verifyEqual(summary.CenterFrequencyHz, ...
                csrd.pipeline.measurement.spectrumCentroid(collapsed, fs), ...
                'AbsTol', max(1, 1e-12 * fs));
        end

    end
end
