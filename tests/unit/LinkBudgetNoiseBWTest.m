classdef LinkBudgetNoiseBWTest < matlab.unittest.TestCase
    % LinkBudgetNoiseBWTest - Pin the realistic noise-bandwidth contract.
    %
    %   `csrd.pipeline.linkbudget.resolveNoiseBandwidth` clamps the noise
    %   bandwidth used in the link-budget SNR to the smallest of the
    %   configured / receiver / transmitter occupied bandwidths.
    %   Without this clamp, narrow-band signals get a systematically
    %   pessimistic SNR label dominated by spectrum the Tx is not even
    %   using.

    methods (Test)

        function picksSmallestPositiveCandidate(testCase)
            bw = csrd.pipeline.linkbudget.resolveNoiseBandwidth(50e6, 20e6, 100e3);
            testCase.verifyEqual(bw, 100e3, ...
                'Tx-occupied bandwidth (100 kHz) is the smallest candidate.');
        end

        function ignoresMissingAndNonPositive(testCase)
            bw = csrd.pipeline.linkbudget.resolveNoiseBandwidth([], 20e6, NaN);
            testCase.verifyEqual(bw, 20e6);

            testCase.verifyError(@() ...
                csrd.pipeline.linkbudget.resolveNoiseBandwidth(0, -1, []), ...
                'CSRD:LinkBudget:MissingNoiseBandwidth');
        end

        function configuredCanBeTheTightest(testCase)
            bw = csrd.pipeline.linkbudget.resolveNoiseBandwidth(1e6, 20e6, 50e6);
            testCase.verifyEqual(bw, 1e6);
        end

        function missingAllCandidatesFailsFast(testCase)
            testCase.verifyError(@() ...
                csrd.pipeline.linkbudget.resolveNoiseBandwidth([], [], []), ...
                'CSRD:LinkBudget:MissingNoiseBandwidth');
        end

        function rxObservationLargerThanTxIsClamped(testCase)
            bw = csrd.pipeline.linkbudget.resolveNoiseBandwidth(100e6, 50e6, 200e3);
            testCase.verifyEqual(bw, 200e3, ...
                'A 200 kHz Tx in a 50 MHz Rx must clamp the noise BW to 200 kHz.');
        end

    end

end
