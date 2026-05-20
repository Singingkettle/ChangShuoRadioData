classdef RuntimePlanBuildTest < matlab.unittest.TestCase
    % RuntimePlanBuildTest - Phase 30 runtime plan construction.

    methods (Test)
        function defaultConfigBuildsRuntimePlan(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');

            testCase.assertTrue(isfield(cfg, 'RuntimePlan'));
            plan = cfg.RuntimePlan;
            testCase.verifyEqual(plan.Frame.FrameNumSamples, ...
                cfg.Factories.Scenario.Global.FrameNumSamples);
            testCase.verifyEqual(plan.Frame.NumFramesPerScenario, ...
                cfg.Factories.Scenario.Global.NumFramesPerScenario);
            testCase.verifyEqual(plan.Frame.FrameDurationSec, ...
                plan.Frame.FrameNumSamples / plan.Frame.SampleRateHz, ...
                'AbsTol', 1e-15);
            testCase.verifyEqual(plan.Frame.ObservationDurationSec, ...
                plan.Frame.FrameDurationSec * plan.Frame.NumFramesPerScenario, ...
                'AbsTol', 1e-15);
            testCase.verifyEqual(plan.Receiver.RealCarrierFrequencyHz, ...
                cfg.Factories.Scenario.CommunicationBehavior.Receiver.RealCarrierFrequency);
            testCase.verifyEqual(plan.Map.OSMSelectionPolicy, ...
                'BalancedFileCoverage');
            testCase.verifyTrue(isfield(plan, 'Seed'));
        end
    end
end
