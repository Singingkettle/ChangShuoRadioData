classdef DeprecatedLoggingFieldsRejectedTest < matlab.unittest.TestCase
    % DeprecatedLoggingFieldsRejectedTest - Reject legacy raw log fields.

    methods (Test)
        function topLevelLogIsRejected(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            cfg.Log = struct('Level', 'DEBUG');

            testCase.verifyError( ...
                @() csrd.pipeline.runtime.buildRuntimePlan(cfg), ...
                'CSRD:RuntimePlan:DeprecatedRawField');
        end

        function runnerLogIsRejected(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            cfg.Runner.Log = struct('Policy', 'LargeMC');

            testCase.verifyError( ...
                @() csrd.pipeline.runtime.buildRuntimePlan(cfg), ...
                'CSRD:RuntimePlan:DeprecatedRawField');
        end
    end
end
