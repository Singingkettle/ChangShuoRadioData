classdef FrameRuntimeContractTest < matlab.unittest.TestCase
    %FRAMERUNTIMECONTRACTTEST ScenarioPlan owns resolved frame facts.

    methods (Test)
        function fixedFramePolicyResolvesInScenarioPlan(testCase)
            cfg = localFixedFrameConfig(1024, 10, 50e6);

            plan = csrd.pipeline.runtime.buildScenarioPlan( ...
                cfg.RuntimePlan, cfg.Factories.Scenario, ...
                struct('ScenarioId', 2, 'RandomSeed', 7));

            testCase.verifyEqual(plan.Frame.FrameNumSamples, 1024);
            testCase.verifyEqual(plan.Frame.NumFramesPerScenario, 10);
            testCase.verifyEqual(plan.Frame.FrameDurationSec, 1024 / 50e6, ...
                AbsTol=1e-15);
            testCase.verifyEqual(plan.Frame.ObservationDurationSec, ...
                10 * 1024 / 50e6, AbsTol=1e-15);
            testCase.verifyEqual(plan.Frame.Source, 'ScenarioPlan.Frame');
        end

        function legacyGlobalFrameLengthFailsFast(testCase)
            cfg = localFixedFrameConfig(1024, 1, 50e6);
            cfg.Factories.Scenario.Global = struct('FrameLength', 1024);

            testCase.verifyError(@() ...
                csrd.pipeline.runtime.buildRuntimePlan(cfg), ...
                'CSRD:RuntimePlan:DeprecatedRawField');
        end

        function runnerFixedFrameLengthFailsFast(testCase)
            cfg = localFixedFrameConfig(1024, 1, 50e6);
            cfg.Runner.FixedFrameLength = 1024;

            testCase.verifyError(@() ...
                csrd.pipeline.runtime.buildRuntimePlan(cfg), ...
                'CSRD:RuntimePlan:DeprecatedRawField');
        end

        function derivedGlobalFrameDurationFailsFast(testCase)
            cfg = localFixedFrameConfig(1024, 1, 50e6);
            cfg.Factories.Scenario.Global = struct( ...
                'FrameDuration', 1024 / 50e6);

            testCase.verifyError(@() ...
                csrd.pipeline.runtime.buildRuntimePlan(cfg), ...
                'CSRD:RuntimePlan:DeprecatedRawField');
        end
    end
end

function cfg = localFixedFrameConfig(frameSamples, numFrames, sampleRate)
cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
cfg = csrd.test_support.applyCanonicalFrameContract( ...
    cfg, numFrames * frameSamples / sampleRate, numFrames);
cfg.Factories.Scenario.CommunicationBehavior.Receiver.SampleRate = sampleRate;
cfg = csrd.pipeline.runtime.buildRuntimePlan(cfg);
end
