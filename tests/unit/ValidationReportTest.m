classdef ValidationReportTest < matlab.unittest.TestCase
    %VALIDATIONREPORTTEST Phase 2 unit tests for the ValidationReport
    %struct returned by csrd.pipeline.blueprint.BlueprintFeasibilityValidator.validate.
    %
    %   Maps to docs/audits/phases/phase-2-blueprint.md §3.3.6 / §5.2.C
    %   ValidationReportTest row.

    methods (Test)

        function emptyBlueprintIsFeasibleWithAllSkipped(testCase)
            % Phase 2 transitional schema: a totally empty blueprint
            % should pass because every check soft-skips when its required
            % field is missing.
            r = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.validate(struct());
            testCase.verifyTrue(r.IsFeasible);
            testCase.verifyEqual(r.NumChecksFailed, 0);
            testCase.verifyEqual(r.NumChecksRun, 20);
            testCase.verifyEqual(r.NumChecksPassed, 20);
        end

        function reportContainsBlueprintHash(testCase)
            r = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.validate(struct());
            testCase.verifyClass(r.BlueprintHash, 'char');
            testCase.verifySize(r.BlueprintHash, [1 16]);
        end

        function singleRejectMakesReportInfeasibleAndPopulatesFailedChecks(testCase)
            bp = struct('Receivers', {{struct( ...
                'SampleRate', 40e6, 'ObservableBandwidth', 80e6)}});
            r = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.validate(bp);
            testCase.verifyFalse(r.IsFeasible);
            testCase.verifyEqual(r.NumChecksFailed, 1);
            testCase.verifyNumElements(r.FailedChecks, 1);
            testCase.verifyEqual(r.FailedChecks(1).Code, 'RxFsEqualsObservableBw');
        end

        function provenanceContainsValidatorVersionAndTimestamp(testCase)
            % Phase 4 (audit §17.6 / S8): the Validator version was
            % bumped from `p3-frozen` to `p4-measurement-doppler-v2`
            % when the MeasurementCompleteness / DopplerSelfConsistency /
            % OverlapAnnotationConsistent checks were promoted from
            % stub to enforced. The exact identifier is tracked in
            % BlueprintFeasibilityValidator.validate; pin it here so a
            % bump always reaches this guard.
            r = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.validate(struct());
            testCase.verifyTrue(isfield(r, 'Provenance'));
            testCase.verifyEqual(r.Provenance.ValidatorVersion, ...
                'p4-measurement-doppler-v2');
            testCase.verifyMatches(r.Provenance.Timestamp, ...
                '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$');
        end

    end
end
