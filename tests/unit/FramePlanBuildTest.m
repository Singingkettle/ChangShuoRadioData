classdef FramePlanBuildTest < matlab.unittest.TestCase
    %FRAMEPLANBUILDTEST FramePlan is derived from a frozen ScenarioPlan.

    methods (Test)
        function frameKWindowUsesScenarioFrameDuration(testCase)
            scenarioPlan = struct();
            scenarioPlan.ScenarioId = 8;
            scenarioPlan.Frame = struct( ...
                'FrameNumSamples', 1000, ...
                'NumFramesPerScenario', 4, ...
                'SampleRateHz', 1000, ...
                'FrameDurationSec', 1);

            framePlan = csrd.pipeline.runtime.buildFramePlan( ...
                scenarioPlan, 3);

            testCase.verifyEqual(framePlan.FrameId, 3);
            testCase.verifyEqual(framePlan.FrameWindowSec, [2, 3]);
            testCase.verifyEqual(framePlan.FrameNumSamples, 1000);
            testCase.verifyEqual(framePlan.SampleRateHz, 1000);
            testCase.verifyEqual(framePlan.ScenarioId, 8);
        end

        function outOfRangeFrameFailsFast(testCase)
            scenarioPlan = struct();
            scenarioPlan.Frame = struct( ...
                'FrameNumSamples', 1000, ...
                'NumFramesPerScenario', 2, ...
                'SampleRateHz', 1000, ...
                'FrameDurationSec', 1);

            testCase.verifyError(@() csrd.pipeline.runtime.buildFramePlan( ...
                scenarioPlan, 3), 'CSRD:FramePlan:FrameOutOfRange');
        end
    end
end
