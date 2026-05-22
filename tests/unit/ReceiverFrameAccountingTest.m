classdef ReceiverFrameAccountingTest < matlab.unittest.TestCase
    %RECEIVERFRAMEACCOUNTINGTEST Dataset item count is receiver-frame count.

    methods (Test)
        function scenarioPlanCountsReceiverFrames(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            cfg = csrd.test_support.applyCanonicalFrameContract(cfg, ...
                3 * 1024 / 50e6, 3);
            cfg.Factories.Scenario.PhysicalEnvironment.Map.Types = {'Statistical'};
            cfg.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;
            cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min = 1;
            cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = 1;
            cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = 2;
            cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = 2;
            cfg = csrd.pipeline.runtime.buildRuntimePlan(cfg);

            factory = csrd.factories.ScenarioFactory( ...
                'Config', cfg.Factories.Scenario, ...
                'RuntimePlan', cfg.RuntimePlan);
            cleanupObj = onCleanup(@() localRelease(factory)); %#ok<NASGU>

            scenarioPlan = factory.planScenario(1);
            testCase.verifyEqual(scenarioPlan.DatasetAccounting.NumReceivers, 2);
            testCase.verifyEqual( ...
                scenarioPlan.DatasetAccounting.NumFramesPerScenario, 3);
            testCase.verifyEqual( ...
                scenarioPlan.DatasetAccounting.NumReceiverFrames, 6);
        end
    end
end

function localRelease(obj)
try
    release(obj);
catch
end
end
