classdef RuntimePlanBuildTest < matlab.unittest.TestCase
    % RuntimePlanBuildTest - Phase 33 run-level policy construction.

    methods (Test)
        function defaultConfigBuildsRuntimePlan(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');

            testCase.assertTrue(isfield(cfg, 'RuntimePlan'));
            plan = cfg.RuntimePlan;
            testCase.verifyFalse(isfield(plan, 'Frame'));
            testCase.verifyTrue(isfield(plan, 'FramePolicy'));
            testCase.verifyEqual(plan.FramePolicy.Scope, 'Scenario');
            testCase.verifyEqual( ...
                plan.FramePolicy.FrameNumSamples.Mode, 'Choice');
            testCase.verifyEqual( ...
                plan.FramePolicy.NumFramesPerScenario.Mode, 'IntegerRange');
            testCase.verifyEqual(plan.Receiver.RealCarrierFrequencyHz, ...
                cfg.Factories.Scenario.CommunicationBehavior.Receiver.RealCarrierFrequency);
            testCase.verifyEqual(plan.Map.OSMSelectionPolicy, ...
                'BalancedFileCoverage');
            testCase.verifyTrue(isfield(plan, 'Seed'));
        end

        function scenarioPlanResolvesFrameFacts(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            scenarioPlan = csrd.pipeline.runtime.buildScenarioPlan( ...
                cfg.RuntimePlan, cfg.Factories.Scenario, ...
                struct('ScenarioId', 3, 'RandomSeed', cfg.Runner.RandomSeed));

            testCase.verifyTrue(isfield(scenarioPlan, 'Frame'));
            testCase.verifyGreaterThan(scenarioPlan.Frame.FrameNumSamples, 0);
            testCase.verifyGreaterThan(scenarioPlan.Frame.NumFramesPerScenario, 0);
            testCase.verifyEqual(scenarioPlan.Frame.FrameDurationSec, ...
                scenarioPlan.Frame.FrameNumSamples / ...
                scenarioPlan.Frame.SampleRateHz, 'AbsTol', 1e-15);
            testCase.verifyEqual( ...
                scenarioPlan.Frame.ObservationDurationSec, ...
                scenarioPlan.Frame.FrameDurationSec * ...
                scenarioPlan.Frame.NumFramesPerScenario, 'AbsTol', 1e-15);
        end
    end
end
