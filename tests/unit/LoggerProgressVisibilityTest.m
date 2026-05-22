classdef LoggerProgressVisibilityTest < matlab.unittest.TestCase
    % LoggerProgressVisibilityTest - Pin operator progress policy behavior.

    methods (Test)
        function largeMcKeepsInfoOutOfConsoleButAllowsProgress(testCase)
            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            logging = cfg.RuntimePlan.Logging;

            testCase.verifyEqual(logging.Policy, 'LargeMC');
            testCase.verifyEqual(logging.ConsoleThreshold, 'WARNING');
            testCase.verifyEqual(logging.FileThreshold, 'INFO');
            testCase.verifyEqual(logging.ProgressMode, 'Summary');

            runnerText = fileread(fullfile(fileparts(fileparts( ...
                fileparts(mfilename('fullpath')))), '+csrd', ...
                'SimulationRunner.m'));
            simulationText = fileread(fullfile(fileparts(fileparts( ...
                fileparts(mfilename('fullpath')))), 'tools', ...
                'simulation.m'));

            testCase.verifyTrue(contains(runnerText, 'logProgress(obj'), ...
                'SimulationRunner must use the progress helper.');
            testCase.verifyTrue(contains(simulationText, 'localLogProgress'), ...
                'simulation.m must use the startup progress helper.');
        end
    end
end
