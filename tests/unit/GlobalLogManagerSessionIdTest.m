classdef GlobalLogManagerSessionIdTest < matlab.unittest.TestCase
    % GlobalLogManagerSessionIdTest - guard the shared-session mechanism.
    %
    %   Parallel workers (tools/multi_simulation.*) must be able to write into
    %   ONE session directory via the CSRD_SESSION_ID environment variable,
    %   instead of each process stamping its own second-resolution timestamp
    %   (which scattered a single parallel run across N session_* folders).

    properties
        OutRoot
        PrevSessionId
    end

    methods (TestMethodSetup)
        function setup(testCase)
            testCase.PrevSessionId = getenv('CSRD_SESSION_ID');
            testCase.OutRoot = tempname;
            csrd.runtime.logger.GlobalLogManager.reset();
        end
    end

    methods (TestMethodTeardown)
        function teardown(testCase)
            csrd.runtime.logger.GlobalLogManager.reset();
            setenv('CSRD_SESSION_ID', testCase.PrevSessionId);
            if exist(testCase.OutRoot, 'dir')
                rmdir(testCase.OutRoot, 's');
            end
        end
    end

    methods (Test)

        function honorsSharedSessionId(testCase)
            setenv('CSRD_SESSION_ID', 'shared_run_1234');
            csrd.runtime.logger.GlobalLogManager.reset();
            csrd.runtime.logger.GlobalLogManager.initialize( ...
                localCfg(), testCase.OutRoot);
            logDir = csrd.runtime.logger.GlobalLogManager.getLogDirectory();
            testCase.verifyTrue(contains(logDir, 'session_shared_run_1234'), ...
                sprintf('logDir "%s" must use the shared CSRD_SESSION_ID.', logDir));
        end

        function sanitizesUnsafeSessionId(testCase)
            setenv('CSRD_SESSION_ID', '../../evil id!!');
            csrd.runtime.logger.GlobalLogManager.reset();
            csrd.runtime.logger.GlobalLogManager.initialize( ...
                localCfg(), testCase.OutRoot);
            logDir = csrd.runtime.logger.GlobalLogManager.getLogDirectory();
            testCase.verifyFalse(contains(logDir, '..'), ...
                'A session id must never introduce a path-traversal component.');
            testCase.verifyTrue(contains(logDir, 'session_evilid'), ...
                sprintf('Unsafe chars must be stripped; got "%s".', logDir));
        end

        function fallsBackToTimestampWhenUnset(testCase)
            setenv('CSRD_SESSION_ID', '');
            csrd.runtime.logger.GlobalLogManager.reset();
            csrd.runtime.logger.GlobalLogManager.initialize( ...
                localCfg(), testCase.OutRoot);
            logDir = csrd.runtime.logger.GlobalLogManager.getLogDirectory();
            testCase.verifyNotEmpty(regexp(logDir, 'session_\d{8}_\d{6}', 'once'), ...
                sprintf('Unset id must fall back to a timestamp session; got "%s".', logDir));
        end

    end

end

function cfg = localCfg()
cfg = struct('Level', 'ERROR', 'SaveToFile', false, 'DisplayInConsole', false);
end
