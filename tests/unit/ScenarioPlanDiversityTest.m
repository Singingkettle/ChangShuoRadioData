classdef ScenarioPlanDiversityTest < matlab.unittest.TestCase
    %SCENARIOPLANDIVERSITYTEST Default policy produces scenario diversity.

    methods (Test)
        function defaultPolicyVariesFrameShapeAcrossScenarios(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            frameSamples = zeros(1, 20);
            frameCounts = zeros(1, 20);

            for scenarioId = 1:20
                plan = csrd.pipeline.runtime.buildScenarioPlan( ...
                    cfg.RuntimePlan, cfg.Factories.Scenario, ...
                    struct('ScenarioId', scenarioId, ...
                    'RandomSeed', cfg.Runner.RandomSeed));
                frameSamples(scenarioId) = plan.Frame.FrameNumSamples;
                frameCounts(scenarioId) = plan.Frame.NumFramesPerScenario;
            end

            testCase.verifyGreaterThan(numel(unique(frameSamples)), 1);
            testCase.verifyGreaterThan(numel(unique(frameCounts)), 1);
        end
    end
end
