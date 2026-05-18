classdef ObwActualShortSignalContractTest < matlab.unittest.TestCase
    %OBWACTUALSHORTSIGNALCONTRACTTEST Short clean bursts keep execution BW.

    methods (Test)

        function oneSampleImpulseOccupiesObservableBandwidth(testCase)
            fs = 50e6;
            signal = complex(1, 0);

            bwActual = csrd.pipeline.measurement.obwActual(signal, fs);
            summary = csrd.pipeline.measurement.measureSignalSummary( ...
                signal, fs, fs);

            testCase.verifyEqual(bwActual, fs);
            testCase.verifyEqual(summary.OccupiedBandwidthHz, fs);
        end

        function zeroShortSignalStillReportsNoOccupiedBandwidth(testCase)
            fs = 50e6;
            signal = complex(0, 0);

            bwActual = csrd.pipeline.measurement.obwActual(signal, fs);

            testCase.verifyEqual(bwActual, 0);
        end

    end
end
