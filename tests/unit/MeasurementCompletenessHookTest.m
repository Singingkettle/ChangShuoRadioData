classdef MeasurementCompletenessHookTest < matlab.unittest.TestCase
    %MEASUREMENTCOMPLETENESSHOOKTEST Phase 4 §S7 / C4 fail-fast unit tests.
    %
    %   Pins the contract that
    %   `csrd.core.ChangShuo.validateMeasurementCompleteness` raises
    %   on a missing `SignalSources` field, missing v2 top-level key,
    %   missing `Truth.{Design,Execution,Measured}` namespace, missing
    %   `Truth.Measured.{SourcePlane,FramePlane}` sub-struct, and
    %   missing required SourcePlane / FramePlane scalar key.
    %
    %   Identifiers asserted:
    %       CSRD:Annotation:SchemaIncomplete        - structural skeleton
    %       CSRD:Annotation:MeasurementIncomplete   - measurement payload
    %
    %   The hook accepts NaN / [] (post-sanitize null) values; absence
    %   of the field itself is what triggers the fail-fast. This mirrors
    %   the Phase 4 §7 risk note that legitimately-unmeasurable scalars
    %   stay NaN and do NOT fail validation.

    methods (Test)

        function emptyAnnotationFailsWithSchemaIncomplete(testCase)
            errorRaised = false;
            try
                csrd.core.ChangShuo.validateMeasurementCompleteness([]);
            catch ME
                errorRaised = true;
                testCase.verifyEqual(ME.identifier, ...
                    'CSRD:Annotation:SchemaIncomplete', ...
                    'Empty annotation must raise SchemaIncomplete.');
            end
            testCase.verifyTrue(errorRaised, ...
                'Empty annotation must raise an error.');
        end

        function annotationWithoutSignalSourcesFailsWithSchemaIncomplete(testCase)
            annotation = struct();
            annotation.Header = struct('Runtime', struct('ScenarioId', 1));
            annotation.Frames = struct('SomeOtherField', 42);
            errorRaised = false;
            try
                csrd.core.ChangShuo.validateMeasurementCompleteness(annotation);
            catch ME
                errorRaised = true;
                testCase.verifyEqual(ME.identifier, ...
                    'CSRD:Annotation:SchemaIncomplete', ...
                    ['An annotation tree without any SignalSources ', ...
                     'must raise SchemaIncomplete.']);
            end
            testCase.verifyTrue(errorRaised, ...
                'Annotation without SignalSources must raise an error.');
        end

        function missingTopLevelTxIdFailsWithSchemaIncomplete(testCase)
            annotation = makeValidAnnotation();
            annotation.Frames.SignalSources = ...
                rmfield(annotation.Frames.SignalSources, 'TxID');
            errorRaised = false;
            try
                csrd.core.ChangShuo.validateMeasurementCompleteness(annotation);
            catch ME
                errorRaised = true;
                testCase.verifyEqual(ME.identifier, ...
                    'CSRD:Annotation:SchemaIncomplete', ...
                    'Missing TxID must raise SchemaIncomplete.');
            end
            testCase.verifyTrue(errorRaised, ...
                'Missing TxID must raise an error.');
        end

        function missingReceiverViewFailsWithSchemaIncomplete(testCase)
            annotation = makeValidAnnotation();
            annotation.Frames.SignalSources = ...
                rmfield(annotation.Frames.SignalSources, 'ReceiverView');
            errorRaised = false;
            try
                csrd.core.ChangShuo.validateMeasurementCompleteness(annotation);
            catch ME
                errorRaised = true;
                testCase.verifyEqual(ME.identifier, ...
                    'CSRD:Annotation:SchemaIncomplete', ...
                    'Missing ReceiverView must raise SchemaIncomplete.');
            end
            testCase.verifyTrue(errorRaised, ...
                'Missing ReceiverView must raise an error.');
        end

        function missingTruthDesignFailsWithSchemaIncomplete(testCase)
            annotation = makeValidAnnotation();
            annotation.Frames.SignalSources(1).Truth = ...
                rmfield(annotation.Frames.SignalSources(1).Truth, 'Design');
            errorRaised = false;
            try
                csrd.core.ChangShuo.validateMeasurementCompleteness(annotation);
            catch ME
                errorRaised = true;
                testCase.verifyEqual(ME.identifier, ...
                    'CSRD:Annotation:SchemaIncomplete', ...
                    'Missing Truth.Design must raise SchemaIncomplete.');
            end
            testCase.verifyTrue(errorRaised, ...
                'Missing Truth.Design must raise an error.');
        end

        function missingMeasuredSourcePlaneFailsWithMeasurementIncomplete(testCase)
            annotation = makeValidAnnotation();
            annotation.Frames.SignalSources(1).Truth.Measured = ...
                rmfield(annotation.Frames.SignalSources(1).Truth.Measured, ...
                    'SourcePlane');
            errorRaised = false;
            try
                csrd.core.ChangShuo.validateMeasurementCompleteness(annotation);
            catch ME
                errorRaised = true;
                testCase.verifyEqual(ME.identifier, ...
                    'CSRD:Annotation:MeasurementIncomplete', ...
                    ['Missing Truth.Measured.SourcePlane must raise ', ...
                     'MeasurementIncomplete.']);
            end
            testCase.verifyTrue(errorRaised, ...
                'Missing SourcePlane must raise an error.');
        end

        function missingSourcePlaneOccupiedBwFailsWithMeasurementIncomplete(testCase)
            annotation = makeValidAnnotation();
            annotation.Frames.SignalSources(1).Truth.Measured.SourcePlane = ...
                rmfield(annotation.Frames.SignalSources(1).Truth.Measured.SourcePlane, ...
                    'OccupiedBandwidthHz');
            errorRaised = false;
            try
                csrd.core.ChangShuo.validateMeasurementCompleteness(annotation);
            catch ME
                errorRaised = true;
                testCase.verifyEqual(ME.identifier, ...
                    'CSRD:Annotation:MeasurementIncomplete', ...
                    ['Missing SourcePlane.OccupiedBandwidthHz must raise ', ...
                     'MeasurementIncomplete.']);
            end
            testCase.verifyTrue(errorRaised, ...
                'Missing OccupiedBandwidthHz must raise an error.');
        end

        function missingFramePlaneFailsWithMeasurementIncomplete(testCase)
            annotation = makeValidAnnotation();
            annotation.Frames.SignalSources(1).Truth.Measured = ...
                rmfield(annotation.Frames.SignalSources(1).Truth.Measured, ...
                    'FramePlane');
            errorRaised = false;
            try
                csrd.core.ChangShuo.validateMeasurementCompleteness(annotation);
            catch ME
                errorRaised = true;
                testCase.verifyEqual(ME.identifier, ...
                    'CSRD:Annotation:MeasurementIncomplete', ...
                    ['Missing Truth.Measured.FramePlane must raise ', ...
                     'MeasurementIncomplete.']);
            end
            testCase.verifyTrue(errorRaised, ...
                'Missing FramePlane must raise an error.');
        end

        function missingFramePlaneFreqOccupancyFailsWithMeasurementIncomplete(testCase)
            annotation = makeValidAnnotation();
            annotation.Frames.SignalSources(1).Truth.Measured.FramePlane = ...
                rmfield(annotation.Frames.SignalSources(1).Truth.Measured.FramePlane, ...
                    'FrequencyOccupancy');
            errorRaised = false;
            try
                csrd.core.ChangShuo.validateMeasurementCompleteness(annotation);
            catch ME
                errorRaised = true;
                testCase.verifyEqual(ME.identifier, ...
                    'CSRD:Annotation:MeasurementIncomplete', ...
                    ['Missing FramePlane.FrequencyOccupancy must raise ', ...
                     'MeasurementIncomplete.']);
            end
            testCase.verifyTrue(errorRaised, ...
                'Missing FramePlane.FrequencyOccupancy must raise an error.');
        end

        function nanOnSourcePlaneOnlyIsAcceptedWhenFrameFinite(testCase)
            % Audit §3.7.D test (c): at-least-one-finite rule — when one
            % plane is NaN/null but the other publishes a finite value
            % the source still counts as measured.
            annotation = makeValidAnnotation();
            annotation.Frames.SignalSources(1).Truth.Measured.SourcePlane.OccupiedBandwidthHz = NaN;
            annotation.Frames.SignalSources(1).Truth.Measured.SourcePlane.FrequencyOccupancy = NaN;
            csrd.core.ChangShuo.validateMeasurementCompleteness(annotation);
            testCase.verifyTrue(true, ...
                ['NaN on SourcePlane.OccupiedBandwidthHz must be accepted ', ...
                 'when FramePlane.OccupiedBandwidthHz is finite.']);
        end

        function nullSentinelOnFrameOnlyIsAcceptedWhenSourceFinite(testCase)
            % Audit §3.7.D test (c) post-sanitize variant: NaN -> []
            % after sanitizeForJson, but the at-least-one-finite rule
            % still passes because SourcePlane.OccupiedBandwidthHz is
            % finite.
            annotation = makeValidAnnotation();
            annotation.Frames.SignalSources(1).Truth.Measured.FramePlane.OccupiedBandwidthHz = [];
            csrd.core.ChangShuo.validateMeasurementCompleteness(annotation);
            testCase.verifyTrue(true, ...
                ['Null sentinel on FramePlane must be accepted when ', ...
                 'SourcePlane is finite (post-sanitize semantics).']);
        end

        function bothPlanesNanFailsWithMeasurementIncomplete(testCase)
            % Audit §3.7.D test (b): when BOTH planes have NaN
            % OccupiedBandwidthHz the source is NOT measured anywhere
            % and the hook MUST fail-fast.
            annotation = makeValidAnnotation();
            annotation.Frames.SignalSources(1).Truth.Measured.SourcePlane.OccupiedBandwidthHz = NaN;
            annotation.Frames.SignalSources(1).Truth.Measured.FramePlane.OccupiedBandwidthHz = NaN;
            errorRaised = false;
            try
                csrd.core.ChangShuo.validateMeasurementCompleteness(annotation);
            catch ME
                errorRaised = true;
                testCase.verifyEqual(ME.identifier, ...
                    'CSRD:Annotation:MeasurementIncomplete', ...
                    ['Both planes NaN must raise MeasurementIncomplete ', ...
                     '(audit §3.7.D test (b)).']);
            end
            testCase.verifyTrue(errorRaised, ...
                'Both planes NaN must raise an error.');
        end

        function bothPlanesEmptyFailsPostSanitize(testCase)
            % Audit §3.7.D test (b) post-sanitize variant: NaN -> []
            % both planes -> reject.
            annotation = makeValidAnnotation();
            annotation.Frames.SignalSources(1).Truth.Measured.SourcePlane.OccupiedBandwidthHz = [];
            annotation.Frames.SignalSources(1).Truth.Measured.FramePlane.OccupiedBandwidthHz = [];
            errorRaised = false;
            try
                csrd.core.ChangShuo.validateMeasurementCompleteness(annotation);
            catch ME
                errorRaised = true;
                testCase.verifyEqual(ME.identifier, ...
                    'CSRD:Annotation:MeasurementIncomplete');
            end
            testCase.verifyTrue(errorRaised, ...
                'Both planes [] must raise an error post-sanitize.');
        end

        function negativeOccupiedBwOnBothPlanesFails(testCase)
            % Negative bandwidth is not physical; treated as not-finite
            % per the helper, so both-plane negative -> reject.
            annotation = makeValidAnnotation();
            annotation.Frames.SignalSources(1).Truth.Measured.SourcePlane.OccupiedBandwidthHz = -1;
            annotation.Frames.SignalSources(1).Truth.Measured.FramePlane.OccupiedBandwidthHz = -1;
            errorRaised = false;
            try
                csrd.core.ChangShuo.validateMeasurementCompleteness(annotation);
            catch ME
                errorRaised = true;
                testCase.verifyEqual(ME.identifier, ...
                    'CSRD:Annotation:MeasurementIncomplete');
            end
            testCase.verifyTrue(errorRaised, ...
                'Negative OccupiedBandwidthHz on both planes must reject.');
        end

        function fullyValidAnnotationDoesNotRaise(testCase)
            annotation = makeValidAnnotation();
            csrd.core.ChangShuo.validateMeasurementCompleteness(annotation);
            testCase.verifyTrue(true, ...
                'A fully-valid annotation must NOT raise any error.');
        end

        function skipExceptionPredicateRejectsAnnotationToken(testCase)
            % Phase 20: annotation contract failures are hard failures, not
            % successful scenario skips.
            annotation = struct('Header', struct(), 'Frames', struct( ...
                'SomeOtherField', 42));
            isSkip = false;
            try
                csrd.core.ChangShuo.validateMeasurementCompleteness(annotation);
            catch ME
                isSkip = csrd.pipeline.scenario.isScenarioSkipException(ME);
            end
            testCase.verifyFalse(isSkip, ...
                'CSRD:Annotation:* identifiers must count as failed scenarios.');
        end

        function skipExceptionPredicateRejectsMeasurementToken(testCase)
            % Phase 20: measurement helper failures expose signal/label
            % inconsistency and must not be hidden as skips.
            try
                error('CSRD:Measurement:InvalidSignal', ...
                    'Synthetic measurement failure for predicate test.');
            catch ME
                isSkip = csrd.pipeline.scenario.isScenarioSkipException(ME);
            end
            testCase.verifyFalse(isSkip, ...
                'CSRD:Measurement:* identifiers must count as failed scenarios.');
        end

    end

