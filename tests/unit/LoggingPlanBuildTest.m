classdef LoggingPlanBuildTest < matlab.unittest.TestCase
    % LoggingPlanBuildTest - Validate the Phase 35 logging plan contract.

    methods (Test)
        function defaultConfigBuildsLargeMcLoggingPlan(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            logging = cfg.RuntimePlan.Logging;

            testCase.verifyEqual(logging.Policy, 'LargeMC');
            testCase.verifyEqual(logging.ConsoleThreshold, 'WARNING');
            testCase.verifyEqual(logging.FileThreshold, 'INFO');
            testCase.verifyTrue(logging.ConsoleEnabled);
            testCase.verifyTrue(logging.FileEnabled);
            testCase.verifyEqual(logging.ProgressMode, 'Summary');
            testCase.verifyEqual(logging.Source, 'config.Logging');
            testCase.verifyTrue(startsWith(logging.Fingerprint, 'fnv1a32:'));
        end

        function standardPolicyBuildsDetailedProgress(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            cfg.Logging.Policy = 'Standard';
            cfg.Logging.Progress.Mode = 'Detailed';
            cfg = csrd.pipeline.runtime.buildRuntimePlan(cfg);
            logging = cfg.RuntimePlan.Logging;

            testCase.verifyEqual(logging.Policy, 'Standard');
            testCase.verifyEqual(logging.ConsoleThreshold, 'INFO');
            testCase.verifyEqual(logging.FileThreshold, 'DEBUG');
            testCase.verifyEqual(logging.ProgressMode, 'Detailed');
        end
    end
end
