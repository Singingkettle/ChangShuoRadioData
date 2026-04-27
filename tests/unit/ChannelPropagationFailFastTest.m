classdef ChannelPropagationFailFastTest < matlab.unittest.TestCase
    %CHANNELPROPAGATIONFAILFASTTEST Phase 3 (§3.2.C) channel propagation strict checks.
    %
    %   processChannelPropagation walked through a three-tier
    %   SampleRate fallback (channel -> segment -> rxInfo) and
    %   silently echoed `channelOutput.Planned` back into the
    %   per-component annotation in Phase 1/2. Both behaviours hid
    %   ChannelFactory bugs and were removed in Phase 3:
    %
    %     * SampleRate now MUST come from `channelOutput.SampleRate`;
    %       otherwise CSRD:Construction:ChannelMissingSampleRate is
    %       raised.
    %     * `component.Planned` is copied only from the segmentSignal
    %       record set by processSingleSegment; the
    %       channel block's Planned echo was deleted from
    %       processChannelPropagation, so any annotation
    %       Planned.{Bandwidth,FrequencyOffset} reflects the
    %       modulator-side planning record (audit §3.1.ter A).
    %
    %   The first contract is enforced by the Static, Hidden helper
    %   csrd.core.ChangShuo.assertChannelOutputSampleRate, which is
    %   exercised here directly. The second contract is enforced by
    %   `test_no_dead_code_phase3` (grep `channelOutput.Planned` 0
    %   hits in processChannelPropagation.m); we ALSO add a textual
    %   guard here so the contract is visible at unit-test time.

    properties (Constant)
        FRAME_ID = 9
        TX_ID = "Tx1"
        RX_ID = "Rx1"
        SEG_IDX = 1
    end

    methods (Test)

        function happyPathSampleRatePasses(testCase)
            channelOutput = struct('Signal', complex(zeros(4, 1)), ...
                'SampleRate', 1.0e6, 'Bandwidth', 200e3);
            % Should not throw
            csrd.core.ChangShuo.assertChannelOutputSampleRate( ...
                channelOutput, testCase.FRAME_ID, testCase.TX_ID, ...
                testCase.RX_ID, testCase.SEG_IDX);
        end

        function missingSampleRateRaisesChannelMissingSampleRate(testCase)
            channelOutput = struct('Signal', complex(zeros(4, 1)), ...
                'Bandwidth', 200e3);
            f = @() csrd.core.ChangShuo.assertChannelOutputSampleRate( ...
                channelOutput, testCase.FRAME_ID, testCase.TX_ID, ...
                testCase.RX_ID, testCase.SEG_IDX);
            testCase.verifyError(f, 'CSRD:Construction:ChannelMissingSampleRate');
        end

        function nonPositiveSampleRateRaisesChannelMissingSampleRate(testCase)
            channelOutput = struct('Signal', complex(zeros(4, 1)), ...
                'SampleRate', 0, 'Bandwidth', 200e3);
            f = @() csrd.core.ChangShuo.assertChannelOutputSampleRate( ...
                channelOutput, testCase.FRAME_ID, testCase.TX_ID, ...
                testCase.RX_ID, testCase.SEG_IDX);
            testCase.verifyError(f, 'CSRD:Construction:ChannelMissingSampleRate');
        end

        function emptySampleRateRaisesChannelMissingSampleRate(testCase)
            channelOutput = struct('Signal', complex(zeros(4, 1)), ...
                'SampleRate', [], 'Bandwidth', 200e3);
            f = @() csrd.core.ChangShuo.assertChannelOutputSampleRate( ...
                channelOutput, testCase.FRAME_ID, testCase.TX_ID, ...
                testCase.RX_ID, testCase.SEG_IDX);
            testCase.verifyError(f, 'CSRD:Construction:ChannelMissingSampleRate');
        end

        function nonStructChannelOutputRaisesChannelMissingSampleRate(testCase)
            f = @() csrd.core.ChangShuo.assertChannelOutputSampleRate( ...
                42, testCase.FRAME_ID, testCase.TX_ID, ...
                testCase.RX_ID, testCase.SEG_IDX);
            testCase.verifyError(f, 'CSRD:Construction:ChannelMissingSampleRate');
        end

        function plannedPassthroughIsRemovedFromProcessChannelPropagation(testCase)
            % Phase 3 (§3.2.C): ChannelFactory MUST NOT echo a
            % `Planned` field into the per-component annotation.
            % We grep the production file to make sure no future
            % refactor accidentally re-introduces the passthrough.
            here = fileparts(mfilename('fullpath'));
            target = fullfile(here, '..', '..', '+csrd', '+core', '@ChangShuo', ...
                'private', 'processChannelPropagation.m');
            target = char(java.io.File(target).getCanonicalPath());
            text = fileread(target);
            code = regexprep(text, '%[^\n\r]*', '');
            testCase.verifyNotEmpty(regexp(code, ...
                'component\.Planned\s*=\s*segmentSignal\.Planned', 'once'), ...
                ['processChannelPropagation.m must pass the upstream ', ...
                 'segmentSignal.Planned design truth to the receiver ', ...
                 'component for annotation v2.']);
            % Forbidden patterns: any assignment of component.Planned
            % from channelOutput.Planned.
            forbidden = {'component.Planned = channelOutput.Planned', ...
                'component.Planned=channelOutput.Planned'};
            for k = 1:numel(forbidden)
                testCase.verifyEqual(strfind(text, forbidden{k}), [], ...
                    sprintf(['processChannelPropagation.m must not echo ', ...
                             'channelOutput.Planned (forbidden pattern: %s).'], ...
                            forbidden{k}));
            end
        end

        function lookupReceiverViewOffsetMissingReceiverViewsRaises(testCase)
            txCfg = struct('EntityID', 'Tx1');
            rxInfo = struct('ID', 'Rx1');
            channelOutput = struct('SampleRate', 1.0e6);
            f = @() csrd.core.ChangShuo.lookupReceiverViewOffset( ...
                txCfg, rxInfo, 1, channelOutput);
            testCase.verifyError(f, 'CSRD:Construction:MissingReceiverViews');
        end

        function lookupReceiverViewOffsetMatchesByReceiverId(testCase)
            txCfg = struct('EntityID', 'Tx1');
            txCfg.ReceiverViews(1) = struct( ...
                'ReceiverId', 'Rx1', 'ProjectedCenterOffsetHz', -2.5e6, ...
                'ProjectedLowerEdgeHz', -2.6e6, 'ProjectedUpperEdgeHz', -2.4e6, ...
                'IsVisible', true, 'VisibilityReason', 'InBand');
            txCfg.ReceiverViews(2) = struct( ...
                'ReceiverId', 'Rx2', 'ProjectedCenterOffsetHz', 3.5e6, ...
                'ProjectedLowerEdgeHz', 3.4e6, 'ProjectedUpperEdgeHz', 3.6e6, ...
                'IsVisible', true, 'VisibilityReason', 'InBand');
            rxInfo = struct('ID', 'Rx2');
            channelOutput = struct('SampleRate', 1.0e6);
            offset = csrd.core.ChangShuo.lookupReceiverViewOffset( ...
                txCfg, rxInfo, 1, channelOutput);
            testCase.verifyEqual(offset, 3.5e6);
        end

        function lookupReceiverViewOffsetFallsBackOnIndexWhenIdMissing(testCase)
            txCfg = struct('EntityID', 'Tx1');
            % ReceiverId fields intentionally left empty so the
            % positional fallback fires.
            txCfg.ReceiverViews(1) = struct( ...
                'ReceiverId', '', 'ProjectedCenterOffsetHz', -2.5e6, ...
                'ProjectedLowerEdgeHz', -2.6e6, 'ProjectedUpperEdgeHz', -2.4e6, ...
                'IsVisible', true, 'VisibilityReason', 'InBand');
            txCfg.ReceiverViews(2) = struct( ...
                'ReceiverId', '', 'ProjectedCenterOffsetHz', 3.5e6, ...
                'ProjectedLowerEdgeHz', 3.4e6, 'ProjectedUpperEdgeHz', 3.6e6, ...
                'IsVisible', true, 'VisibilityReason', 'InBand');
            rxInfo = struct('ID', 'Rx2');
            channelOutput = struct('SampleRate', 1.0e6);
            offset = csrd.core.ChangShuo.lookupReceiverViewOffset( ...
                txCfg, rxInfo, 2, channelOutput);
            testCase.verifyEqual(offset, 3.5e6);
        end

        function lookupReceiverViewOffsetIndexOutOfRangeRaises(testCase)
            txCfg = struct('EntityID', 'Tx1');
            txCfg.ReceiverViews(1) = struct( ...
                'ReceiverId', '', 'ProjectedCenterOffsetHz', -2.5e6, ...
                'ProjectedLowerEdgeHz', -2.6e6, 'ProjectedUpperEdgeHz', -2.4e6, ...
                'IsVisible', true, 'VisibilityReason', 'InBand');
            rxInfo = struct('ID', 'Rx2');
            channelOutput = struct('SampleRate', 1.0e6);
            f = @() csrd.core.ChangShuo.lookupReceiverViewOffset( ...
                txCfg, rxInfo, 5, channelOutput);
            testCase.verifyError(f, 'CSRD:Construction:ReceiverViewIndexOutOfRange');
        end

    end

end
