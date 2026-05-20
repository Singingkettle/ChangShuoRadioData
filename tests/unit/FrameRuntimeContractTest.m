classdef FrameRuntimeContractTest < matlab.unittest.TestCase
    % FrameRuntimeContractTest - Phase 17 canonical frame/time contract.
    % 中文说明：验证 FrameNumSamples 是唯一帧长权威，旧字段直接拒绝。

    methods (Test)
        function canonicalFrameNumSamplesResolves(testCase)
            fc = localFactoryConfigs(1024, 10, 50e6);
            c = csrd.pipeline.runtime.resolveFrameRuntimeContract(fc, struct());

            testCase.verifyEqual(c.FrameNumSamples, 1024);
            testCase.verifyEqual(c.NumFramesPerScenario, 10);
            testCase.verifyEqual(c.FrameDurationSec, 1024 / 50e6, ...
                'AbsTol', 1e-15);
            testCase.verifyEqual(c.ObservationDurationSec, ...
                10 * 1024 / 50e6, 'AbsTol', 1e-15);
            testCase.verifyEqual(c.Source, ...
                'Factories.Scenario.Global.FrameNumSamples');
        end

        function legacyGlobalFrameLengthFailsFast(testCase)
            fc = localFactoryConfigs(1024, 1, 50e6);
            fc.Scenario.Global = rmfield(fc.Scenario.Global, 'FrameNumSamples');
            fc.Scenario.Global.FrameLength = 1024;

            testCase.verifyError(@() ...
                csrd.pipeline.runtime.resolveFrameRuntimeContract(fc, struct()), ...
                'CSRD:Frame:DeprecatedFrameLengthAlias');
        end

        function frameDurationCannotInferFrameSamples(testCase)
            fc = localFactoryConfigs(1024, 1, 50e6);
            fc.Scenario.Global = rmfield(fc.Scenario.Global, 'FrameNumSamples');

            testCase.verifyError(@() ...
                csrd.pipeline.runtime.resolveFrameRuntimeContract(fc, struct()), ...
                'CSRD:Frame:MissingFrameNumSamples');
        end

        function runnerFixedFrameLengthFailsFast(testCase)
            fc = localFactoryConfigs(1024, 1, 50e6);
            runner = struct('FixedFrameLength', 1024);

            testCase.verifyError(@() ...
                csrd.pipeline.runtime.resolveFrameRuntimeContract(fc, runner), ...
                'CSRD:Frame:DeprecatedRunnerFixedFrameLength');
        end

        function derivedObservationDurationFailsFast(testCase)
            fc = localFactoryConfigs(1024, 10, 50e6);
            fc.Scenario.Global.ObservationDuration = 1.0;

            testCase.verifyError(@() ...
                csrd.pipeline.runtime.resolveFrameRuntimeContract(fc, struct()), ...
                'CSRD:Frame:DeprecatedDerivedObservationDuration');
        end

        function derivedFrameDurationFailsFast(testCase)
            fc = localFactoryConfigs(1024, 10, 50e6);
            fc.Scenario.Global.FrameDuration = 1024 / 50e6;

            testCase.verifyError(@() ...
                csrd.pipeline.runtime.resolveFrameRuntimeContract(fc, struct()), ...
                'CSRD:Frame:DeprecatedDerivedFrameDuration');
        end

        function frameWindowMustMatchCanonicalFrame(testCase)
            fc = localFactoryConfigs(1024, 1, 50e6);
            badWindow = [0, 2048 / 50e6];

            testCase.verifyError(@() ...
                csrd.pipeline.runtime.resolveFrameRuntimeContract(fc, struct(), ...
                'FrameWindow', badWindow), ...
                'CSRD:Frame:InconsistentFrameSamples');
        end
    end
end

function fc = localFactoryConfigs(frameSamples, numFrames, sampleRate)
fc = struct();
fc.Scenario.Global = struct( ...
    'FrameNumSamples', frameSamples, ...
    'NumFramesPerScenario', numFrames);
fc.Scenario.CommunicationBehavior.Receiver.SampleRate = sampleRate;
end
