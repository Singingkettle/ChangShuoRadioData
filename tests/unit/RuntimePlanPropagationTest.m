classdef RuntimePlanPropagationTest < matlab.unittest.TestCase
    % RuntimePlanPropagationTest - Derived runtime facts flow from RuntimePlan.

    methods (Test)
        function scenarioFactorySurfacesRuntimePlanWithoutConfigWriteBack(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            cfg.Factories.Scenario.CommunicationBehavior.Receiver.SampleRate = 20e6;
            cfg = csrd.test_support.applyCanonicalFrameContract(cfg, 0.001, 2);
            cfg.Factories.Scenario.PhysicalEnvironment.Map.Types = {'Statistical'};
            cfg.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;
            cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min = 1;
            cfg.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = 1;
            cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = 1;
            cfg.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = 1;
            cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternTypes = {'Continuous'};
            cfg.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternDistribution = 1;
            cfg = csrd.test_support.buildRuntimePlanForTest(cfg);

            testCase.verifyFalse(isfield(cfg.Factories.Scenario.Global, 'FrameDuration'));
            testCase.verifyFalse(isfield(cfg.Factories.Scenario.Global, 'ObservationDuration'));

            factory = csrd.factories.ScenarioFactory( ...
                'Config', cfg.Factories.Scenario, ...
                'RuntimePlan', cfg.RuntimePlan);
            cleanup = onCleanup(@() release(factory)); %#ok<NASGU>

            setup(factory);
            [txFrame, rxFrame] = step(factory, 1);
            frameWindow = txFrame{1}.TransmissionState.FrameWindow;
            testCase.verifyEqual(frameWindow(2) - frameWindow(1), ...
                cfg.RuntimePlan.Frame.FrameDurationSec, 'AbsTol', 1e-15);
            testCase.verifyEqual(rxFrame{1}.Observation.SampleRate, ...
                cfg.RuntimePlan.Frame.SampleRateHz, 'AbsTol', 1e-9);

            rx = {struct('SampleRate', cfg.RuntimePlan.Frame.SampleRateHz, ...
                'ObservableBandwidth', cfg.RuntimePlan.Frame.SampleRateHz)};
            blueprint = factory.assembleBlueprint(1, {}, rx, struct(), ...
                struct('MapType', 'Statistical'));

            testCase.verifyEqual(blueprint.Global.FrameDuration, ...
                cfg.RuntimePlan.Frame.FrameDurationSec, 'AbsTol', 1e-15);
            testCase.verifyEqual(blueprint.Global.NumFrames, ...
                cfg.RuntimePlan.Frame.NumFramesPerScenario);

            report = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.validate(blueprint);
            testCase.verifyTrue(report.IsFeasible);
        end
    end
end
