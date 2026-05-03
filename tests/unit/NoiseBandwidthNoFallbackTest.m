classdef NoiseBandwidthNoFallbackTest < matlab.unittest.TestCase
    % NoiseBandwidthNoFallbackTest - Phase 18 forbids magic noise BW.
    % 中文说明：链路预算噪声带宽必须来自显式候选，不能回退到 50 MHz。

    methods (Test)
        function allMissingNoiseBandwidthCandidatesFail(testCase)
            testCase.verifyError(@() ...
                csrd.pipeline.linkbudget.resolveNoiseBandwidth([], [], []), ...
                'CSRD:LinkBudget:MissingNoiseBandwidth');
        end

        function segmentBandwidthCanClampReceiverWindow(testCase)
            bw = csrd.pipeline.linkbudget.resolveNoiseBandwidth([], 50e6, 250e3);
            testCase.verifyEqual(bw, 250e3);
        end
    end
end
