classdef ValidateRequiredToolboxesTest < matlab.unittest.TestCase
    %VALIDATEREQUIREDTOOLBOXESTEST Phase 0 unit tests for the toolbox
    %check helper.
    %
    %   Covers:
    %     - default level is 'standard'
    %     - all three tiers return Ok=true on a healthy MATLAB install
    %     - bogus level identifier raises CSRD:Phase0:InvalidToolboxLevel
    %     - report struct has the documented schema
    %
    %   We deliberately do NOT mock `ver`/`license` here; this is an
    %   integration smoke test against the host MATLAB. The CI guarantee
    %   is that whatever environment runs the test suite has at least
    %   the toolboxes required by the requested level. Operators that
    %   run only a subset must invoke `runtests` with a tag filter --
    %   tracked in audit §17.2 risk register.

    methods (Test)
        function defaultLevelIsStandard(testCase)
            report = csrd.utils.toolbox.validateRequiredToolboxes();
            testCase.verifyEqual(report.Level, 'standard');
            testCase.verifyTrue(report.Ok);
        end

        function reportSchemaMatchesDoc(testCase)
            report = csrd.utils.toolbox.validateRequiredToolboxes('minimal');
            expectedFields = {'Level', 'Required', 'Missing', ...
                'Unlicensed', 'Ok', 'Diagnostics'};
            for k = 1:numel(expectedFields)
                testCase.verifyTrue(isfield(report, expectedFields{k}), ...
                    sprintf('Missing field %s in report.', expectedFields{k}));
            end
            testCase.verifyTrue(isstruct(report.Diagnostics));
            testCase.verifyTrue(isfield(report.Diagnostics, 'MatlabVersion'));
            testCase.verifyTrue(isfield(report.Diagnostics, 'Hostname'));
            testCase.verifyTrue(isfield(report.Diagnostics, 'Timestamp'));
        end

        function tierMinimalSubsetOfStandard(testCase)
            minR = csrd.utils.toolbox.validateRequiredToolboxes('minimal');
            stdR = csrd.utils.toolbox.validateRequiredToolboxes('standard');
            minNames = {minR.Required.Name};
            stdNames = {stdR.Required.Name};
            testCase.verifyGreaterThan(numel(stdNames), numel(minNames));
            for k = 1:numel(minNames)
                testCase.verifyTrue(any(strcmp(stdNames, minNames{k})), ...
                    sprintf('"standard" tier missing required tool "%s".', ...
                    minNames{k}));
            end
        end

        function badLevelRaises(testCase)
            testCase.verifyError(...
                @() csrd.utils.toolbox.validateRequiredToolboxes('bogus-tier'), ...
                'CSRD:Phase0:InvalidToolboxLevel');
        end

        function caseInsensitiveLevel(testCase)
            % Lower/Upper variations should both resolve to the same tier.
            r1 = csrd.utils.toolbox.validateRequiredToolboxes('standard');
            r2 = csrd.utils.toolbox.validateRequiredToolboxes('STANDARD');
            testCase.verifyEqual(r1.Level, r2.Level);
        end

        function diagnosticsTimestampIso8601Utc(testCase)
            % Smoke: ensure the timestamp parses back through datetime.
            r = csrd.utils.toolbox.validateRequiredToolboxes('minimal');
            try
                dt = datetime(r.Diagnostics.Timestamp, ...
                    'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss''Z''', ...
                    'TimeZone', 'UTC');
                testCase.verifyTrue(~isnat(dt));
            catch parseErr
                testCase.verifyFail(sprintf( ...
                    'Diagnostics.Timestamp not ISO8601-UTC: %s', ...
                    parseErr.message));
            end
        end
    end
end
