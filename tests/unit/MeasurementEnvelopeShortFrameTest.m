classdef MeasurementEnvelopeShortFrameTest < matlab.unittest.TestCase
    % MeasurementEnvelopeShortFrameTest
    % 中文说明：短帧默认测量窗口自适应，显式过大窗口仍硬失败。

    methods (Test)

        function defaultWindowFitsShortFrame(testCase)
            sampleRate = 50e6;
            signal = ones(1024, 1);
            info = csrd.pipeline.measurement.detectBurstEnvelope(signal, sampleRate);

            testCase.verifyEqual(info.WindowSec, numel(signal) / sampleRate, ...
                'AbsTol', 1e-15);
            testCase.verifyEqual(info.TimeOccupancy, 1);
            testCase.verifyEqual(info.NumBursts, 1);
        end

        function explicitTooLargeWindowStillFails(testCase)
            sampleRate = 50e6;
            signal = ones(1024, 1);
            testCase.verifyError(@() ...
                csrd.pipeline.measurement.detectBurstEnvelope( ...
                    signal, sampleRate, struct('WindowSec', 1e-4)), ...
                'CSRD:Measurement:InvalidWindow');
        end

    end
end
