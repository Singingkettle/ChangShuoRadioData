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

        function preservesExactLength(testCase)
            s = struct('Signal', complex(ones(4, 1)), 'SampleRate', 2000);
            out = csrd.pipeline.signal.gateToDuration(s, 0.002, 'UnitExact');

            testCase.verifyEqual(size(out.Signal, 1), 4);
            testCase.verifyEqual(out.SignalGating.UnitExact.Action, 'none');
            testCase.verifyEqual(out.SignalDurationSec, 0.002, 'AbsTol', 1e-12);
        end
    end
end
