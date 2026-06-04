classdef ScenarioPlanInitialStateAtZeroTest < matlab.unittest.TestCase
    %SCENARIOPLANINITIALSTATEATZEROTEST ScenarioPlan entities start at t=0.

    methods (Test)
        function initialEntitiesAreStampedAtZero(testCase)
            cfg = localFixedStatisticalConfig();
            factory = csrd.factories.ScenarioFactory( ...
                'Config', cfg.Factories.Scenario, ...
                'RuntimePlan', cfg.RuntimePlan);
            cleanupObj = onCleanup(@() localRelease(factory)); %#ok<NASGU>

            scenarioPlan = factory.planScenario(1);
            times = localInitialEntityTimes(scenarioPlan.Entities.Initial);

            testCase.verifyEqual(times.CreationTime, zeros(size(times.CreationTime)));
            testCase.verifyEqual(times.LastUpdateTime, zeros(size(times.LastUpdateTime)));
            testCase.verifyEqual(times.SnapshotTime, zeros(size(times.SnapshotTime)));
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

function times = localInitialEntityTimes(entities)
times = struct();
times.CreationTime = arrayfun(@(e) double(e.CreationTime), entities);
times.LastUpdateTime = arrayfun(@(e) double(e.LastUpdateTime), entities);
times.SnapshotTime = arrayfun(@(e) double(e.Snapshots{1}.Timestamp), entities);
end

function localRelease(obj)
try
    release(obj);
catch
end
end
