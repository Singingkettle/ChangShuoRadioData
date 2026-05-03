classdef AnnotationHeaderBlueprintProvenanceTest < matlab.unittest.TestCase
    %ANNOTATIONHEADERBLUEPRINTPROVENANCETEST Phase 2 (audit C4) contract
    %tests for the BlueprintHash / BlueprintResamples / ValidatorVersion
    %fields under Header.Runtime in the persisted scenario annotation.
    %
    %   Maps to docs/audits/phases/phase-2-blueprint.md §3.4 / §7.C4.
    %
    %   The contract is owned by the Hidden static helper
    %   csrd.SimulationRunner.injectBlueprintProvenance which
    %   stampRuntimeHeader delegates to. Targeting the helper directly
    %   keeps the unit test fast and decoupled from the matlab.System
    %   setup chain. End-to-end coverage (sweep -> annotation file)
    %   lives in tests/regression/test_baseline_sweep_200.

    methods (TestMethodSetup)
        function silenceLogger(~)
            try
                csrd.runtime.logger.GlobalLogManager.setLevel('error');
            catch
            end
        end
    end

    methods (Test)

        function provenanceFieldsAreAlwaysWritten(testCase)
            provenance = struct( ...
                'BlueprintHash', 'abc123def4567890', ...
                'BlueprintResamples', 3, ...
                'ValidatorVersion', 'p2-frozen');
            runtimeHeader = struct('LegacyKey', 1);
            stamped = csrd.SimulationRunner.injectBlueprintProvenance( ...
                runtimeHeader, provenance);

            testCase.verifyEqual(stamped.BlueprintHash, 'abc123def4567890');
            testCase.verifyEqual(stamped.BlueprintResamples, 3);
            testCase.verifyEqual(stamped.ValidatorVersion, 'p2-frozen');
            % Phase 0 / Phase 1 keys must survive untouched.
            testCase.verifyEqual(stamped.LegacyKey, 1);
        end

        function emptyProvenanceCollapsesToCanonicalDefaults(testCase)
            stamped = csrd.SimulationRunner.injectBlueprintProvenance( ...
                struct(), struct( ...
                    'BlueprintHash', '', 'BlueprintResamples', 0, ...
                    'ValidatorVersion', ''));
            testCase.verifyEqual(stamped.BlueprintHash, '');
            testCase.verifyEqual(stamped.BlueprintResamples, 0);
            testCase.verifyEqual(stamped.ValidatorVersion, '');
        end

        function nonStringBlueprintHashIsCoercedSafely(testCase)
            % A struct value for BlueprintHash collapses to '' rather
            % than crashing the annotation-save path.
            stamped = csrd.SimulationRunner.injectBlueprintProvenance( ...
                struct(), struct( ...
                    'BlueprintHash', struct('weird', 1), ...
                    'BlueprintResamples', NaN, ...
                    'ValidatorVersion', []));
            testCase.verifyEqual(stamped.BlueprintHash, '');
            testCase.verifyEqual(stamped.BlueprintResamples, 0);
            testCase.verifyEqual(stamped.ValidatorVersion, '');
        end

        function infiniteResamplesCollapseToZero(testCase)
            for badValue = {Inf, -Inf, NaN, 'string-not-number', [1 2 3]}
                bv = badValue{1};
                stamped = csrd.SimulationRunner.injectBlueprintProvenance( ...
                    struct(), struct( ...
                        'BlueprintHash', 'h', ...
                        'BlueprintResamples', bv, ...
                        'ValidatorVersion', 'v'));
                testCase.verifyEqual(stamped.BlueprintResamples, 0, ...
                    sprintf('value class=%s did not collapse to 0', class(bv)));
            end
        end

        function missingProvenanceArgumentDefaultsToEmpty(testCase)
            stamped = csrd.SimulationRunner.injectBlueprintProvenance(struct());
            testCase.verifyTrue(isfield(stamped, 'BlueprintHash'));
            testCase.verifyTrue(isfield(stamped, 'BlueprintResamples'));
            testCase.verifyTrue(isfield(stamped, 'ValidatorVersion'));
            testCase.verifyEqual(stamped.BlueprintHash, '');
            testCase.verifyEqual(stamped.BlueprintResamples, 0);
            testCase.verifyEqual(stamped.ValidatorVersion, '');
        end

        function stringScalarBlueprintHashIsAccepted(testCase)
            stamped = csrd.SimulationRunner.injectBlueprintProvenance( ...
                struct(), struct( ...
                    'BlueprintHash', string('abcdef0123456789'), ...
                    'BlueprintResamples', 2, ...
                    'ValidatorVersion', string('p2-frozen')));
            testCase.verifyEqual(stamped.BlueprintHash, 'abcdef0123456789');
            testCase.verifyEqual(stamped.ValidatorVersion, 'p2-frozen');
        end

        function nonStructProvenanceArgumentIsTreatedAsEmpty(testCase)
            % If a misbehaving caller passes a numeric or empty value
            % for the provenance struct, the helper still produces the
            % canonical defaults rather than throwing.
            stamped = csrd.SimulationRunner.injectBlueprintProvenance( ...
                struct(), 42);
            testCase.verifyEqual(stamped.BlueprintHash, '');
            testCase.verifyEqual(stamped.BlueprintResamples, 0);
            testCase.verifyEqual(stamped.ValidatorVersion, '');
        end

    end
end
