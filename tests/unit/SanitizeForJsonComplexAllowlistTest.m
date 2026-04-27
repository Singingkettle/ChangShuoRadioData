classdef SanitizeForJsonComplexAllowlistTest < matlab.unittest.TestCase
    %SANITIZEFORJSONCOMPLEXALLOWLISTTEST Phase 0 unit tests covering
    %the value-class allowlist for sanitizeForJson.
    %
    %   The audit (§16.10) defines an explicit list of "exotic" classes
    %   that the helper must coerce rather than throw on. This file
    %   exercises each one and asserts that:
    %     - The cleaned output is jsonencode-safe (round-trip works).
    %     - The manifest records the coercion with a stable Reason key.

    methods (Test)
        function complexArrayBecomesStruct(testCase)
            z = [1 + 2i, 3 + 4i; 5 - 6i, 7 + 8i];
            [clean, manifest] = csrd.utils.annotation.sanitizeForJson(z);
            testCase.verifyEqual(size(clean.Real), size(z));
            testCase.verifyEqual(clean.Real, real(z));
            testCase.verifyEqual(clean.Imag, imag(z));
            txt = jsonencode(clean);
            d = jsondecode(txt);
            testCase.verifyEqual(size(d.Real), size(z));
            reasons = {manifest.Entries.Reason};
            testCase.verifyTrue(any(strcmp(reasons, ...
                'complex->struct(Real,Imag)')));
        end

        function nanInfArrayBecomesCell(testCase)
            x = [1, NaN, 3, Inf, -Inf, 6];
            [clean, manifest] = csrd.utils.annotation.sanitizeForJson(x);
            testCase.verifyClass(clean, 'cell');
            testCase.verifyEqual(clean{1}, 1);
            testCase.verifyTrue(isempty(clean{2}));
            testCase.verifyEqual(clean{3}, 3);
            testCase.verifyTrue(isempty(clean{4}));
            testCase.verifyTrue(isempty(clean{5}));
            testCase.verifyEqual(clean{6}, 6);

            reasons = {manifest.Entries.Reason};
            testCase.verifyTrue(any(strcmp(reasons, 'NaN/Inf-array->cell')));
        end

        function stringScalarBecomesChar(testCase)
            s = "hello";
            [clean, ~] = csrd.utils.annotation.sanitizeForJson(s);
            testCase.verifyClass(clean, 'char');
            testCase.verifyEqual(clean, 'hello');
        end

        function stringMissingBecomesNull(testCase)
            s = string(missing);
            [clean, manifest] = csrd.utils.annotation.sanitizeForJson(s);
            testCase.verifyTrue(isempty(clean));
            reasons = {manifest.Entries.Reason};
            testCase.verifyTrue(any(strcmp(reasons, 'missing->null')));
        end

        function categoricalBecomesText(testCase)
            c = categorical({'cat1', 'cat2', 'cat1'});
            [clean, manifest] = csrd.utils.annotation.sanitizeForJson(c);
            testCase.verifyClass(clean, 'cell');
            testCase.verifyEqual(clean, {'cat1', 'cat2', 'cat1'});
            reasons = {manifest.Entries.Reason};
            testCase.verifyTrue(any(strcmp(reasons, 'categorical->text')));
        end

        function mexceptionBecomesStruct(testCase)
            try
                error('CSRD:SanitizeForJsonTest:Synthetic', ...
                    'synthetic error for unit test');
            catch ME
                [clean, manifest] = csrd.utils.annotation.sanitizeForJson(ME);
            end
            % First confirm the cleaned value is a scalar struct so the
            % subsequent field accesses are well-defined.
            testCase.assertClass(clean, 'struct');
            testCase.assertTrue(isscalar(clean));
            testCase.assertTrue(isfield(clean, 'Identifier'));
            testCase.assertTrue(isfield(clean, 'Message'));
            testCase.assertTrue(isfield(clean, 'Stack'));

            % Use isequal rather than verifyEqual or strcmp: in
            % R2025a, calling verifyEqual with a char value that
            % contains a colon makes the framework try to interpret
            % it as a name-value pair. isequal is the safe comparator.
            idOk = isequal(clean.Identifier, ...
                'CSRD:SanitizeForJsonTest:Synthetic');
            msgOk = isequal(clean.Message, ...
                'synthetic error for unit test');
            testCase.verifyTrue(idOk, ...
                'Identifier mismatch in sanitised MException');
            testCase.verifyTrue(msgOk, ...
                'Message mismatch in sanitised MException');
            testCase.verifyClass(clean.Stack, 'cell');

            reasons = {manifest.Entries.Reason};
            hasMex = false;
            for k = 1:numel(reasons)
                if isequal(reasons{k}, 'mexception->struct')
                    hasMex = true;
                    break;
                end
            end
            testCase.verifyTrue(hasMex, ...
                'manifest must record mexception->struct coercion');
        end

        function unsupportedClassFallsThroughGracefully(testCase)
            % Use a graphics handle as an "exotic" class jsonencode
            % would otherwise choke on. We expect the helper to coerce
            % to a sentinel rather than throw.
            f = figure('Visible', 'off');
            cleanup = onCleanup(@() close(f));
            try
                [clean, manifest] = csrd.utils.annotation.sanitizeForJson(f);
            catch sanitizeErr
                testCase.verifyFail(sprintf( ...
                    'Helper should not throw on unknown classes: %s', ...
                    sanitizeErr.message));
                return;
            end
            testCase.verifyClass(clean, 'char');
            testCase.verifyTrue(startsWith(clean, '<unsupported:'));
            reasons = {manifest.Entries.Reason};
            testCase.verifyTrue(any(strcmp(reasons, 'unsupported-class')));
        end

        function badNumericPolicyRaises(testCase)
            opts = struct('NumericPolicy', 'mystery-mode');
            testCase.verifyError(@() csrd.utils.annotation.sanitizeForJson( ...
                NaN, opts), 'CSRD:Phase0:SanitizeBadOption');
        end
    end
end
