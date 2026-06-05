classdef ChangShuoRuntimePlanRequiredTest < matlab.unittest.TestCase
    % ChangShuoRuntimePlanRequiredTest - Engine no longer normalizes internally.

    methods (Test)
        function engineRequiresRuntimePlan(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            engine = csrd.core.ChangShuo('FactoryConfigs', cfg.Factories);
            cleanup = onCleanup(@() localRelease(engine)); %#ok<NASGU>

            testCase.verifyError(@() setup(engine), ...
                'CSRD:RuntimePlan:MissingRuntimePlan');
        end
    end
end

function localRelease(obj)
if isLocked(obj)
    release(obj);
end
end
