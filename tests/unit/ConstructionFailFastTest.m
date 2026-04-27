classdef ConstructionFailFastTest < matlab.unittest.TestCase
    %CONSTRUCTIONFAILFASTTEST Phase 3 (§3.2.A / §3.2.B) construction-layer fail-fast.
    %
    %   Pin the fail-fast contract for the buildSegmentConfig +
    %   transmit-impairment construction layer. The legacy magic
    %   defaults (PSK / RandomBit / 100 kHz / 1024 / SamplesPerSymbol=4
    %   in buildSegmentConfig; FrequencyOffset=0 + 2.5*plannedBW
    %   SampleRate derive in processTransmitImpairments) were removed;
    %   any blueprint that reaches the construction layer with a
    %   missing field MUST raise a CSRD:Construction:Missing*
    %   identifier so the planner-side bug is surfaced rather than
    %   silently papered over.
    %
    %   The two helpers under test live as Static, Hidden methods on
    %   csrd.core.ChangShuo so the contract can be exercised without
    %   standing up the full pipeline:
    %
    %     csrd.core.ChangShuo.buildSegmentConfigFromTxScenario(...)
    %     csrd.core.ChangShuo.assertSegmentSignalReadyForImpairments(...)

    properties (Constant)
        FRAME_ID = 7
        TX_ID = "Tx1"
        SEG_IDX = 1
    end

    methods (Test)

        % ---------- buildSegmentConfigFromTxScenario : happy path ------

        function happyPathReturnsPopulatedSegment(testCase)
            tx = ConstructionFailFastTest.makeMinimalTxScenario();
            seg = csrd.core.ChangShuo.buildSegmentConfigFromTxScenario(tx, 1);

            testCase.verifyClass(seg, 'struct');
            testCase.verifyEqual(seg.Message.TypeID, 'RandomBit');
            testCase.verifyEqual(seg.Modulation.TypeID, 'PSK');
            testCase.verifyEqual(seg.Modulation.SymbolRate, 100e3);
            testCase.verifyEqual(seg.Placement.FrequencyOffset, -1.5e6);
            testCase.verifyEqual(seg.Placement.TargetBandwidth, 200e3);
            testCase.verifyEqual(seg.Placement.StartTime, 0);
            testCase.verifyGreaterThan(seg.Placement.Duration, 0);
        end

        % ---------- buildSegmentConfigFromTxScenario : Message ---------

        function missingMessageRaisesMissingMessageConfig(testCase)
            tx = ConstructionFailFastTest.makeMinimalTxScenario();
            tx = rmfield(tx, 'Message');
            f = @() csrd.core.ChangShuo.buildSegmentConfigFromTxScenario(tx, 1);
            testCase.verifyError(f, 'CSRD:Construction:MissingMessageConfig');
        end

        function missingMessageTypeRaisesMissingMessageType(testCase)
            tx = ConstructionFailFastTest.makeMinimalTxScenario();
            tx.Message = rmfield(tx.Message, 'Type');
            f = @() csrd.core.ChangShuo.buildSegmentConfigFromTxScenario(tx, 1);
            testCase.verifyError(f, 'CSRD:Construction:MissingMessageType');
        end

        function missingMessageLengthRaisesMissingMessageLength(testCase)
            tx = ConstructionFailFastTest.makeMinimalTxScenario();
            tx.Message = rmfield(tx.Message, 'Length');
            f = @() csrd.core.ChangShuo.buildSegmentConfigFromTxScenario(tx, 1);
            testCase.verifyError(f, 'CSRD:Construction:MissingMessageLength');
        end

        function nonPositiveMessageLengthRaisesMissingMessageLength(testCase)
            tx = ConstructionFailFastTest.makeMinimalTxScenario();
            tx.Message.Length = 0;
            f = @() csrd.core.ChangShuo.buildSegmentConfigFromTxScenario(tx, 1);
            testCase.verifyError(f, 'CSRD:Construction:MissingMessageLength');
        end

        % ---------- buildSegmentConfigFromTxScenario : Modulation ------

        function missingModulationRaisesMissingModulationConfig(testCase)
            tx = ConstructionFailFastTest.makeMinimalTxScenario();
            tx = rmfield(tx, 'Modulation');
            f = @() csrd.core.ChangShuo.buildSegmentConfigFromTxScenario(tx, 1);
            testCase.verifyError(f, 'CSRD:Construction:MissingModulationConfig');
        end

        function missingModulationTypeRaisesMissingModulationType(testCase)
            tx = ConstructionFailFastTest.makeMinimalTxScenario();
            tx.Modulation = rmfield(tx.Modulation, 'Type');
            f = @() csrd.core.ChangShuo.buildSegmentConfigFromTxScenario(tx, 1);
            testCase.verifyError(f, 'CSRD:Construction:MissingModulationType');
        end

        function missingSymbolRateRaisesMissingModulationSymbolRate(testCase)
            tx = ConstructionFailFastTest.makeMinimalTxScenario();
            tx.Modulation = rmfield(tx.Modulation, 'SymbolRate');
            f = @() csrd.core.ChangShuo.buildSegmentConfigFromTxScenario(tx, 1);
            testCase.verifyError(f, 'CSRD:Construction:MissingModulationSymbolRate');
        end

        function nonPositiveSymbolRateRaisesMissingModulationSymbolRate(testCase)
            tx = ConstructionFailFastTest.makeMinimalTxScenario();
            tx.Modulation.SymbolRate = -1;
            f = @() csrd.core.ChangShuo.buildSegmentConfigFromTxScenario(tx, 1);
            testCase.verifyError(f, 'CSRD:Construction:MissingModulationSymbolRate');
        end

        % ---------- buildSegmentConfigFromTxScenario : ReceiverViews ---

        function missingReceiverViewsRaisesMissingReceiverViews(testCase)
            tx = ConstructionFailFastTest.makeMinimalTxScenario();
            tx = rmfield(tx, 'ReceiverViews');
            f = @() csrd.core.ChangShuo.buildSegmentConfigFromTxScenario(tx, 1);
            testCase.verifyError(f, 'CSRD:Construction:MissingReceiverViews');
        end

        function emptyReceiverViewsRaisesMissingReceiverViews(testCase)
            tx = ConstructionFailFastTest.makeMinimalTxScenario();
            tx.ReceiverViews = struct([]);
            f = @() csrd.core.ChangShuo.buildSegmentConfigFromTxScenario(tx, 1);
            testCase.verifyError(f, 'CSRD:Construction:MissingReceiverViews');
        end

        function missingPlannedBandwidthRaisesMissingPlannedBandwidth(testCase)
            tx = ConstructionFailFastTest.makeMinimalTxScenario();
            tx.Spectrum.PlannedBandwidth = 0;
            f = @() csrd.core.ChangShuo.buildSegmentConfigFromTxScenario(tx, 1);
            testCase.verifyError(f, 'CSRD:Construction:MissingPlannedBandwidth');
        end

        % ---------- buildSegmentConfigFromTxScenario : control flow ----

        function missingTemporalReturnsEmpty(testCase)
            tx = ConstructionFailFastTest.makeMinimalTxScenario();
            tx = rmfield(tx, 'Temporal');
            seg = csrd.core.ChangShuo.buildSegmentConfigFromTxScenario(tx, 1);
            testCase.verifyEmpty(seg);
        end

        function segIdxPastEndReturnsEmpty(testCase)
            tx = ConstructionFailFastTest.makeMinimalTxScenario();
            seg = csrd.core.ChangShuo.buildSegmentConfigFromTxScenario(tx, 99);
            testCase.verifyEmpty(seg);
        end

        % ---------- assertSegmentSignalReadyForImpairments -------------

        function happyPathAssertImpairmentsPasses(testCase)
            seg = ConstructionFailFastTest.makeMinimalSegSignal();
            % Should not throw
            csrd.core.ChangShuo.assertSegmentSignalReadyForImpairments( ...
                seg, testCase.FRAME_ID, testCase.TX_ID, testCase.SEG_IDX);
        end

        function missingFrequencyOffsetRaisesMissingFrequencyOffset(testCase)
            seg = ConstructionFailFastTest.makeMinimalSegSignal();
            seg = rmfield(seg, 'FrequencyOffset');
            f = @() csrd.core.ChangShuo.assertSegmentSignalReadyForImpairments( ...
                seg, testCase.FRAME_ID, testCase.TX_ID, testCase.SEG_IDX);
            testCase.verifyError(f, 'CSRD:Construction:MissingFrequencyOffset');
        end

        function missingSampleRateRaisesMissingSampleRate(testCase)
            seg = ConstructionFailFastTest.makeMinimalSegSignal();
            seg = rmfield(seg, 'SampleRate');
            f = @() csrd.core.ChangShuo.assertSegmentSignalReadyForImpairments( ...
                seg, testCase.FRAME_ID, testCase.TX_ID, testCase.SEG_IDX);
            testCase.verifyError(f, 'CSRD:Construction:MissingSampleRate');
        end

        function nonPositiveSampleRateRaisesMissingSampleRate(testCase)
            seg = ConstructionFailFastTest.makeMinimalSegSignal();
            seg.SampleRate = -1;
            f = @() csrd.core.ChangShuo.assertSegmentSignalReadyForImpairments( ...
                seg, testCase.FRAME_ID, testCase.TX_ID, testCase.SEG_IDX);
            testCase.verifyError(f, 'CSRD:Construction:MissingSampleRate');
        end

        function nonStructSegSignalRaisesMissingSegmentSignalStruct(testCase)
            f = @() csrd.core.ChangShuo.assertSegmentSignalReadyForImpairments( ...
                42, testCase.FRAME_ID, testCase.TX_ID, testCase.SEG_IDX);
            testCase.verifyError(f, 'CSRD:Construction:MissingSegmentSignalStruct');
        end

    end

    methods (Static, Access = private)

        function tx = makeMinimalTxScenario()
            % Returns the smallest possible Phase 3 TxPlan that should
            % survive buildSegmentConfigFromTxScenario without errors.
            tx = struct();
            tx.EntityID = 'Tx1';
            tx.Temporal = struct('Intervals', [0, 0.05]);
            tx.Message = struct('Type', 'RandomBit', 'Length', 1024);
            tx.Modulation = struct( ...
                'Type', 'PSK', 'Order', 4, 'SymbolRate', 100e3, ...
                'SamplesPerSymbol', 4, 'BitsPerSymbol', 2);
            tx.Spectrum = struct( ...
                'PlannedBandwidth', 200e3, 'PlannedFreqOffset', -1.5e6);
            tx.ReceiverViews = struct( ...
                'ReceiverId', 'Rx1', ...
                'ProjectedCenterOffsetHz', -1.5e6, ...
                'ProjectedLowerEdgeHz', -1.6e6, ...
                'ProjectedUpperEdgeHz', -1.4e6, ...
                'IsVisible', true, ...
                'VisibilityReason', 'InBand');
        end

        function seg = makeMinimalSegSignal()
            % Returns the smallest possible Phase 3 segment-signal that
            % should survive assertSegmentSignalReadyForImpairments.
            seg = struct( ...
                'FrequencyOffset', -1.5e6, ...
                'SampleRate', 1.0e6, ...
                'Signal', complex(zeros(8, 1)), ...
                'Bandwidth', 200e3, ...
                'StartTime', 0, ...
                'Duration', 0.05);
        end

    end

end
