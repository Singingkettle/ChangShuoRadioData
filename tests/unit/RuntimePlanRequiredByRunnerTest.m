classdef RuntimePlanRequiredByRunnerTest < matlab.unittest.TestCase
    % RuntimePlanRequiredByRunnerTest - Runner no longer normalizes internally.

    methods (Test)
        function runnerRequiresRuntimePlan(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            cfg.Runner.NumScenarios = 1;
            runner = csrd.SimulationRunner('RunnerConfig', cfg.Runner);
            runner.FactoryConfigs = cfg.Factories;
            cleanup = onCleanup(@() localRelease(runner)); %#ok<NASGU>

            testCase.verifyError(@() runner(1, 1), ...
                'CSRD:RuntimePlan:MissingRuntimePlan');
        end

        function runnerRejectsMismatchedRuntimePlanFingerprint(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            cfg.Runner.NumScenarios = 1;
            runner = csrd.SimulationRunner('RunnerConfig', cfg.Runner);
            runner.FactoryConfigs = cfg.Factories;
            runner.RuntimePlan = cfg.RuntimePlan;
            cleanup = onCleanup(@() localRelease(runner)); %#ok<NASGU>

            testCase.verifyError(@() runner(1, 1), ...
                'CSRD:RuntimePlan:ConfigFingerprintMismatch');
        end
    end
end

function localRelease(obj)
if isLocked(obj)
    release(obj);
end
end
