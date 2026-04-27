classdef LogPolicyLargeMCTest < matlab.unittest.TestCase
    %LOGPOLICYLARGEMCTEST Phase 0 falsifiable test for the 'LargeMC' tier.
    %
    %   Falsifiable exit condition C2 (phase-0-baseline.md §9):
    %     - Apply 'LargeMC' policy.
    %     - Emit 50 debug() calls.
    %     - Console captures 0 of them (CommandWindow threshold = WARNING).
    %     - Log file captures 0 of them either (File threshold = INFO),
    %       so the I/O cost on a 200-scenario sweep collapses to <5% of
    %       Standard's footprint.
    %
    %   This is the keystone test for §17.2 progress gating: if it goes
    %   red, do NOT merge Phase 0.

    properties (Access = private)
        TempDir
        PreviousSnapshot
    end

    methods (TestMethodSetup)
        function setupGlobalLogger(testCase)
            csrd.utils.logger.GlobalLogManager.reset();
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            cfg = struct( ...
                'Name', 'CSRD-LogPolicyLargeMC-Test', ...
                'Level', 'DEBUG', ...
                'SaveToFile', true, ...
                'DisplayInConsole', true);
            csrd.utils.logger.GlobalLogManager.initialize(cfg, testCase.TempDir);
        end
    end

    methods (TestMethodTeardown)
        function teardownGlobalLogger(testCase)
            if ~isempty(testCase.PreviousSnapshot)
                try
                    csrd.utils.logger.policy.LogPolicy.restore( ...
                        testCase.PreviousSnapshot);
                catch
                end
            end
            try
                logger = csrd.utils.logger.GlobalLogManager.getLogger();
                logger.fcloseLogFile();
            catch
            end
            csrd.utils.logger.GlobalLogManager.reset();
            if ~isempty(testCase.TempDir) && isfolder(testCase.TempDir)
                try
                    rmdir(testCase.TempDir, 's');
                catch
                end
            end
        end
    end

    methods (Test)
        function applySetsExpectedThresholds(testCase)
            import csrd.utils.logger.mlog.Level
            policy = csrd.utils.logger.policy.LogPolicy('LargeMC');
            testCase.PreviousSnapshot = policy.apply();
            logger = csrd.utils.logger.GlobalLogManager.getLogger();
            testCase.verifyEqual(logger.CommandWindowThreshold, Level.WARNING);
            testCase.verifyEqual(logger.FileThreshold, Level.INFO);
        end

        function fiftyDebugCallsLeaveLogFileUntouched(testCase)
            % Apply LargeMC, emit 50 debug() lines, then verify that the
            % rolling log file contains zero of the marker tokens.
            % We read the active file via logger.LogFile rather than via
            % dir(getLogDirectory()) because the singleton can reuse a
            % previous test's directory; LogFile is always authoritative.

            policy = csrd.utils.logger.policy.LogPolicy('LargeMC');
            testCase.PreviousSnapshot = policy.apply();
            logger = csrd.utils.logger.GlobalLogManager.getLogger();

            % Force at least one INFO line first so the file definitely
            % exists (info passes File threshold INFO).
            logger.info('LARGEMC bootstrap line for file creation');

            tokenStem = sprintf('LARGEMC-DROP-%s', ...
                char(java.util.UUID.randomUUID));
            for k = 1:50
                logger.debug('%s-%03d', tokenStem, k);
            end

            try
                logger.fcloseLogFile();
            catch
            end

            logFile = char(logger.LogFile);
            testCase.assertNotEmpty(logFile, ...
                'logger.LogFile must be populated after the info() line.');
            testCase.assertTrue(isfile(logFile), sprintf( ...
                'Expected logger.LogFile to exist on disk: %s', logFile));

            txt = fileread(logFile);
            totalHits = numel(strfind(txt, tokenStem));
            testCase.verifyEqual(totalHits, 0, sprintf( ...
                ['LargeMC tier must drop debug() calls from the file ', ...
                'sink as well; got %d hits in %s.'], totalHits, logFile));
        end

        function infoLevelStillReachesFile(testCase)
            % Sanity: INFO must still go to the file, otherwise we'd
            % have lost progress reporting.

            policy = csrd.utils.logger.policy.LogPolicy('LargeMC');
            testCase.PreviousSnapshot = policy.apply();
            logger = csrd.utils.logger.GlobalLogManager.getLogger();

            marker = sprintf('LARGEMC-KEEP-%s', ...
                char(java.util.UUID.randomUUID));
            logger.info('%s', marker);

            try
                logger.fcloseLogFile();
            catch
            end

            logFile = char(logger.LogFile);
            testCase.assertNotEmpty(logFile, ...
                'logger.LogFile must be populated after info() call.');
            testCase.assertTrue(isfile(logFile), sprintf( ...
                'Expected logger.LogFile to exist on disk: %s', logFile));
            txt = fileread(logFile);
            testCase.verifyTrue(contains(txt, marker), sprintf( ...
                ['LargeMC tier must still write info() lines to the file. ', ...
                'File=%s, marker=%s'], logFile, marker));
        end

        function applyWithoutInitRaises(testCase)
            csrd.utils.logger.GlobalLogManager.reset();
            policy = csrd.utils.logger.policy.LogPolicy('LargeMC');
            testCase.verifyError(@() policy.apply(), ...
                'CSRD:Phase0:LogPolicyNotInitialized');
        end

        function badLevelRaises(testCase)
            testCase.verifyError(...
                @() csrd.utils.logger.policy.LogPolicy('NotARealTier'), ...
                'CSRD:Phase0:InvalidLogPolicy');
        end
    end
end
