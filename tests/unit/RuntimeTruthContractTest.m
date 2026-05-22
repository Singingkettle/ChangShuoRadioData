classdef RuntimeTruthContractTest < matlab.unittest.TestCase
    % RuntimeTruthContractTest - Phase 18 runtime truth validator coverage.

    methods (Test)
        function configLoaderStampsRuntimeTruthContract(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');

            testCase.assertTrue(isfield(cfg.Metadata.RuntimeContracts, ...
                'RuntimeTruth'));
            truth = cfg.Metadata.RuntimeContracts.RuntimeTruth;

            testCase.verifyEqual(truth.Receiver.SampleRateHz, ...
                cfg.Factories.Scenario.CommunicationBehavior.Receiver.SampleRate);
            testCase.verifyEqual(truth.Receiver.RealCarrierFrequencyHz, ...
                cfg.Factories.Scenario.CommunicationBehavior.Receiver.RealCarrierFrequency);
            testCase.verifyEqual(truth.Frame.FrameNumSamples, ...
                cfg.Factories.Scenario.Global.FrameNumSamples);
        end

        function deprecatedLinkBudgetCarrierFailsAtRuntimeContractBoundary(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            cfg.Factories.Channel.LinkBudget.CarrierFrequency = 915e6;

            testCase.verifyError(@() ...
                csrd.pipeline.runtime.validateRuntimeTruthContracts( ...
                    cfg.Factories, cfg.Runner), ...
                'CSRD:RuntimeTruth:DeprecatedCarrierFrequencyAuthority');
        end

        function observableRangeMustMatchReceiverSampleRateWhenDeclared(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            cfg.Factories.Scenario.CommunicationBehavior.Receiver.ObservableRange = ...
                [-1e6, 1e6];

            testCase.verifyError(@() ...
                csrd.pipeline.runtime.validateRuntimeTruthContracts( ...
                    cfg.Factories, cfg.Runner), ...
                'CSRD:RuntimeTruth:ObservableRangeSampleRateMismatch');
        end
    end
end
