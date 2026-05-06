classdef LoggerHotPathNoDbstackTest < matlab.unittest.TestCase
    %LOGGERHOTPATHNODBSTACKTEST Phase 21 logger filtered-path contract.

    methods (Test)

        function filteredDebugDoesNotFormatInvalidSprintf(testCase)
            import csrd.runtime.logger.mlog.Level
            logger = csrd.runtime.logger.mlog.Logger( ...
                "CSRD-Phase21-LoggerHotPath-Test");
            logger.FileThreshold = Level.ERROR;
            logger.CommandWindowThreshold = Level.ERROR;
            logger.MessageReceivedEventThreshold = Level.ERROR;

            testCase.verifyEmpty(logger.debug('%d %d', 1), ...
                ['Filtered debug() must return empty without invoking ', ...
                 'sprintf or caller stack resolution.']);
        end

        function filteredExceptionDoesNotConvertReport(testCase)
            import csrd.runtime.logger.mlog.Level
            logger = csrd.runtime.logger.mlog.Logger( ...
                "CSRD-Phase21-LoggerHotPath-Exception-Test");
            logger.FileThreshold = Level.ERROR;
            logger.CommandWindowThreshold = Level.ERROR;
            logger.MessageReceivedEventThreshold = Level.ERROR;

            cause = MException('CSRD:Phase21:FilteredDebugProbe', ...
                'This exception must not be formatted when DEBUG is dropped.');
            msg = logger.write(Level.DEBUG, cause);
            testCase.verifyEmpty(msg);
        end

    end
end
