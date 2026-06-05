classdef ScenarioPlanFrozenBeforeFrameExecutionTest < matlab.unittest.TestCase
    %SCENARIOPLANFROZENBEFOREFRAMEEXECUTIONTEST Scenario facts do not resample mid-loop.

    methods (Test)
        function frameLoopReusesFrozenScenarioPlan(testCase)
            cfg = localFixedStatisticalConfig();
            factory = csrd.factories.ScenarioFactory( ...
                'Config', cfg.Factories.Scenario, ...
                'RuntimePlan', cfg.RuntimePlan);
            cleanupObj = onCleanup(@() localRelease(factory)); %#ok<NASGU>

            scenarioPlan = factory.planScenario(1);
            [~, ~, layout1] = step(factory, 1);
            [~, ~, layout2] = step(factory, 2);

            testCase.verifyEqual(layout1.ScenarioPlan.Frame, scenarioPlan.Frame);
            testCase.verifyEqual(layout2.ScenarioPlan.Frame, scenarioPlan.Frame);
            testCase.verifyEqual(layout1.ScenarioPlan.Map, scenarioPlan.Map);
            testCase.verifyEqual(layout2.ScenarioPlan.Map, scenarioPlan.Map);
            testCase.verifyEqual(layout1.ScenarioPlan.Communication, ...
                scenarioPlan.Communication);
            testCase.verifyEqual(layout2.ScenarioPlan.Communication, ...
                scenarioPlan.Communication);
            testCase.verifyEqual(numel(layout1.ScenarioPlan.Transmitters), ...
                numel(scenarioPlan.Transmitters));
            testCase.verifyEqual(numel(layout2.ScenarioPlan.Receivers), ...
                numel(scenarioPlan.Receivers));
            testCase.verifyEqual(layout2.ScenarioPlan.Frame.FrameNumSamples, 1024);
            testCase.verifyEqual(layout2.ScenarioPlan.Frame.NumFramesPerScenario, 2);
        end
    end
end

function cfg = localFixedStatisticalConfig()
cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
cfg = csrd.test_support.applyCanonicalFrameContract(cfg, 2 * 1024 / 50e6, 2);
cfg.Factories.Scenario.PhysicalEnvironment.Map.Types = {'Statistical'};
cfg.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;
cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min = 1;
cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = 1;
cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Mobility.Model = ...
    'ConstantVelocity';
cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = 1;
cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = 1;
cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Mobility.Model = ...
    'Stationary';
cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternTypes = {'Continuous'};
cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternDistribution = 1;
cfg = csrd.pipeline.runtime.buildRuntimePlan(cfg);
end

function localRelease(obj)
try
    release(obj);
catch
end
end
