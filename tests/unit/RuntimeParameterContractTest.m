classdef RuntimeParameterContractTest < matlab.unittest.TestCase
    % RuntimeParameterContractTest - Config loader stamps canonical runtime contracts.
    % 中文说明：配置加载后不能残留旧帧长字段，派生时间字段必须一致。

    methods (Test)
        function defaultConfigUsesCanonicalFrameContract(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');

            testCase.verifyFalse(isfield(cfg.Runner, 'FixedFrameLength'));
            testCase.verifyTrue(isfield(cfg.Factories.Scenario.Global, ...
                'FrameNumSamples'));
            testCase.verifyFalse(isfield(cfg.Factories.Scenario.Global, ...
                'FrameLength'));

            contract = cfg.Metadata.RuntimeContracts.Frame;
            testCase.verifyEqual(contract.FrameNumSamples, ...
                cfg.Factories.Scenario.Global.FrameNumSamples);
            testCase.verifyEqual( ...
                cfg.Factories.Scenario.Global.ObservationDuration * ...
                cfg.Factories.Scenario.CommunicationBehavior.Receiver.SampleRate, ...
                contract.FrameNumSamples * contract.NumFramesPerScenario, ...
                'AbsTol', 1);
        end

        function injectedLegacyFrameLengthIsRejected(testCase)
            fc = struct();
            fc.Scenario.Global = struct('FrameLength', 1024, ...
                'NumFramesPerScenario', 1, 'ObservationDuration', 1024 / 50e6);
            fc.Scenario.CommunicationBehavior.Receiver.SampleRate = 50e6;

            testCase.verifyError(@() ...
                csrd.pipeline.runtime.resolveFrameRuntimeContract(fc, struct()), ...
                'CSRD:Frame:DeprecatedFrameLengthAlias');
        end
    end
end
