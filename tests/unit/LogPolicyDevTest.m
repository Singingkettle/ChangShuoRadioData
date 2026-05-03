classdef LogPolicyDevTest < matlab.unittest.TestCase
    %LOGPOLICYDEVTEST Phase 0 tests covering the 'Dev' tier.
    %
    %   In Dev tier:
    %     - Console threshold = DEBUG
    %     - File threshold    = DEBUG
    %     - debug() messages reach BOTH the command window and the file
    %
    %   We use a temporary log directory so we don't pollute the default
    %   artifacts/tests/runs/ log area.

    properties (Access = private)
        TempDir
        PreviousSnapshot
    end

    methods (TestMethodSetup)
        function setupGlobalLogger(testCase)
            % Reset to a clean state, then initialise into a temp dir.
            csrd.runtime.logger.GlobalLogManager.reset();
            testCase.TempDir = tempname;
            mkdir(testCase.TempDir);
            cfg = struct( ...
                'Name', 'CSRD-LogPolicyDev-Test', ...
                'Level', 'DEBUG', ...
                'SaveToFile', true, ...
                'DisplayInConsole', true);
            csrd.runtime.logger.GlobalLogManager.initialize(cfg, testCase.TempDir);
        end
    end

    methods (TestMethodTeardown)
        function teardownGlobalLogger(testCase)
            % Restore previous thresholds if we captured them.
            if ~isempty(testCase.PreviousSnapshot)
                try
                    csrd.runtime.logger.policy.LogPolicy.restore( ...
                        testCase.PreviousSnapshot);
                catch
                end
            end
            % Hard-reset for isolation of the next test case.
            try
                logger = csrd.runtime.logger.GlobalLogManager.getLogger();
                logger.fcloseLogFile();
            catch
            end
            csrd.runtime.logger.GlobalLogManager.reset();
            % rmdir is best-effort: on Windows the singleton mlog file
            % handle may still hold an exclusive lock for a few ms after
            % reset(), and a lingering temp directory does not invalidate
            % the test outcome.
            if ~isempty(testCase.TempDir) && isfolder(testCase.TempDir)
                try
                    rmdir(testCase.TempDir, 's');
                catch
                end
            end
        end
    end

    methods (Test)
        function applySetsDebugBothChannels(testCase)
            import csrd.runtime.logger.mlog.Level
            policy = csrd.runtime.logger.policy.LogPolicy('Dev');
            testCase.PreviousSnapshot = policy.apply();
            logger = csrd.runtime.logger.GlobalLogManager.getLogger();

            testCase.verifyEqual(logger.CommandWindowThreshold, Level.DEBUG);
            testCase.verifyEqual(logger.FileThreshold, Level.DEBUG);
        end

        function describeReportsExpectedShape(testCase)
            policy = csrd.runtime.logger.policy.LogPolicy('Dev');
            desc = policy.describe();
            testCase.verifyEqual(desc.Level, 'Dev');
            testCase.verifyEqual(desc.ConsoleThreshold, 'DEBUG');
            testCase.verifyEqual(desc.FileThreshold, 'DEBUG');
            testCase.verifyClass(desc.AppliedAt, 'char');
        end

        function debugMessageHitsLogFile(testCase)
            policy = csrd.runtime.logger.policy.LogPolicy('Dev');
            testCase.PreviousSnapshot = policy.apply();
            logger = csrd.runtime.logger.GlobalLogManager.getLogger();

            marker = sprintf('CSRD-DEV-MARKER-%s', char(java.util.UUID.randomUUID));
            logger.debug('phase0 unit-test marker: %s', marker);

            % Force flush by closing the current file handle.
            try
                logger.fcloseLogFile();
            catch
            end

            % Use the logger's own LogFile property to find the active
            % file. Going via dir() of getLogDirectory() is fragile:
            % when two tests fire within the same wall-clock second the
            % singleton reuses an earlier instance whose LogFolder still
            % points at a *deleted* TempDir, so the freshly written
            % bytes land in mlog's tempdir() fallback, not in our
            % session folder.
            logFile = char(logger.LogFile);
            testCase.assertNotEmpty(logFile, ...
                'logger.LogFile must be populated after a debug() call.');
            testCase.assertTrue(isfile(logFile), ...
                sprintf('Expected logger.LogFile to exist on disk: %s', logFile));

            txt = fileread(logFile);
            testCase.verifyTrue(contains(txt, marker), ...
                sprintf(['Dev tier should write debug() lines to the log file. ', ...
                'File=%s, marker=%s'], logFile, marker));
        end

        function caseInsensitiveLevel(testCase)
            p1 = csrd.runtime.logger.policy.LogPolicy('dev');
            p2 = csrd.runtime.logger.policy.LogPolicy('DEV');
            testCase.verifyEqual(p1.Level, p2.Level);
            testCase.verifyEqual(p1.Level, 'Dev');
        end
    end
end