end

% =========================================================================
function annotation = makeValidAnnotation()
    %MAKEVALIDANNOTATION Build a minimal v2-schema annotation skeleton.
    src = struct();
    src.TxID = 'Tx_001';
    src.SegmentId = 'Seg_001';
    src.BurstId = 'Brst_001';
    src.Truth = struct();
    src.Truth.Design = struct( ...
        'PlannedCenterFrequencyHz', 1e6, ...
        'PlannedBandwidthHz', 200e3, ...
        'PlannedSampleRate', 1e6, ...
        'ModulationFamily', 'PSK', ...
        'ModulationOrder', 4, ...
        'MessageSource', 'RandomBit', ...
        'IsDigital', true, ...
        'PayloadLengthBits', 1024, ...
        'NumTransmitAntennas', 1);
    src.Truth.Execution = struct( ...
        'ModulatedBandwidthHz', 200e3, ...
        'CenterFrequencyOffsetHz', 1e6, ...
        'SampleRate', 1e6, ...
        'ChannelModel', 'AWGN', ...
        'PathLossDB', 60, ...
        'AnalyticalSNRdB', 20, ...
        'AppliedSNRdB', 19.5, ...
        'DopplerShiftHz', 0, ...
        'RadialVelocityMps', 0, ...
        'GeometrySnapshot', struct( ...
            'TxPositionM', [0, 0, 0], ...
            'TxVelocityMps', [0, 0, 0], ...
            'RxPositionM', [100, 0, 0], ...
            'RxVelocityMps', [0, 0, 0], ...
            'LinkDistanceM', 100));
    src.Truth.Measured = struct();
    src.Truth.Measured.SourcePlane = struct( ...
        'OccupiedBandwidthHz', 195e3, ...
        'CenterFrequencyHz', 1.001e6, ...
        'SNRdB', 19.5, ...
        'TimeOccupancy', 0.95, ...
        'FrequencyOccupancy', 0.2, ...
        'MeasurementSemantics', 'receiver_view_isolated');
    src.Truth.Measured.FramePlane = struct( ...
        'OccupiedBandwidthHz', 195e3, ...
        'CenterFrequencyHz', 1.001e6, ...
        'TimeOccupancy', 0.95, ...
        'FrequencyOccupancy', 0.2, ...
        'MeasurementSemantics', 'post_rx_combined_pre_rfchain');
    src.RFImpairments = struct('Type', 'none');
    src.ReceiverView = struct( ...
        'ReceiverId', 'Rx_001', ...
        'ProjectedCenterOffsetHz', 1e6, ...
        'ProjectedLowerEdgeHz', 0.9e6, ...
        'ProjectedUpperEdgeHz', 1.1e6, ...
        'IsVisible', true, ...
        'VisibilityReason', 'WithinObservableWindow');

    annotation = struct();
    annotation.Header = struct('Runtime', struct('ScenarioId', 1));
    annotation.Frames = struct();
    annotation.Frames.SignalSources = src;
end
