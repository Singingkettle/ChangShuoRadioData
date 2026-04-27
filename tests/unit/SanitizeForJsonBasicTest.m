classdef SanitizeForJsonBasicTest < matlab.unittest.TestCase
    %SANITIZEFORJSONBASICTEST Phase 0 unit tests covering scalar coercion
    %rules in csrd.utils.annotation.sanitizeForJson.
    %
    %   Each test case asserts both the cleaned value AND the manifest
    %   entry, because Phase 4 will lean on the manifest as a stable
    %   provenance contract (audit §17.2).

    methods (Test)
        function passesThroughPlainNumbers(testCase)
            [clean, manifest] = csrd.utils.annotation.sanitizeForJson(3.14);
            testCase.verifyEqual(clean, 3.14);
            testCase.verifyEmpty(manifest.Entries);
        end

        function passesThroughChar(testCase)
            [clean, manifest] = csrd.utils.annotation.sanitizeForJson('hello');
            testCase.verifyEqual(clean, 'hello');
            testCase.verifyEmpty(manifest.Entries);
        end

        function nanScalarBecomesNullByDefault(testCase)
            [clean, manifest] = csrd.utils.annotation.sanitizeForJson(NaN);
            testCase.verifyTrue(isempty(clean));   % null in JSON
            testCase.verifyEqual(numel(manifest.Entries), 1);
            testCase.verifyEqual(manifest.Entries(1).Reason, 'NaN->null');
            testCase.verifyEqual(manifest.NumericPolicy, 'null');
        end

        function nanScalarBecomesStringWhenPolicyIsString(testCase)
            opts = struct('NumericPolicy', 'string');
            [clean, manifest] = csrd.utils.annotation.sanitizeForJson(NaN, opts);
            testCase.verifyEqual(clean, 'NaN');
            testCase.verifyEqual(manifest.Entries(1).Reason, 'NaN->null');
            testCase.verifyEqual(manifest.NumericPolicy, 'string');
        end

        function positiveInfBecomesNull(testCase)
            [clean, manifest] = csrd.utils.annotation.sanitizeForJson(Inf);
            testCase.verifyTrue(isempty(clean));
            testCase.verifyEqual(manifest.Entries(1).Reason, '+Inf->null');
        end

        function negativeInfBecomesNull(testCase)
            [clean, manifest] = csrd.utils.annotation.sanitizeForJson(-Inf);
            testCase.verifyTrue(isempty(clean));
            testCase.verifyEqual(manifest.Entries(1).Reason, '-Inf->null');
        end

        function complexScalarBecomesStruct(testCase)
            z = 1 + 2i;
            [clean, manifest] = csrd.utils.annotation.sanitizeForJson(z);
            testCase.verifyEqual(clean.Real, 1);
            testCase.verifyEqual(clean.Imag, 2);
            testCase.verifyEqual(manifest.Entries(1).Reason, ...
                'complex->struct(Real,Imag)');
        end

        function functionHandleBecomesText(testCase)
            f = @(x) x.^2;
            [clean, manifest] = csrd.utils.annotation.sanitizeForJson(f);
            testCase.verifyEqual(clean, '@(x)x.^2');
            testCase.verifyEqual(manifest.Entries(1).Reason, ...
                'function_handle->char');
        end

        function datetimeBecomesIso8601(testCase)
            dt = datetime(2026, 4, 24, 12, 30, 0, 'TimeZone', 'UTC');
            [clean, manifest] = csrd.utils.annotation.sanitizeForJson(dt);
            testCase.verifyEqual(clean, '2026-04-24T12:30:00Z');
            testCase.verifyEqual(manifest.Entries(1).Reason, ...
                'datetime->iso8601');
        end

        function durationBecomesSeconds(testCase)
            d = duration(0, 5, 30);
            [clean, manifest] = csrd.utils.annotation.sanitizeForJson(d);
            testCase.verifyEqual(clean, 330);
            testCase.verifyEqual(manifest.Entries(1).Reason, ...
                'duration->seconds');
        end

        function jsonOutputIsParsable(testCase)
            % Belt-and-braces: the cleaned struct must round-trip
            % through jsonencode -> jsondecode without throwing.
            payload = struct( ...
                'good',    3.14, ...
                'bad_nan', NaN, ...
                'bad_inf', Inf, ...
                'bad_z',   1 + 2i);
            [clean, ~] = csrd.utils.annotation.sanitizeForJson(payload);
            txt = jsonencode(clean);
            decoded = jsondecode(txt);
            testCase.verifyEqual(decoded.good, 3.14);
            testCase.verifyTrue(isempty(decoded.bad_nan));
            testCase.verifyTrue(isempty(decoded.bad_inf));
            testCase.verifyEqual(decoded.bad_z.Real, 1);
            testCase.verifyEqual(decoded.bad_z.Imag, 2);
        end
    end
end
