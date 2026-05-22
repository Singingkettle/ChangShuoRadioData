classdef RuntimeParameterContractTest < matlab.unittest.TestCase
    % RuntimeParameterContractTest - Config loader builds canonical runtime plan.

    methods (Test)
        function defaultConfigUsesCanonicalFrameContract(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');

            testCase.verifyFalse(isfield(cfg.Runner, 'FixedFrameLength'));
            testCase.verifyTrue(isfield(cfg.Factories.Scenario.Global, ...
                'FrameNumSamples'));
            testCase.verifyFalse(isfield(cfg.Factories.Scenario.Global, ...
                'FrameLength'));
            testCase.verifyFalse(isfield(cfg.Factories.Scenario.Global, ...
                'FrameDuration'));
            testCase.verifyFalse(isfield(cfg.Factories.Scenario.Global, ...
                'ObservationDuration'));

            contract = cfg.RuntimePlan.Frame;
            testCase.verifyEqual(contract.FrameNumSamples, ...
                cfg.Factories.Scenario.Global.FrameNumSamples);
            testCase.verifyEqual( ...
                contract.ObservationDurationSec * contract.SampleRateHz, ...
                contract.FrameNumSamples * contract.NumFramesPerScenario, ...
                'AbsTol', 1);
            testCase.verifyEqual(cfg.Metadata.RuntimeContracts.Frame, contract);
        end

        function injectedLegacyFrameLengthIsRejected(testCase)
            fc = struct();
            fc.Scenario.Global = struct('FrameLength', 1024, ...
                'NumFramesPerScenario', 1);
            fc.Scenario.CommunicationBehavior.Receiver.SampleRate = 50e6;

            testCase.verifyError(@() ...
                csrd.pipeline.runtime.resolveFrameRuntimeContract(fc, struct()), ...
                'CSRD:Frame:DeprecatedFrameLengthAlias');
        end
    end
end
