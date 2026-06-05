classdef RunPlanPolicyOnlyTest < matlab.unittest.TestCase
    %RUNPLANPOLICYONLYTEST RuntimePlan remains a run-level policy object.

    methods (Test)
        function runtimePlanDoesNotContainScenarioFrameFacts(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');

            testCase.verifyTrue(isfield(cfg.RuntimePlan, 'FramePolicy'));
            testCase.verifyFalse(isfield(cfg.RuntimePlan, 'Frame'));
            testCase.verifyEqual(cfg.RuntimePlan.FramePolicy.Scope, 'Scenario');
            testCase.verifyFalse(isfield(cfg.Metadata.RuntimeContracts, 'Frame'));
            testCase.verifyTrue(isfield(cfg.Metadata.RuntimeContracts, ...
                'FramePolicy'));
        end
    end
end
