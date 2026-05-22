classdef ScenarioPlanAnnotationContractTest < matlab.unittest.TestCase
    %SCENARIOPLANANNOTATIONCONTRACTTEST Annotation carries the design plan.

    methods (Test)
        function annotationHeaderIncludesScenarioPlanFrame(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            cfg = csrd.test_support.applyCanonicalFrameContract(cfg, 1024 / 50e6, 1);
            cfg.Factories.Scenario.PhysicalEnvironment.Map.Types = {'Statistical'};
            cfg.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;
            cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min = 1;
            cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = 1;
            cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = 1;
            cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = 1;
            cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternTypes = {'Continuous'};
            cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternDistribution = 1;
            cfg = csrd.pipeline.runtime.buildRuntimePlan(cfg);

            engine = csrd.core.ChangShuo();
            cleanupObj = onCleanup(@() localRelease(engine)); %#ok<NASGU>
            engine.FactoryConfigs = cfg.Factories;
            engine.RuntimePlan = cfg.RuntimePlan;
            setup(engine, 1);
            [scenarioData, scenarioAnnotation] = step(engine, 1);

            frameData = scenarioData{1}{1};
            frameAnn = scenarioAnnotation{1}{1};
            testCase.verifyTrue(isfield(frameAnn, 'ScenarioPlan'));
            testCase.verifyEqual( ...
                frameAnn.ScenarioPlan.Frame.FrameNumSamples, 1024);
            testCase.verifyEqual(size(frameData.Signal, 1), ...
                frameAnn.ScenarioPlan.Frame.FrameNumSamples);
            testCase.verifyEqual( ...
                frameAnn.ScenarioPlan.DatasetAccounting.NumReceiverFrames, 1);
        end
    end
end

function localRelease(obj)
try
    release(obj);
catch
end
end
