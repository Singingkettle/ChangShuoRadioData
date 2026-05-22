classdef GlobalLoggerSingleInitializationTest < matlab.unittest.TestCase
    % GlobalLoggerSingleInitializationTest - Runner must not mutate logging thresholds.

    methods (Test)
        function runnerSetupDoesNotReapplyLogPolicy(testCase)
            tempRoot = tempname;
            mkdir(tempRoot);
            cleanup = onCleanup(@() localCleanup(tempRoot)); %#ok<NASGU>

            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            cfg.Runner.Data.OutputDirectory = fullfile(tempRoot, 'out');
            cfg = csrd.pipeline.runtime.buildRuntimePlan(cfg);

            csrd.runtime.logger.GlobalLogManager.reset();
            csrd.runtime.logger.GlobalLogManager.initialize( ...
                cfg.RuntimePlan.Logging, fullfile(tempRoot, 'logs'));
            logger = csrd.runtime.logger.GlobalLogManager.getLogger();
            beforeConsole = char(logger.CommandWindowThreshold);
            beforeFile = char(logger.FileThreshold);

            runner = csrd.SimulationRunner( ...
                'RunnerConfig', cfg.Runner, ...
                'FactoryConfigs', cfg.Factories, ...
                'RuntimePlan', cfg.RuntimePlan);
            setup(runner);
            release(runner);

            logger = csrd.runtime.logger.GlobalLogManager.getLogger();
            testCase.verifyEqual(char(logger.CommandWindowThreshold), ...
                beforeConsole);
            testCase.verifyEqual(char(logger.FileThreshold), beforeFile);
        end
    end
end

function localCleanup(pathName)
% localCleanup - Reset logger state and remove temporary files.
try
    csrd.runtime.logger.GlobalLogManager.reset();
catch
end
if isfolder(pathName)
    try
        rmdir(pathName, 's');
    catch
    end
end
end
