classdef ModulatedBandwidthMimoNoCancellationTest < matlab.unittest.TestCase
    %MODULATEDBANDWIDTHMIMONOCANCELLATIONTEST Clean Tx OBW is per antenna.

    methods (Test)

        function antennaMaxAvoidsDestructiveColumnCancellation(testCase)
            fs = 10e6;
            n = 4096;
            t = (0:n - 1).' / fs;
            tone = exp(1j * 2 * pi * 1e6 * t);
            mimoSignal = [tone, -tone];

            summedBw = csrd.pipeline.measurement.obwActual(mimoSignal, fs);
            antennaBw = csrd.pipeline.measurement.obwAntennaMax(mimoSignal, fs);

            testCase.verifyEqual(summedBw, 0, ...
                'This fixture must exercise destructive column cancellation.');
            testCase.verifyGreaterThan(antennaBw, 0, ...
                'Clean execution bandwidth must survive opposite-phase antennas.');
        end

    end
end
