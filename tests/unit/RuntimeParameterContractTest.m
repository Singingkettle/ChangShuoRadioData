classdef RuntimeParameterContractTest < matlab.unittest.TestCase
    %RUNTIMEPARAMETERCONTRACTTEST Config loader builds run-level policies.

    methods (Test)
        function defaultConfigUsesFramePolicyNotResolvedGlobalFields(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');

            testCase.verifyFalse(isfield(cfg.Runner, 'FixedFrameLength'));
            testCase.verifyFalse(isfield(cfg.Factories.Scenario, 'Global'));
            testCase.verifyTrue(isfield(cfg.Factories.Scenario, 'FramePolicy'));
            testCase.verifyTrue(isfield(cfg.RuntimePlan, 'FramePolicy'));
            testCase.verifyFalse(isfield(cfg.RuntimePlan, 'Frame'));
            testCase.verifyEqual(cfg.RuntimePlan.FramePolicy.Scope, 'Scenario');
            testCase.verifyEqual(cfg.Metadata.RuntimeContracts.FramePolicy, ...
                cfg.RuntimePlan.FramePolicy);
        end

        function injectedLegacyFrameLengthIsRejected(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            cfg.Factories.Scenario.Global = struct('FrameLength', 1024);

            testCase.verifyError(@() ...
                csrd.pipeline.runtime.buildRuntimePlan(cfg), ...
                'CSRD:RuntimePlan:DeprecatedRawField');
        end
    end
end
