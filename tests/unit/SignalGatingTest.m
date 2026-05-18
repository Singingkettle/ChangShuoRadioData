classdef SignalGatingTest < matlab.unittest.TestCase
    %SIGNALGATINGTEST Pin duration gating for Phase 16 segment timing.

    methods (Test)
        function trimsLongColumnVector(testCase)
            s = struct('Signal', complex((1:10).'), 'SampleRate', 1000);
            out = csrd.pipeline.signal.gateToDuration(s, 0.006, 'UnitTrim');

            testCase.verifyEqual(size(out.Signal, 1), 6);
            testCase.verifyEqual(out.SignalGating.UnitTrim.Action, 'trim');
            testCase.verifyEqual(out.SignalSampleCount, 6);
        end

        function padsShortMultiAntennaMatrix(testCase)
            s = struct('Signal', complex(ones(3, 2)), 'SampleRate', 1000);
            out = csrd.pipeline.signal.gateToDuration(s, 0.005, 'UnitPad');

            testCase.verifyEqual(size(out.Signal), [5, 2]);
            testCase.verifyEqual(out.Signal(4:5, :), zeros(2, 2));
            testCase.verifyEqual(out.SignalGating.UnitPad.Action, 'pad');
        end

        function preservesOneSampleMultiAntennaRow(testCase)
            s = struct('Signal', complex([1, 2]), 'SampleRate', 1000);
            out = csrd.pipeline.signal.gateToDuration(s, 0.001, 'UnitRowExact');

            testCase.verifyEqual(size(out.Signal), [1, 2]);
            testCase.verifyEqual(real(out.Signal), [1, 2]);
            testCase.verifyEqual(imag(out.Signal), [0, 0]);
            testCase.verifyEqual(out.SignalGating.UnitRowExact.Action, 'none');
        end

        function padsOneSampleMultiAntennaRowByRows(testCase)
            s = struct('Signal', complex([1, 2]), 'SampleRate', 1000);
            out = csrd.pipeline.signal.gateToDuration(s, 0.002, 'UnitRowPad');

            testCase.verifyEqual(size(out.Signal), [2, 2]);
            testCase.verifyEqual(out.Signal(1, :), [1, 2]);
            testCase.verifyEqual(out.Signal(2, :), [0, 0]);
            testCase.verifyEqual(out.SignalGating.UnitRowPad.Action, 'pad');
        end

        function preservesExactLength(testCase)
            s = struct('Signal', complex(ones(4, 1)), 'SampleRate', 2000);
            out = csrd.pipeline.signal.gateToDuration(s, 0.002, 'UnitExact');

            testCase.verifyEqual(size(out.Signal, 1), 4);
            testCase.verifyEqual(out.SignalGating.UnitExact.Action, 'none');
            testCase.verifyEqual(out.SignalDurationSec, 0.002, 'AbsTol', 1e-12);
        end

        function canKeepOneSampleForPositiveSubSampleDuration(testCase)
            s = struct('Signal', complex((1:4).'), 'SampleRate', 1000);
            out = csrd.pipeline.signal.gateToDuration( ...
                s, 1e-4, 'UnitMinPositive', 'MinPositiveSamples', true);

            testCase.verifyEqual(size(out.Signal, 1), 1);
            testCase.verifyEqual(out.Signal(1), 1);
            testCase.verifyEqual(out.SignalGating.UnitMinPositive.RequestedSamples, 0);
            testCase.verifyEqual(out.SignalGating.UnitMinPositive.TargetSamples, 1);
            testCase.verifyTrue(out.SignalGating.UnitMinPositive.MinimumPositiveSamplesApplied);
        end

        function doesNotSynthesizeSampleFromEmptySignal(testCase)
            s = struct('Signal', complex(zeros(0, 1)), 'SampleRate', 1000);
            out = csrd.pipeline.signal.gateToDuration( ...
                s, 1e-4, 'UnitEmpty', 'MinPositiveSamples', true);

            testCase.verifyEqual(size(out.Signal, 1), 0);
            testCase.verifyEqual(out.SignalGating.UnitEmpty.TargetSamples, 0);
            testCase.verifyFalse(out.SignalGating.UnitEmpty.MinimumPositiveSamplesApplied);
        end
    end
end
