classdef ComputeBlueprintHashTest < matlab.unittest.TestCase
    %COMPUTEBLUEPRINTHASHTEST Phase 2 unit tests for
    %csrd.pipeline.blueprint.computeBlueprintHash.
    %
    %   Maps to docs/audits/phases/phase-2-blueprint.md §3.2.5 (8 cases).

    methods (Test)

        function roundTripBytewiseEqual(testCase)
            bp = struct( ...
                'Receiver', struct('SampleRateHz', 40e6, 'NumAntennas', 2), ...
                'Emitters', struct('Bandwidth', 20e6, 'Modulation', 'QAM'));
            h1 = csrd.pipeline.blueprint.computeBlueprintHash(bp);
            h2 = csrd.pipeline.blueprint.computeBlueprintHash(bp);
            testCase.verifyEqual(h2, h1);
            testCase.verifySize(h1, [1 16]);
            testCase.verifyMatches(h1, '^[0-9a-f]{16}$');
        end

        function fieldOrderIsInvariant(testCase)
            s1 = struct(); s1.A = 1; s1.B = 2;
            s2 = struct(); s2.B = 2; s2.A = 1;
            h1 = csrd.pipeline.blueprint.computeBlueprintHash(s1);
            h2 = csrd.pipeline.blueprint.computeBlueprintHash(s2);
            testCase.verifyEqual(h2, h1);
        end

        function nestedStructValueChangeChangesHash(testCase)
            % NOTE: 0.1+0.2 != 0.3 exactly in IEEE-754. Documented in
            % phase-2-blueprint.md §3.2.5 case 3.
            s1 = struct('outer', struct('val', 0.1 + 0.2));
            s2 = struct('outer', struct('val', 0.3));
            h1 = csrd.pipeline.blueprint.computeBlueprintHash(s1);
            h2 = csrd.pipeline.blueprint.computeBlueprintHash(s2);
            testCase.verifyNotEqual(h2, h1);
        end

        function cellVsVectorDistinguished(testCase)
            % {1,2,3} (heterogeneous container) and [1 2 3] (numeric vector)
            % must hash to different digests so cell metadata is not silently
            % collapsed.
            h1 = csrd.pipeline.blueprint.computeBlueprintHash({1, 2, 3});
            h2 = csrd.pipeline.blueprint.computeBlueprintHash([1 2 3]);
            testCase.verifyNotEqual(h2, h1);
        end

        function nanThrowsHashFailed(testCase)
            bp = struct('val', NaN);
            testCase.verifyError( ...
                @() csrd.pipeline.blueprint.computeBlueprintHash(bp), ...
                'CSRD:Blueprint:HashFailed');
        end

        function infThrowsHashFailed(testCase)
            bp = struct('val', Inf);
            testCase.verifyError( ...
                @() csrd.pipeline.blueprint.computeBlueprintHash(bp), ...
                'CSRD:Blueprint:HashFailed');
        end

        function complexThrowsHashFailed(testCase)
            bp = struct('val', complex(1, 1));
            testCase.verifyError( ...
                @() csrd.pipeline.blueprint.computeBlueprintHash(bp), ...
                'CSRD:Blueprint:HashFailed');
        end

        function containersMapThrowsHashFailed(testCase)
            m = containers.Map({'a','b'}, {1, 2});
            bp = struct('mapField', m);
            testCase.verifyError( ...
                @() csrd.pipeline.blueprint.computeBlueprintHash(bp), ...
                'CSRD:Blueprint:HashFailed');
        end

        % ---- additional safety-net tests ----

        function logicalAndIntegerAreDistinguished(testCase)
            % logical true should not hash equal to numeric 1
            h1 = csrd.pipeline.blueprint.computeBlueprintHash(true);
            h2 = csrd.pipeline.blueprint.computeBlueprintHash(1);
            testCase.verifyNotEqual(h2, h1);
        end

        function singleAndDoubleAreDistinguished(testCase)
            h1 = csrd.pipeline.blueprint.computeBlueprintHash(single(1.5));
            h2 = csrd.pipeline.blueprint.computeBlueprintHash(1.5);
            testCase.verifyNotEqual(h2, h1);
        end

        function emptyArrayHasStableHash(testCase)
            h1 = csrd.pipeline.blueprint.computeBlueprintHash([]);
            h2 = csrd.pipeline.blueprint.computeBlueprintHash([]);
            testCase.verifyEqual(h2, h1);
            % And it should differ from an empty cell:
            h3 = csrd.pipeline.blueprint.computeBlueprintHash({});
            testCase.verifyNotEqual(h3, h1);
        end

        function structArrayHashIsStable(testCase)
            sa = struct('x', {1, 2, 3}, 'y', {'a','b','c'});
            h1 = csrd.pipeline.blueprint.computeBlueprintHash(sa);
            h2 = csrd.pipeline.blueprint.computeBlueprintHash(sa);
            testCase.verifyEqual(h2, h1);
        end

    end
end
