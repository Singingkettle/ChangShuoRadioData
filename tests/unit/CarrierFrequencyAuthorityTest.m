classdef CarrierFrequencyAuthorityTest < matlab.unittest.TestCase
    % CarrierFrequencyAuthorityTest - Receiver RF plan owns carrier frequency.

    methods (Test)
        function linkBudgetCarrierFieldIsForbidden(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            cfg.Factories.Channel.LinkBudget.CarrierFrequency = ...
                cfg.Factories.Scenario.CommunicationBehavior.Receiver.RealCarrierFrequency;

            testCase.verifyError(@() ...
                csrd.pipeline.runtime.validateRuntimeTruthContracts( ...
                    cfg.Factories, cfg.Runner), ...
                'CSRD:RuntimeTruth:DeprecatedCarrierFrequencyAuthority');
        end

        function receiverCarrierIsStampedAsChannelRuntimeCarrier(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            contract = csrd.pipeline.runtime.validateRuntimeTruthContracts( ...
                cfg.Factories, cfg.Runner);

            testCase.verifyEqual(contract.Channel.LinkBudget.CarrierFrequencyHz, ...
                contract.Receiver.RealCarrierFrequencyHz);
        end
    end
end
