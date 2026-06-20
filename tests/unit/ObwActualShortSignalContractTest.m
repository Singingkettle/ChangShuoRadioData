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

        function lateFrameTailBurstIsNotDiscarded(testCase)
            % Regression: a short burst sitting entirely in the trailing
            % partial segment that pwelch discards must still be measured as
            % a positive occupied bandwidth (both estimators). Before the
            % whole-signal-periodogram fallback, pwelch saw an all-zero
            % windowed estimate and reported 0 Hz, which tripped the
            % "OccupiedBandwidthHz must be positive for a live signal"
            % assertion and dropped the entire frame/scenario.
            fs = 2.4e6;
            rng(32000767, 'twister');
            N = 21284; burstLen = 386;
            signal = complex(zeros(N, 1));
            symbols = randi([0, 3], burstLen, 1);
            signal(N - burstLen + 1:N) = exp(1j * 2 * pi * symbols / 4);

            bwActual = csrd.pipeline.measurement.obwActual(signal, fs);
            summary = csrd.pipeline.measurement.measureSignalSummary( ...
                signal, fs, fs);

            testCase.verifyGreaterThan(bwActual, 0);
            testCase.verifyGreaterThan(summary.OccupiedBandwidthHz, 0);
            % The two estimators share the fallback, so they must agree.
            testCase.verifyEqual(bwActual, summary.OccupiedBandwidthHz, ...
                'RelTol', 1e-9);
        end

        function allZeroLongSignalStillReportsZero(testCase)
            % The fallback must not manufacture bandwidth out of a genuinely
            % silent buffer: an all-zero long signal still reports 0 Hz
            % (the caller classifies it as NoSignal upstream).
            fs = 2.4e6;
            signal = complex(zeros(20000, 1));

            bwActual = csrd.pipeline.measurement.obwActual(signal, fs);
            summary = csrd.pipeline.measurement.measureSignalSummary( ...
                signal, fs, fs);

            testCase.verifyEqual(bwActual, 0);
            testCase.verifyEqual(summary.OccupiedBandwidthHz, 0);
        end

    end
end
