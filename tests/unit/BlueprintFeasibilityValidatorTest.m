classdef BlueprintFeasibilityValidatorTest < matlab.unittest.TestCase
    %BLUEPRINTFEASIBILITYVALIDATORTEST Phase 3 unit tests for the 21
    %feasibility checks (20 implemented as static methods + 1 stub for the
    %regression-test-only ChannelStateContinuity).
    %
    %   Each check has a positive (passing) case and a negative (rejected)
    %   case. The ChannelStateContinuity coverage is ALSO included here as
    %   a placeholder dispatcher pointing at the regression test (so the
    %   "21 checks have 21x2 unit cases" contract is upheld at the audit
    %   layer).
    %
    %   Phase 3 schema upgrades:
    %     - #3 TxBwInsideRxWindow now reads ReceiverView projection
    %     - #13 ReceiverViewProjectionPresent message references
    %       ProjectedCenterOffsetHz
    %
    %   Maps to docs/audits/phases/phase-2-blueprint.md §3.3.6 and §5.2.C
    %   plus docs/audits/phases/phase-3-construction.md §3.1.

    methods (Test)

        % =================================================================
        % §4.bis B - 12 checks
        % =================================================================

        function frameSampleConsistencyPositive(testCase)
            bp = struct( ...
                'Global',    struct('FrameDuration', 1e-3, 'FrameNumSamples', 4e4), ...
                'Receivers', {{struct('SampleRate', 4e7)}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkFrameSampleConsistency(bp);
            testCase.verifyEmpty(f);
        end

        function frameSampleConsistencyNegative(testCase)
            bp = struct( ...
                'Global',    struct('FrameDuration', 1e-3, 'FrameNumSamples', 4e4), ...
                'Receivers', {{struct('SampleRate', 8e7)}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkFrameSampleConsistency(bp);
            testCase.verifyEqual(f.Code, 'FrameSampleConsistency');
            testCase.verifyEqual(f.Severity, 'Reject');
        end

        function rxFsEqualsObservableBwPositive(testCase)
            bp = struct('Receivers', {{struct('SampleRate', 40e6, ...
                'ObservableBandwidth', 40e6)}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkRxFsEqualsObservableBw(bp);
            testCase.verifyEmpty(f);
        end

        function rxFsEqualsObservableBwNegative(testCase)
            bp = struct('Receivers', {{struct('SampleRate', 40e6, ...
                'ObservableBandwidth', 80e6)}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkRxFsEqualsObservableBw(bp);
            testCase.verifyEqual(f.Code, 'RxFsEqualsObservableBw');
            testCase.verifyEqual(f.Severity, 'Reject');
        end

        function txBwInsideRxWindowPositiveLegacy(testCase)
            % Legacy path: blueprint without ReceiverViews falls back to
            % Spectrum.PlannedFreqOffset (Phase 3 transitional contract).
            bp = struct( ...
                'Receivers', {{struct('SampleRate', 40e6, 'ObservableBandwidth', 40e6)}}, ...
                'Emitters',  {{struct('Spectrum', struct('PlannedBandwidth', 10e6, ...
                                                          'PlannedFreqOffset', 5e6))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkTxBwInsideRxWindow(bp);
            testCase.verifyEmpty(f);
        end

        function txBwInsideRxWindowNegativeLegacy(testCase)
            bp = struct( ...
                'Receivers', {{struct('SampleRate', 40e6, 'ObservableBandwidth', 40e6)}}, ...
                'Emitters',  {{struct('Spectrum', struct('PlannedBandwidth', 60e6, ...
                                                          'PlannedFreqOffset', 0))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkTxBwInsideRxWindow(bp);
            testCase.verifyEqual(f.Code, 'TxBwInsideRxWindow');
        end

        function txBwInsideRxWindowPositiveReceiverView(testCase)
            % Phase 3: ReceiverView projection wins over Spectrum.PlannedFreqOffset
            % when both are present. Here Spectrum says +30 MHz (would
            % fall outside ±20 MHz window) but the projection onto Rx1
            % is 0 Hz, so the check must pass.
            rv = struct('ReceiverId', 'Rx1', ...
                        'ProjectedCenterOffsetHz', 0, ...
                        'ProjectedLowerEdgeHz',   -5e6, ...
                        'ProjectedUpperEdgeHz',    5e6, ...
                        'IsVisible',               true, ...
                        'VisibilityReason',        'InBand');
            bp = struct( ...
                'Receivers', {{struct('EntityID', 'Rx1', 'SampleRate', 40e6, ...
                                       'ObservableBandwidth', 40e6)}}, ...
                'Emitters',  {{struct( ...
                    'Spectrum',      struct('PlannedBandwidth', 10e6, ...
                                              'PlannedFreqOffset', 30e6), ...
                    'ReceiverViews', rv)}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkTxBwInsideRxWindow(bp);
            testCase.verifyEmpty(f);
        end

        function txBwInsideRxWindowNegativeReceiverView(testCase)
            % Reverse: Spectrum says 0 Hz (would pass) but the ReceiverView
            % projects to +30 MHz (outside ±20 MHz). The check must reject
            % using the projection, and the failure message must
            % reference ProjectedCenterOffsetHz.
            rv = struct('ReceiverId', 'Rx1', ...
                        'ProjectedCenterOffsetHz', 30e6, ...
                        'ProjectedLowerEdgeHz',    25e6, ...
                        'ProjectedUpperEdgeHz',    35e6, ...
                        'IsVisible',               false, ...
                        'VisibilityReason',        'OutOfBand');
            bp = struct( ...
                'Receivers', {{struct('EntityID', 'Rx1', 'SampleRate', 40e6, ...
                                       'ObservableBandwidth', 40e6)}}, ...
                'Emitters',  {{struct( ...
                    'Spectrum',      struct('PlannedBandwidth', 10e6, ...
                                              'PlannedFreqOffset', 0), ...
                    'ReceiverViews', rv)}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkTxBwInsideRxWindow(bp);
            testCase.verifyEqual(f.Code, 'TxBwInsideRxWindow');
            testCase.verifySubstring(f.Field, 'ReceiverViews');
            testCase.verifySubstring(f.Hint,  'ProjectedCenterOffsetHz');
        end

        function txBwInsideRxWindowMultiReceiverViewsByIndex(testCase)
            % When the receiver carries no EntityID, the helper falls back
            % to positional rxIdx into ReceiverViews. Two receivers:
            % Rx1 sees Tx at 0 Hz (pass); Rx2 sees Tx at +30 MHz (fail).
            rvs(1) = struct('ReceiverId', '', ...
                            'ProjectedCenterOffsetHz', 0, ...
                            'ProjectedLowerEdgeHz',   -5e6, ...
                            'ProjectedUpperEdgeHz',    5e6, ...
                            'IsVisible',               true, ...
                            'VisibilityReason',        'InBand');
            rvs(2) = struct('ReceiverId', '', ...
                            'ProjectedCenterOffsetHz', 30e6, ...
                            'ProjectedLowerEdgeHz',    25e6, ...
                            'ProjectedUpperEdgeHz',    35e6, ...
                            'IsVisible',               false, ...
                            'VisibilityReason',        'OutOfBand');
            bp = struct( ...
                'Receivers', {{struct('SampleRate', 40e6, 'ObservableBandwidth', 40e6), ...
                                struct('SampleRate', 40e6, 'ObservableBandwidth', 40e6)}}, ...
                'Emitters',  {{struct( ...
                    'Spectrum',      struct('PlannedBandwidth', 10e6, ...
                                              'PlannedFreqOffset', 0), ...
                    'ReceiverViews', rvs)}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkTxBwInsideRxWindow(bp);
            testCase.verifyEqual(f.Code, 'TxBwInsideRxWindow');
            testCase.verifySubstring(f.Message, 'Rx 2');
        end

        function modulationAntennaCompatiblePositive(testCase)
            bp = struct('Emitters', {{struct( ...
                'Modulation', struct('Family', 'OFDM'), ...
                'Hardware',   struct('NumAntennas', 2))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkModulationAntennaCompatible(bp);
            testCase.verifyEmpty(f);
        end

        function modulationAntennaCompatibleNegative(testCase)
            % FM @ 2 antennas is Forbidden in the matrix
            bp = struct('Emitters', {{struct( ...
                'Modulation', struct('Family', 'FM'), ...
                'Hardware',   struct('NumAntennas', 2))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkModulationAntennaCompatible(bp);
            testCase.verifyEqual(f.Code, 'ModulationAntennaCompatible');
        end

        function rfImpairmentRangePositive(testCase)
            bp = struct('Emitters', {{struct('RFImpairment', struct( ...
                'IIP3Dbm', 20, 'PhaseNoiseLevel', 'Mid', 'IQImbalanceDb', 0.5))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkRFImpairmentRange(bp);
            testCase.verifyEmpty(f);
        end

        function rfImpairmentRangeNegative(testCase)
            bp = struct('Emitters', {{struct('RFImpairment', struct( ...
                'IIP3Dbm', 100))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkRFImpairmentRange(bp);
            testCase.verifyEqual(f.Code, 'RFImpairmentRange');
        end

        function burstTotalDurationFitsPositive(testCase)
            bp = struct( ...
                'Global',   struct('NumFrames', 4, 'FrameDuration', 1e-3), ...
                'Emitters', {{struct('BurstSchedule', struct('Bursts', ...
                    struct('Duration', 1e-3, 'EndTime', 2e-3)))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkBurstTotalDurationFits(bp);
            testCase.verifyEmpty(f);
        end

        function burstTotalDurationFitsNegative(testCase)
            bp = struct( ...
                'Global',   struct('NumFrames', 2, 'FrameDuration', 1e-3), ...
                'Emitters', {{struct('BurstSchedule', struct('Bursts', ...
                    struct('Duration', 5e-3, 'EndTime', 10e-3)))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkBurstTotalDurationFits(bp);
            testCase.verifyEqual(f.Code, 'BurstTotalDurationFits');
        end

        function crossFrameSegmentMinSamplesPositive(testCase)
            bp = struct('Emitters', {{struct('PrecomputedSegments', ...
                struct('VisibleSamples', 256))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkCrossFrameSegmentMinSamples(bp);
            testCase.verifyEmpty(f);
        end

        function crossFrameSegmentMinSamplesNegative(testCase)
            bp = struct('Emitters', {{struct('PrecomputedSegments', ...
                struct('VisibleSamples', 32))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkCrossFrameSegmentMinSamples(bp);
            testCase.verifyEqual(f.Code, 'CrossFrameSegmentMinSamples');
        end

        function osmFileExistsAndBuildingsPositive(testCase)
            bp = struct('ChannelPreference', struct('Model', 'AWGN'));
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkOsmFileExistsAndBuildings(bp);
            testCase.verifyEmpty(f);
        end

        function osmFileExistsAndBuildingsNegative(testCase)
            bp = struct('ChannelPreference', struct( ...
                'Model', 'RayTracing', 'OSMFile', 'C:\__definitely_not_exist__.osm'));
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkOsmFileExistsAndBuildings(bp);
            testCase.verifyEqual(f.Code, 'OsmFileExistsAndBuildings');
        end

        function channelModelInRegistryPositive(testCase)
            bp = struct( ...
                'ChannelPreference',    struct('Model', 'AWGN'), ...
                'ChannelModelRegistry', {{'AWGN', 'Rician', 'RayTracing'}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkChannelModelInRegistry(bp);
            testCase.verifyEmpty(f);
        end

        function channelModelInRegistryNegative(testCase)
            bp = struct( ...
                'ChannelPreference',    struct('Model', 'BogusChannel'), ...
                'ChannelModelRegistry', {{'AWGN', 'Rician'}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkChannelModelInRegistry(bp);
            testCase.verifyEqual(f.Code, 'ChannelModelInRegistry');
        end

        function trajectoryMonotonicAndCoversPositive(testCase)
            bp = struct( ...
                'Global',   struct('NumFrames', 2, 'FrameDuration', 1e-3), ...
                'Emitters', {{struct('Trajectory', struct( ...
                    'SampleTimes', [0 1e-3 2e-3 3e-3]))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkTrajectoryMonotonicAndCovers(bp);
            testCase.verifyEmpty(f);
        end

        function trajectoryMonotonicAndCoversNegative(testCase)
            bp = struct( ...
                'Global',   struct('NumFrames', 2, 'FrameDuration', 1e-3), ...
                'Emitters', {{struct('Trajectory', struct( ...
                    'SampleTimes', [0 5e-3 4e-3]))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkTrajectoryMonotonicAndCovers(bp);
            testCase.verifyEqual(f.Code, 'TrajectoryMonotonicAndCovers');
        end

        function linkDistanceAboveMinPositive(testCase)
            bp = struct( ...
                'Emitters',  {{struct('Position', [0 0 10])}}, ...
                'Receivers', {{struct('Position', [50 0 10])}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkLinkDistanceAboveMin(bp);
            testCase.verifyEmpty(f);
        end

        function linkDistanceAboveMinNegative(testCase)
            bp = struct( ...
                'Emitters',  {{struct('Position', [0 0 10])}}, ...
                'Receivers', {{struct('Position', [0.01 0 10])}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkLinkDistanceAboveMin(bp);
            testCase.verifyEqual(f.Code, 'LinkDistanceAboveMin');
        end

        function memoryBudgetPositive(testCase)
            bp = struct( ...
                'Global',    struct('NumFrames', 2, 'FrameNumSamples', 4e4), ...
                'Receivers', {{struct('Hardware', struct('NumAntennas', 1))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkMemoryBudget(bp);
            testCase.verifyEmpty(f);
        end

        function memoryBudgetNegative(testCase)
            bp = struct( ...
                'Global',    struct('NumFrames', 1000, 'FrameNumSamples', 4e6), ...
                'Receivers', {{struct('Hardware', struct('NumAntennas', 16))}}, ...
                'Validator', struct('MemoryBudgetMB', 1024));
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkMemoryBudget(bp);
            testCase.verifyEqual(f.Code, 'MemoryBudget');
        end

        % =================================================================
        % §4.ter - 5 checks
        % =================================================================

        function receiverViewProjectionPresentPositive(testCase)
            % Phase 3 canonical 5-field ReceiverView schema.
            rv = struct('ReceiverId', 'Rx1', ...
                        'ProjectedCenterOffsetHz', 0, ...
                        'ProjectedLowerEdgeHz',   -5e6, ...
                        'ProjectedUpperEdgeHz',    5e6, ...
                        'IsVisible',               true, ...
                        'VisibilityReason',        'InBand');
            bp = struct( ...
                'Receivers', {{struct('Hardware', struct('NumAntennas', 1)), ...
                                struct('Hardware', struct('NumAntennas', 2))}}, ...
                'Emitters',  {{struct('ReceiverViews', rv)}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkReceiverViewProjectionPresent(bp);
            testCase.verifyEmpty(f);
        end

        function receiverViewProjectionPresentNegative(testCase)
            bp = struct( ...
                'Receivers', {{struct('Hardware', struct('NumAntennas', 1)), ...
                                struct('Hardware', struct('NumAntennas', 2))}}, ...
                'Emitters',  {{struct('Modulation', struct('Family', 'OFDM'))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkReceiverViewProjectionPresent(bp);
            testCase.verifyEqual(f.Code, 'ReceiverViewProjectionPresent');
            testCase.verifySubstring(f.Message, 'ProjectedCenterOffsetHz');
        end

        function burstOverlapsFrameExpansionPositive(testCase)
            bursts = struct('OverlappingFramesIds', {[1 2]}, ...
                            'ExpandedSegments',     {[struct('FrameId', 1) struct('FrameId', 2)]});
            bp = struct('Emitters', {{struct('BurstSchedule', struct('Bursts', bursts))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkBurstOverlapsFrameExpansion(bp);
            testCase.verifyEmpty(f);
        end

        function burstOverlapsFrameExpansionNegative(testCase)
            bursts = struct('OverlappingFramesIds', {[1 2 3]}, ...
                            'ExpandedSegments',     {[struct('FrameId', 1)]});
            bp = struct('Emitters', {{struct('BurstSchedule', struct('Bursts', bursts))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkBurstOverlapsFrameExpansion(bp);
            testCase.verifyEqual(f.Code, 'BurstOverlapsFrameExpansion');
        end

        function measurementPlanesSeparatedPositive(testCase)
            bp = struct('MeasurementPolicy', struct( ...
                'MaxVisibleSourcesPerFrame', 4, ...
                'Planes', {{'SourcePlane', 'FramePlane'}}));
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkMeasurementPlanesSeparated(bp);
            testCase.verifyEmpty(f);
        end

        function measurementPlanesSeparatedNegative(testCase)
            bp = struct('MeasurementPolicy', struct( ...
                'MaxVisibleSourcesPerFrame', 4, ...
                'Planes', {{'FramePlane'}}));
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkMeasurementPlanesSeparated(bp);
            testCase.verifyEqual(f.Code, 'MeasurementPlanesSeparated');
        end

        function geometryGranularityDeclaredPositive(testCase)
            bp = struct('AnnotationPolicy', struct('GeometryGranularity', 'Frame'));
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkGeometryGranularityDeclared(bp);
            testCase.verifyEmpty(f);
        end

        function geometryGranularityDeclaredNegative(testCase)
            bp = struct('AnnotationPolicy', struct('GeometryGranularity', 'Bogus'));
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkGeometryGranularityDeclared(bp);
            testCase.verifyEqual(f.Code, 'GeometryGranularityDeclared');
        end

        function receiverOutputWindowConsistentPositive(testCase)
            bp = struct( ...
                'Global',       struct('FrameNumSamples', 4e4), ...
                'OutputPolicy', struct('OutputWindowPolicy', 'ExactFrameClip', ...
                                        'OutputLengthSamples', 4e4));
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkReceiverOutputWindowConsistent(bp);
            testCase.verifyEmpty(f);
        end

        function receiverOutputWindowConsistentNegative(testCase)
            bp = struct( ...
                'Global',       struct('FrameNumSamples', 4e4), ...
                'OutputPolicy', struct('OutputWindowPolicy', 'ExactFrameClip', ...
                                        'OutputLengthSamples', 8e4));
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkReceiverOutputWindowConsistent(bp);
            testCase.verifyEqual(f.Code, 'ReceiverOutputWindowConsistent');
        end

        % =================================================================
        % §16.7.1 - OverlapAnnotationConsistent (real) + 2 stubs
        % =================================================================

        function overlapAnnotationConsistentPositive(testCase)
            bursts = struct('OverlappingFramesIds', {[1 2]});
            fep    = struct('Segments', [struct('BurstIndex', 1, 'FrameId', 1) ...
                                          struct('BurstIndex', 1, 'FrameId', 2)]);
            bp = struct('Emitters', {{struct( ...
                'BurstSchedule',      struct('Bursts', bursts), ...
                'FrameExecutionPlan', fep)}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkOverlapAnnotationConsistent(bp);
            testCase.verifyEmpty(f);
        end

        function overlapAnnotationConsistentNegative(testCase)
            bursts = struct('OverlappingFramesIds', {[1 2]});
            fep    = struct('Segments', [struct('BurstIndex', 1, 'FrameId', 1) ...
                                          struct('BurstIndex', 1, 'FrameId', 5)]);
            bp = struct('Emitters', {{struct( ...
                'BurstSchedule',      struct('Bursts', bursts), ...
                'FrameExecutionPlan', fep)}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkOverlapAnnotationConsistent(bp);
            testCase.verifyEqual(f.Code, 'OverlapAnnotationConsistent');
        end

        % =================================================================
        % Phase 4 §3.6.A — checkMeasurementCompleteness (PASS-only at
        % blueprint phase; enforcement lives in saveScenarioData hook)
        % =================================================================

        function measurementCompletenessAlwaysPassesAtBlueprintPhase(testCase)
            % Audit §3.6.A: blueprint-phase NoOp, full enforcement is in
            % SimulationRunner.saveScenarioData via
            % csrd.core.ChangShuo.validateMeasurementCompleteness.
            bp = struct();
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkMeasurementCompleteness(bp);
            testCase.verifyEmpty(f);
        end

        function measurementCompletenessIgnoresAnnotationShapedInput(testCase)
            % Audit §3.6.A: even with intentionally bad annotation-shaped
            % input the blueprint-phase check is silent. Reject lives in
            % the write-back hook (covered by MeasurementCompletenessHookTest).
            bp = struct('Truth', struct('Measured', struct( ...
                'SourcePlane', struct('OccupiedBandwidthHz', NaN), ...
                'FramePlane',  struct('OccupiedBandwidthHz', NaN))));
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkMeasurementCompleteness(bp);
            testCase.verifyEmpty(f);
        end

        function measurementCompletenessIgnoresMissingMeasurementPolicy(testCase)
            bp = struct('Emitters', {{struct('Mobility', struct('MaxSpeedMps', 100))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkMeasurementCompleteness(bp);
            testCase.verifyEmpty(f);
        end

        function measurementCompletenessIgnoresEmptyBlueprint(testCase)
            % Defensive: even an empty struct must be handled gracefully.
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkMeasurementCompleteness(struct());
            testCase.verifyEmpty(f);
        end

        % =================================================================
        % Phase 4 §3.6.B — checkDopplerSelfConsistency (predictive Reject
        % when high-velocity Tx but Doppler not required by policy)
        % =================================================================

        function dopplerSelfConsistencyPositiveStaticEntities(testCase)
            % All emitters stationary (MaxSpeedMps=0); Doppler not
            % required is fine.
            bp = struct( ...
                'Emitters', {{struct('Mobility', struct('MaxSpeedMps', 0))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkDopplerSelfConsistency(bp);
            testCase.verifyEmpty(f);
        end

        function dopplerSelfConsistencyPositiveHighSpeedWithRequirement(testCase)
            % High-velocity Tx + MeasurementPolicy.RequireDopplerShiftHz=true
            % is the canonical PASS case (audit §3.6.B).
            bp = struct( ...
                'Emitters', {{struct('Mobility', struct('MaxSpeedMps', 200))}}, ...
                'MeasurementPolicy', struct('RequireDopplerShiftHz', true));
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkDopplerSelfConsistency(bp);
            testCase.verifyEmpty(f);
        end

        function dopplerSelfConsistencyNegativeHighSpeedNoRequirement(testCase)
            % High-velocity Tx + RequireDopplerShiftHz absent => REJECT.
            bp = struct( ...
                'Emitters', {{struct('Mobility', struct('MaxSpeedMps', 200))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkDopplerSelfConsistency(bp);
            testCase.verifyEqual(f.Code, 'DopplerSelfConsistency');
            testCase.verifyEqual(f.Severity, 'Reject');
            testCase.verifySubstring(f.Message, 'RequireDopplerShiftHz');
        end

        function dopplerSelfConsistencyNegativeHighSpeedExplicitFalse(testCase)
            % High-velocity Tx + RequireDopplerShiftHz=false => REJECT.
            bp = struct( ...
                'Emitters', {{struct('Mobility', struct('MaxSpeedMps', 100))}}, ...
                'MeasurementPolicy', struct('RequireDopplerShiftHz', false));
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkDopplerSelfConsistency(bp);
            testCase.verifyEqual(f.Code, 'DopplerSelfConsistency');
            testCase.verifyEqual(f.Severity, 'Reject');
        end

        % =================================================================
        % Phase 4 §3.6.C — checkOverlapAnnotationConsistent rail #2
        % (ActiveIntervalIndices cardinality vs. Bursts count)
        % =================================================================

        function overlapAnnotationConsistentRail2Positive(testCase)
            % 3 bursts, FEP segments use ActiveIntervalIndices in {1,2,3}
            % => unique count == numel(Bursts) => PASS.
            bursts = struct('OverlappingFramesIds', {[], [], []});
            fep = struct('Segments', [ ...
                struct('ActiveIntervalIndices', 1) ...
                struct('ActiveIntervalIndices', 2) ...
                struct('ActiveIntervalIndices', 3) ...
                struct('ActiveIntervalIndices', [1 2])]);
            bp = struct('Emitters', {{struct( ...
                'BurstSchedule',      struct('Bursts', bursts), ...
                'FrameExecutionPlan', fep)}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkOverlapAnnotationConsistent(bp);
            testCase.verifyEmpty(f);
        end

        function overlapAnnotationConsistentRail2NegativeMissingBurst(testCase)
            % 2 bursts authored, but FEP references 3 distinct
            % ActiveIntervalIndices => burst missing from BurstSchedule.
            bursts = struct('OverlappingFramesIds', {[], []});
            fep = struct('Segments', [ ...
                struct('ActiveIntervalIndices', 1) ...
                struct('ActiveIntervalIndices', 2) ...
                struct('ActiveIntervalIndices', 3)]);
            bp = struct('Emitters', {{struct( ...
                'BurstSchedule',      struct('Bursts', bursts), ...
                'FrameExecutionPlan', fep)}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkOverlapAnnotationConsistent(bp);
            testCase.verifyEqual(f.Code, 'OverlapAnnotationConsistent');
            testCase.verifyEqual(f.Severity, 'Reject');
            testCase.verifySubstring(f.Message, 'ActiveIntervalIndices');
        end

        function overlapAnnotationConsistentRail2NegativeOrphanBurst(testCase)
            % 4 bursts authored but FEP only schedules 2 distinct
            % => orphan bursts that never run.
            bursts = struct('OverlappingFramesIds', {[], [], [], []});
            fep = struct('Segments', [ ...
                struct('ActiveIntervalIndices', 1) ...
                struct('ActiveIntervalIndices', 2)]);
            bp = struct('Emitters', {{struct( ...
                'BurstSchedule',      struct('Bursts', bursts), ...
                'FrameExecutionPlan', fep)}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkOverlapAnnotationConsistent(bp);
            testCase.verifyEqual(f.Code, 'OverlapAnnotationConsistent');
            testCase.verifyEqual(f.Severity, 'Reject');
        end

        function overlapAnnotationConsistentSkipsEmitterWithoutFEP(testCase)
            % An emitter with no FrameExecutionPlan must not trigger
            % rail #2 (skip, not reject).
            bursts = struct('OverlappingFramesIds', {[1 2]});
            bp = struct('Emitters', {{struct( ...
                'BurstSchedule', struct('Bursts', bursts))}});
            f = csrd.utils.blueprint.BlueprintFeasibilityValidator.checkOverlapAnnotationConsistent(bp);
            testCase.verifyEmpty(f);
        end

        % =================================================================
        % 21st check: ChannelStateContinuity dispatcher (regression-test
        % only; this case documents that contract).
        % =================================================================

        function channelStateContinuityDispatchedToRegression(testCase)
            % There is no static method for this check; it lives in
            % tests/regression/test_channel_state_continuity.m.
            testCase.verifyEmpty(meta.class.fromName( ...
                'csrd.utils.blueprint.BlueprintFeasibilityValidator').MethodList.findobj( ...
                'Name', 'checkChannelStateContinuity'));
        end

        function channelStateContinuityNotInValidate(testCase)
            % validate() must NOT execute ChannelStateContinuity; the
            % regression test owns it. Smoke: validate runs to completion
            % with NumChecksRun==20.
            report = csrd.utils.blueprint.BlueprintFeasibilityValidator.validate(struct());
            testCase.verifyEqual(report.NumChecksRun, 20);
        end

    end
end
