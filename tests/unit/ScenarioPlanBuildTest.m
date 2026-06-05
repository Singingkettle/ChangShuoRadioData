classdef ScenarioPlanBuildTest < matlab.unittest.TestCase
    %SCENARIOPLANBUILDTEST ScenarioPlan is deterministic per run seed/id.

    methods (Test)
        function sameSeedAndScenarioIdRebuildSamePlan(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            ctx = struct('ScenarioId', 17, 'RandomSeed', 20260520);

            a = csrd.pipeline.runtime.buildScenarioPlan( ...
                cfg.RuntimePlan, cfg.Factories.Scenario, ctx);
            b = csrd.pipeline.runtime.buildScenarioPlan( ...
                cfg.RuntimePlan, cfg.Factories.Scenario, ctx);

            testCase.verifyEqual(a.Frame, b.Frame);
            testCase.verifyEqual(a.Seed, b.Seed);
            testCase.verifyEqual(a.ScenarioId, 17);
        end

        function fixedPolicyBuildsExpectedFramePlan(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            cfg = csrd.test_support.applyCanonicalFrameContract(cfg, ...
                3 * 2048 / 50e6, 3);
            cfg = csrd.pipeline.runtime.buildRuntimePlan(cfg);

            plan = csrd.pipeline.runtime.buildScenarioPlan( ...
                cfg.RuntimePlan, cfg.Factories.Scenario, ...
                struct('ScenarioId', 4, 'RandomSeed', 11));

            testCase.verifyEqual(plan.Frame.FrameNumSamples, 2048);
            testCase.verifyEqual(plan.Frame.NumFramesPerScenario, 3);
            testCase.verifyEqual(plan.DatasetAccounting.NumReceiverFrames, 0);
        end
    end
end
