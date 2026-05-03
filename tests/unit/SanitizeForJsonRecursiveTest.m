classdef SanitizeForJsonRecursiveTest < matlab.unittest.TestCase
    %SANITIZEFORJSONRECURSIVETEST Phase 0 unit tests covering the
    %recursive descent into nested structs, struct arrays, cells, and
    %containers.Map.

    methods (Test)
        function nestedStructIsCleanedRecursively(testCase)
            payload.outer = struct( ...
                'inner',     struct( ...
                    'a',     NaN, ...
                    'b',     1 + 2i), ...
                'sibling',   'ok');
            [clean, manifest] = csrd.pipeline.annotation.sanitizeForJson(payload);

            testCase.verifyTrue(isempty(clean.outer.inner.a));
            testCase.verifyEqual(clean.outer.inner.b.Real, 1);
            testCase.verifyEqual(clean.outer.inner.b.Imag, 2);
            testCase.verifyEqual(clean.outer.sibling, 'ok');

            paths = {manifest.Entries.Path};
            testCase.verifyTrue(any(strcmp(paths, 'outer.inner.a')));
            testCase.verifyTrue(any(strcmp(paths, 'outer.inner.b')));
        end

        function structArrayPreservesShape(testCase)
            payload(1).x = NaN;
            payload(2).x = 7;
            payload(3).x = Inf;
            [clean, manifest] = csrd.pipeline.annotation.sanitizeForJson(payload);

            testCase.verifyEqual(numel(clean), 3);
            testCase.verifyTrue(isempty(clean(1).x));
            testCase.verifyEqual(clean(2).x, 7);
            testCase.verifyTrue(isempty(clean(3).x));

            paths = {manifest.Entries.Path};
            testCase.verifyTrue(any(strcmp(paths, '[1].x')));
            testCase.verifyTrue(any(strcmp(paths, '[3].x')));
        end

        function cellArrayIsCleanedElementWise(testCase)
            payload = {1, NaN, struct('z', Inf), 'literal'};
            [clean, manifest] = csrd.pipeline.annotation.sanitizeForJson(payload);
            testCase.verifyEqual(clean{1}, 1);
            testCase.verifyTrue(isempty(clean{2}));
            testCase.verifyTrue(isempty(clean{3}.z));
            testCase.verifyEqual(clean{4}, 'literal');

            paths = {manifest.Entries.Path};
            testCase.verifyTrue(any(strcmp(paths, '{2}')));
            testCase.verifyTrue(any(strcmp(paths, '{3}.z')));
        end

        function containersMapBecomesStruct(testCase)
            m = containers.Map( ...
                {'alpha', 'beta'}, {NaN, 42});
            payload.config = m;
            [clean, manifest] = csrd.pipeline.annotation.sanitizeForJson(payload);
            testCase.verifyTrue(isstruct(clean.config));
            testCase.verifyTrue(isempty(clean.config.alpha));
            testCase.verifyEqual(clean.config.beta, 42);

            reasons = {manifest.Entries.Reason};
            testCase.verifyTrue(any(strcmp(reasons, ...
                'containers.Map->struct')));
        end

        function deeplyNestedJsonRoundTrips(testCase)
            payload = struct( ...
                'level1', struct( ...
                    'level2', struct( ...
                        'level3', struct( ...
                            'leafNan', NaN, ...
                            'leafComplex', 3 - 4i))));
            [clean, ~] = csrd.pipeline.annotation.sanitizeForJson(payload);
            txt = jsonencode(clean);
            d = jsondecode(txt);
            testCase.verifyTrue(isempty(d.level1.level2.level3.leafNan));
            testCase.verifyEqual(d.level1.level2.level3.leafComplex.Real, 3);
            testCase.verifyEqual(d.level1.level2.level3.leafComplex.Imag, -4);
        end

        function maxDepthClipsRecursion(testCase)
            % Build a struct with depth >= 5; clip to 3 to verify the
            % truncation marker shows up.
            payload = struct('a', struct('b', struct('c', struct('d', 'leaf'))));
            opts = struct('MaxDepth', uint32(3));
            [clean, manifest] = csrd.pipeline.annotation.sanitizeForJson( ...
                payload, opts);

            % Walk down and check that one of the leaves is the
            % truncation marker. The exact path depends on the
            % traversal order; we just assert *somewhere* in the
            % manifest there's a depth-cap entry.
            reasons = {manifest.Entries.Reason};
            testCase.verifyTrue(any(strcmp(reasons, 'depth-cap')), ...
                'Expected at least one depth-cap entry in manifest.');

            txt = jsonencode(clean);
            testCase.verifyTrue(contains(txt, 'truncated:depth>3'), ...
                'Expected truncation sentinel in the cleaned JSON.');
        end

        function manifestSchemaIsStable(testCase)
            payload.x = NaN;
            [~, manifest] = csrd.pipeline.annotation.sanitizeForJson(payload);
            testCase.verifyEqual(manifest.Schema, 'csrd.sanitize-manifest.v1');
            testCase.verifyTrue(isfield(manifest, 'NumericPolicy'));
            testCase.verifyTrue(isfield(manifest, 'Entries'));
            testCase.verifyTrue(isfield(manifest.Entries, 'Path'));
            testCase.verifyTrue(isfield(manifest.Entries, 'OriginalClass'));
            testCase.verifyTrue(isfield(manifest.Entries, 'Reason'));
            testCase.verifyTrue(isfield(manifest.Entries, 'NewType'));
        end
    end
end
