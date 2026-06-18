function signalsAtReceivers = processChannelPropagation(obj, FrameId, txsSignalSegments, TxInfos, RxInfos)
    % processChannelPropagation - Apply channel effects to transmitted signals
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    % This method processes all transmitter-receiver pairs through the channel model.
    %
    % Inputs:
    %   FrameId - Frame identifier
    %   txsSignalSegments - Cell array of signal segments per transmitter
    %   TxInfos - Cell array of transmitter information structures
    %   RxInfos - Cell array of receiver information structures
    %
    % Outputs:
    %   signalsAtReceivers - Cell array of received signals per receiver

    obj.logger.debug("Frame %d: Processing channel propagation.", FrameId);

    numTx = length(txsSignalSegments);
    numRx = length(RxInfos);

    signalsAtReceivers = cell(1, numRx);
    scenarioMapProfile = struct();
    if ~isempty(obj.ScenarioConfig) && isstruct(obj.ScenarioConfig) && ...
            isfield(obj.ScenarioConfig, 'Layout')
        scenarioMapProfile = getMapProfileFromLayout(obj.ScenarioConfig.Layout);
    end
    useMidpointGeometry = localUseSegmentMidpointGeometry(obj.ScenarioConfig);
    if isstruct(scenarioMapProfile) && ...
            isfield(scenarioMapProfile, 'ChannelModel') && ...
            strcmpi(char(string(scenarioMapProfile.ChannelModel)), 'RayTracing') && ...
            ~useMidpointGeometry && ...
            ismethod(obj.Factories.Channel, 'precomputeRayTracingFrame')
        activeTxInfos = localActiveTxInfosForChannelPrecompute( ...
            txsSignalSegments, TxInfos);
        activeRxInfos = localActiveRxInfosForChannelPrecompute(RxInfos);
        if isempty(activeTxInfos) || isempty(activeRxInfos)
            obj.logger.debug(['Frame %d: skipped RayTracing precompute ', ...
                'because no live Tx/Rx links exist.'], FrameId);
        else
            obj.Factories.Channel.precomputeRayTracingFrame( ...
                FrameId, activeTxInfos, activeRxInfos, scenarioMapProfile, ...
                obj.ScenarioConfig);
        end
    end

    % Initialize received signals structure for each receiver
    for rxIdx = 1:numRx
        signalsAtReceivers{rxIdx} = struct();
        rxEntry = RxInfos{rxIdx};
        if isstruct(rxEntry) && isfield(rxEntry, 'ID')
            signalsAtReceivers{rxIdx}.ReceiverID = rxEntry.ID;
        else
            signalsAtReceivers{rxIdx}.ReceiverID = sprintf('Rx%d', rxIdx);
        end
        signalsAtReceivers{rxIdx}.SignalComponents = {};
        signalsAtReceivers{rxIdx}.TotalSignal = [];
    end

    % Process each transmitter-receiver pair
    for txIdx = 1:numTx
        if isempty(txsSignalSegments{txIdx}) || ~iscell(txsSignalSegments{txIdx})
            continue;
        end

        txInfo = TxInfos{txIdx};
        if ~isfield(txInfo, 'ID')
            continue;
        end
        if isfield(txInfo, 'Status') && contains(txInfo.Status, 'Error')
            continue;
        end

        for rxIdx = 1:numRx
            rxInfo = RxInfos{rxIdx};
            if ~isfield(rxInfo, 'ID') || contains(rxInfo.Status, 'Error')
                continue;
            end

            try
                % Apply channel model to all segments from this transmitter
                for segIdx = 1:length(txsSignalSegments{txIdx})
                    segmentSignal = txsSignalSegments{txIdx}{segIdx};

                    if isempty(segmentSignal) || ~isfield(segmentSignal, 'Signal')
                        continue;
                    end

                    localAssertSegmentAntennaColumns( ...
                        segmentSignal, txInfo, rxInfo, FrameId, segIdx);

                    txInfoForLink = txInfo;
                    rxInfoForLink = rxInfo;
                    linkGeometry = struct();
                    if useMidpointGeometry
                        [txInfoForLink, rxInfoForLink, linkGeometry] = ...
                            localResolveSegmentMidpointGeometry( ...
                                obj.ScenarioConfig.ScenarioPlan, ...
                                segmentSignal, txInfo, rxInfo, FrameId, segIdx);
                    end

                    channelInputStruct = segmentSignal;
                    channelInputStruct.TxInfo = txInfoForLink;
                    channelInputStruct.RxInfo = rxInfoForLink;

                    if iscell(obj.ScenarioConfig.Transmitters)
                        txScenarioConfig = obj.ScenarioConfig.Transmitters{txIdx};
                    elseif isstruct(obj.ScenarioConfig.Transmitters)
                        txScenarioConfig = obj.ScenarioConfig.Transmitters(txIdx);
                    else
                        txScenarioConfig = struct();
                    end
                    if iscell(obj.ScenarioConfig.Receivers)
                        rxScenarioConfig = obj.ScenarioConfig.Receivers{rxIdx};
                    elseif isstruct(obj.ScenarioConfig.Receivers)
                        rxScenarioConfig = obj.ScenarioConfig.Receivers(rxIdx);
                    else
                        rxScenarioConfig = struct();
                    end

                    % Combine scenario configs into a single channel link info struct
                    channelLinkInfo = struct();
                    channelLinkInfo.TxScenarioConfig = txScenarioConfig;
                    channelLinkInfo.RxScenarioConfig = rxScenarioConfig;
                    channelLinkInfo.MapProfile = scenarioMapProfile;
                    channelLinkInfo.ChannelModel = resolveChannelModelFromScenario(channelLinkInfo.MapProfile);
                    if ~isempty(fieldnames(linkGeometry))
                        channelLinkInfo.GeometryEvaluationTimeSec = ...
                            linkGeometry.EvaluationTimeSec;
                        channelLinkInfo.GeometryEvaluationPolicy = ...
                            linkGeometry.EvaluationPolicy;
                        channelLinkInfo.TxGeometry = linkGeometry.Tx;
                        channelLinkInfo.RxGeometry = linkGeometry.Rx;
                    end
                    if isfield(segmentSignal, 'BurstId') && ~isempty(segmentSignal.BurstId)
                        channelLinkInfo.BurstId = segmentSignal.BurstId;
                    else
                        error('CSRD:Construction:MissingBurstId', ...
                            ['Frame %d, TxID %s, RxID %s, Segment %d: ', ...
                             'segmentSignal.BurstId is required before channel propagation.'], ...
                            FrameId, string(txInfo.ID), string(rxInfo.ID), segIdx);
                    end

                    % Apply channel effects using ChannelFactory
                    channelOutput = step(obj.Factories.Channel, channelInputStruct, ...
                        FrameId, txInfoForLink, rxInfoForLink, channelLinkInfo);

                    component = struct();
                    component.TxID = txInfo.ID;
                    if isfield(segmentSignal, 'SegmentId') && ~isempty(segmentSignal.SegmentId)
                        component.SegmentId = segmentSignal.SegmentId;
                    else
                        component.SegmentId = sprintf('%s.Seg%03d', ...
                            char(string(txInfo.ID)), segIdx);
                    end
                    if isfield(segmentSignal, 'BurstId') && ~isempty(segmentSignal.BurstId)
                        component.BurstId = segmentSignal.BurstId;
                    else
                        error('CSRD:Construction:MissingBurstId', ...
                            ['Frame %d, TxID %s, RxID %s, Segment %d: ', ...
                             'segmentSignal.BurstId is required for component annotation.'], ...
                            FrameId, string(txInfo.ID), string(rxInfo.ID), segIdx);
                    end
                    % Phase 3 (§3.2.C): single source of truth for the
                    % component SampleRate is `channelOutput.SampleRate`.
                    % The legacy three-tier fallback (segment ->
                    % rxInfo) was removed -- enforcement lives on the
                    % class as a Static, Hidden helper for testability.
                    csrd.core.ChangShuo.assertChannelOutputSampleRate( ...
                        channelOutput, FrameId, txInfo.ID, rxInfo.ID, segIdx);
                    component.SampleRate = channelOutput.SampleRate;

                    if ~isfield(segmentSignal, 'Planned') || ...
                            ~isstruct(segmentSignal.Planned) || ...
                            isempty(fieldnames(segmentSignal.Planned))
                        error('CSRD:Construction:MissingSegmentPlannedTruth', ...
                            ['Frame %d, TxID %s, RxID %s, Segment %d: ', ...
                             'segmentSignal is missing the Planned design ', ...
                             'truth required for annotation.'], ...
                            FrameId, string(txInfo.ID), string(rxInfo.ID), segIdx);
                    end
                    component.Planned = segmentSignal.Planned;
                    if ~isempty(fieldnames(linkGeometry))
                        component.Planned.GeometrySnapshot = linkGeometry;
                    end

                    % Phase 4 (audit §17.6 / H12 / A5): apply physical
                    % Doppler shift `f_d = v_radial * f_c / c` after the
                    % channel block produced its baseband output. The
                    % current channel zoo (AWGN / MIMO / RayTracing as
                    % wired here) does not honour Tx/Rx velocity, so
                    % Doppler MUST be applied explicitly. The
                    % HasInternalDoppler hint on channelOutput.ChannelInfo
                    % is the future hook for channel types that already
                    % integrate Doppler internally; presence + true value
                    % causes us to skip to avoid double-shifting.
                    [component.Signal, component.DopplerShiftHz, ...
                     component.RadialVelocityMps] = applyDopplerForComponent( ...
                        channelOutput, txInfoForLink, rxInfoForLink);
                    component.ChannelOutputWasEmptyBeforeGating = ...
                        isfield(channelOutput, 'Signal') && isempty(channelOutput.Signal);
                    component = csrd.pipeline.signal.gateToDuration( ...
                        component, localComponentDurationSec(segmentSignal), ...
                        'ChannelOutput');
                    % Phase 3 (audit §3.1.ter A / phase-3-construction.md §3.1):
                    % the per-(Tx,Rx) component MUST carry the
                    % receiver-baseband ProjectedCenterOffsetHz from
                    % txScenarioConfig.ReceiverViews, NOT the emitter-global
                    % offset that came back through channelOutput. In the
                    % Phase 3 unified-receiver contract these two values are
                    % equal but the schema source-of-truth is the per-Rx
                    % projection, so consumers and Phase 4 heterogeneous-rx
                    % work will both pick up the correct value here.
                    component.FrequencyOffset = csrd.core.ChangShuo.lookupReceiverViewOffset( ...
                        txScenarioConfig, rxInfo, rxIdx, channelOutput);
                    % Phase 4 (§3.5 / S6 / P4-followup-3): persist the
                    % full per-(Tx,Rx) ReceiverView (5+1 fields) onto the
                    % component so downstream `buildSourceAnnotation`
                    % can publish it under SignalSources(k).ReceiverView
                    % verbatim. The lookup is fail-fast: a missing
                    % ReceiverViews struct on the Tx is a Phase 3 schema
                    % violation and must not be papered over.
                    component.ReceiverView = csrd.core.ChangShuo.lookupReceiverViewEntry( ...
                        txScenarioConfig, rxInfo, rxIdx);
                    component.Bandwidth = channelOutput.Bandwidth;
                    % Phase 4 (audit §17.6 / §6 C8 / §3.4): the v1
                    % `Realized.Bandwidth` was the modulator's analytical
                    % `(1+rolloff)*Rs`-style scalar set in BaseModulator.
                    % That formula consistently underestimates the
                    % actually-realised pulse-shape OBW by 5-30 % (e.g.
                    % RRC tails, OFDM PAPR clipping, FSK shaping), so a
                    % straight comparison against the receiver-side
                    % `Truth.Measured.SourcePlane.OccupiedBandwidthHz`
                    % made the C8<3% gate structurally infeasible. Phase
                    % 4 therefore promotes `Execution.ModulatedBandwidthHz`
                    % to a *measurement* on the **clean** modulator
                    % output (`segmentSignal.Signal`, pre-channel,
                    % zero-AWGN), using the same `obwActual` helper that
                    % powers the SourcePlane number. With the
                    % peak-relative -3 dBc thresholding rolled out in
                    % the post-baseline_v0 fix, the threshold floats
                    % with the signal peak (not with the per-source
                    % noise floor), so the SourcePlane OBW must equal
                    % the Execution OBW within the pwelch bin-grid
                    % quantisation -- which is exactly what the < 3 %
                    % gate is meant to police.
                    component.ModulatedBandwidthHz = ...
                        measureModulatedBandwidth(segmentSignal);
                    component.AnalyticalBandwidthHz = ...
                        coerceScalarBandwidth(channelOutput.Bandwidth);
                    if ~isfinite(component.ModulatedBandwidthHz) || ...
                            component.ModulatedBandwidthHz <= 0
                        csrd.runtime.performance.trace('event', ...
                            'Measurement.NonPositiveCleanObw', ...
                            NaN, localCleanObwDiagnostic( ...
                                component, segmentSignal));
                    end
                    if isfield(channelOutput, 'StartTime')
                        component.StartTime = channelOutput.StartTime;
                    elseif isfield(segmentSignal, 'StartTime')
                        component.StartTime = segmentSignal.StartTime;
                    else
                        component.StartTime = 0;
                    end
                    if isfield(segmentSignal, 'FrameRelativeStartTime')
                        component.FrameRelativeStartTime = ...
                            segmentSignal.FrameRelativeStartTime;
                    else
                        component.FrameRelativeStartTime = component.StartTime;
                    end
                    if isfield(segmentSignal, 'FrameRelativeEndTime')
                        component.FrameRelativeEndTime = ...
                            segmentSignal.FrameRelativeEndTime;
                    elseif isfield(segmentSignal, 'Duration')
                        component.FrameRelativeEndTime = ...
                            component.FrameRelativeStartTime + segmentSignal.Duration;
                    else
                        component.FrameRelativeEndTime = ...
                            component.FrameRelativeStartTime + ...
                            size(component.Signal, 1) / component.SampleRate;
                    end
                    if isfield(segmentSignal, 'FrameWindow')
                        component.FrameWindow = segmentSignal.FrameWindow;
                    end
                    % Phase 3 (§3.2.C / §3.4 D8 / audit §3.1.ter A):
                    % `component.Planned` is the modulator-side planning
                    % record set by processSingleSegment L86-88. Channel
                    % blocks must NOT echo a `.Planned` field back; doing
                    % so silently overwrote the per-segment planning truth
                    % with a channel-level reinterpretation. The
                    % passthrough was removed and any channelOutput.Planned
                    % is now ignored on purpose.
                    if isfield(channelOutput, 'ModulationTypeID')
                        component.ModulationType = channelOutput.ModulationTypeID;
                    end
                    if isfield(channelOutput, 'RFImpairments')
                        component.RFImpairments = channelOutput.RFImpairments;
                    end

                    % Attach spatial and link budget info for annotation
                    if isfield(txInfoForLink, 'Position')
                        component.TxPosition = txInfoForLink.Position;
                    end
                    if isfield(txInfoForLink, 'Velocity')
                        component.TxVelocity = txInfoForLink.Velocity;
                    else
                        error('CSRD:Construction:MissingTxVelocity', ...
                            'Frame %d, TxID %s: Tx velocity is required for channel geometry.', ...
                            FrameId, string(txInfo.ID));
                    end
                    if isfield(rxInfoForLink, 'Position')
                        component.RxPosition = rxInfoForLink.Position;
                    end
                    if isfield(rxInfoForLink, 'Velocity')
                        component.RxVelocity = rxInfoForLink.Velocity;
                    else
                        error('CSRD:Construction:MissingRxVelocity', ...
                            'Frame %d, RxID %s: Rx velocity is required for channel geometry.', ...
                            FrameId, string(rxInfo.ID));
                    end
                    if ~isempty(fieldnames(linkGeometry))
                        component.GeometryEvaluationTimeSec = ...
                            linkGeometry.EvaluationTimeSec;
                        component.GeometryEvaluationPolicy = ...
                            linkGeometry.EvaluationPolicy;
                        component.GeometrySnapshot = linkGeometry;
                    end
                    if isfield(channelOutput, 'LinkDistance')
                        component.LinkDistance = channelOutput.LinkDistance;
                    end
                    if isfield(channelOutput, 'PathLoss')
                        component.PathLoss = channelOutput.PathLoss;
                    end
                    if isfield(channelOutput, 'ComputedSNR')
                        component.ComputedSNR = channelOutput.ComputedSNR;
                    end
                    if isfield(channelOutput, 'AppliedSNRdB')
                        component.AppliedSNRdB = channelOutput.AppliedSNRdB;
                    end
                    if isfield(channelOutput, 'AppliedPathLoss')
                        component.AppliedPathLoss = channelOutput.AppliedPathLoss;
                    end
                    if isfield(channelOutput, 'ChannelModel')
                        component.ChannelModel = channelOutput.ChannelModel;
                    end
                    if isfield(channelOutput, 'ChannelInfo')
                        component.ChannelInfo = channelOutput.ChannelInfo;
                    end
                    if isfield(channelOutput, 'RayCount')
                        component.RayCount = channelOutput.RayCount;
                    end
                    if isfield(channelOutput, 'ChannelFallback')
                        component.ChannelFallback = channelOutput.ChannelFallback;
                    end

                    signalsAtReceivers{rxIdx}.SignalComponents{end+1} = component;
                end

            catch ME_channel
                obj.logger.error("Frame %d, Tx %s -> Rx %s: Channel error: %s", ...
                    FrameId, string(txInfo.ID), string(rxInfo.ID), ME_channel.message);

                % Scenario-level identifiers must propagate up to
                % SimulationRunner so that the offending scenario can be
                % skipped instead of producing a half-corrupted frame.
                if csrd.pipeline.scenario.isScenarioSkipException(ME_channel)
                    rethrow(ME_channel);
                end
                rethrow(ME_channel);
            end
        end
    end

    obj.logger.debug("Frame %d: Channel propagation complete.", FrameId);
end

function tf = localUseSegmentMidpointGeometry(scenarioConfig)
%LOCALUSESEGMENTMIDPOINTGEOMETRY Check the frozen scenario geometry policy.
tf = false;
if ~isstruct(scenarioConfig) || ~isfield(scenarioConfig, 'ScenarioPlan') || ...
        ~isstruct(scenarioConfig.ScenarioPlan) || ...
        ~isfield(scenarioConfig.ScenarioPlan, 'GeometryPolicy') || ...
        ~isstruct(scenarioConfig.ScenarioPlan.GeometryPolicy) || ...
        ~isfield(scenarioConfig.ScenarioPlan.GeometryPolicy, 'Evaluation')
    return;
end
tf = strcmpi(char(string( ...
    scenarioConfig.ScenarioPlan.GeometryPolicy.Evaluation)), ...
    'SegmentMidpoint');
end

function [txInfoOut, rxInfoOut, geometry] = localResolveSegmentMidpointGeometry( ...
        scenarioPlan, segmentSignal, txInfo, rxInfo, frameId, segIdx)
%LOCALRESOLVESEGMENTMIDPOINTGEOMETRY Evaluate Tx/Rx states at segment midpoint.
if ~isstruct(scenarioPlan)
    error('CSRD:ScenarioPlan:MissingScenarioPlan', ...
        'Frame %d, Segment %d: ScenarioPlan is required for midpoint geometry.', ...
        frameId, segIdx);
end
evaluationTimeSec = localSegmentEvaluationTime(segmentSignal, frameId, segIdx);
txState = csrd.pipeline.scenario.evaluateEntityState( ...
    scenarioPlan, txInfo.ID, evaluationTimeSec);
rxState = csrd.pipeline.scenario.evaluateEntityState( ...
    scenarioPlan, rxInfo.ID, evaluationTimeSec);

txInfoOut = localApplyEntityStateToInfo(txInfo, txState);
rxInfoOut = localApplyEntityStateToInfo(rxInfo, rxState);

geometry = struct( ...
    'EvaluationTimeSec', evaluationTimeSec, ...
    'EvaluationPolicy', 'SegmentMidpoint', ...
    'Tx', txState, ...
    'Rx', rxState);
end

function evaluationTimeSec = localSegmentEvaluationTime(segmentSignal, frameId, segIdx)
%LOCALSEGMENTEVALUATIONTIME Resolve absolute scenario time for geometry.
if isstruct(segmentSignal) && isfield(segmentSignal, 'GeometryEvaluationTimeSec') && ...
        isnumeric(segmentSignal.GeometryEvaluationTimeSec) && ...
        isscalar(segmentSignal.GeometryEvaluationTimeSec) && ...
        isfinite(segmentSignal.GeometryEvaluationTimeSec)
    evaluationTimeSec = double(segmentSignal.GeometryEvaluationTimeSec);
    return;
end
if isstruct(segmentSignal) && isfield(segmentSignal, 'StartTime') && ...
        isfield(segmentSignal, 'EndTime') && ...
        isnumeric(segmentSignal.StartTime) && isnumeric(segmentSignal.EndTime) && ...
        isscalar(segmentSignal.StartTime) && isscalar(segmentSignal.EndTime) && ...
        isfinite(segmentSignal.StartTime) && isfinite(segmentSignal.EndTime)
    evaluationTimeSec = (double(segmentSignal.StartTime) + ...
        double(segmentSignal.EndTime)) / 2;
    return;
end
error('CSRD:ScenarioPlan:MissingSegmentMidpoint', ...
    ['Frame %d, Segment %d: segmentSignal must carry ', ...
     'GeometryEvaluationTimeSec or finite StartTime/EndTime.'], ...
    frameId, segIdx);
end

function infoOut = localApplyEntityStateToInfo(infoIn, entityState)
%LOCALAPPLYENTITYSTATETOINFO Stamp evaluated geometry onto link info.
infoOut = infoIn;
infoOut.Position = entityState.PositionM;
infoOut.PositionUnit = 'meters';
infoOut.Velocity = entityState.VelocityMps;
if isfield(entityState, 'GeoPositionDeg') && ~isempty(entityState.GeoPositionDeg)
    infoOut.GeoPositionDeg = entityState.GeoPositionDeg;
end
infoOut.GeometryEvaluationTimeSec = entityState.EvaluationTimeSec;
infoOut.GeometryEvaluationPolicy = entityState.EvaluationPolicy;
end

function durationSec = localComponentDurationSec(segmentSignal)
    % localComponentDurationSec - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    if isfield(segmentSignal, 'FrameRelativeStartTime') && ...
            isfield(segmentSignal, 'FrameRelativeEndTime') && ...
            ~isempty(segmentSignal.FrameRelativeStartTime) && ...
            ~isempty(segmentSignal.FrameRelativeEndTime)
        durationSec = double(segmentSignal.FrameRelativeEndTime) - ...
            double(segmentSignal.FrameRelativeStartTime);
    elseif isfield(segmentSignal, 'Duration') && ~isempty(segmentSignal.Duration)
        durationSec = double(segmentSignal.Duration);
    else
        error('CSRD:Signal:MissingComponentDuration', ...
            'Channel component is missing Duration/FrameRelative time fields.');
    end
    if durationSec < 0 || ~isfinite(durationSec)
        error('CSRD:Signal:InvalidComponentDuration', ...
            'Channel component duration must be finite and non-negative.');
    end
end

function localAssertSegmentAntennaColumns(segmentSignal, txInfo, rxInfo, frameId, segIdx)
    % localAssertSegmentAntennaColumns - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    signalData = segmentSignal.Signal;
    if isempty(signalData)
        return;
    end

    expectedColumns = localResolveTxAntennaColumns(segmentSignal, txInfo);
    actualColumns = size(signalData, 2);
    if actualColumns ~= expectedColumns
        txId = localIdText(txInfo, 'Tx');
        rxId = localIdText(rxInfo, 'Rx');
        burstId = '';
        if isstruct(segmentSignal) && isfield(segmentSignal, 'BurstId') && ...
                ~isempty(segmentSignal.BurstId)
            burstId = char(string(segmentSignal.BurstId));
        end
        error('CSRD:Channel:SegmentAntennaColumnMismatch', ...
            ['Frame %d, Tx %s -> Rx %s, Segment %d, BurstId=%s: ', ...
             'channel input signal has %d columns but declares %d transmit antennas. ', ...
             'Signals must remain samples-by-antennas through modulation, TRF, and gating. SignalSize=%s.'], ...
            frameId, txId, rxId, segIdx, burstId, actualColumns, ...
            expectedColumns, mat2str(size(signalData)));
    end
end

function expectedColumns = localResolveTxAntennaColumns(segmentSignal, txInfo)
    % localResolveTxAntennaColumns - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    expectedColumns = [];
    if isstruct(segmentSignal) && isfield(segmentSignal, 'NumTransmitAntennas') && ...
            isnumeric(segmentSignal.NumTransmitAntennas) && ...
            isscalar(segmentSignal.NumTransmitAntennas) && ...
            isfinite(segmentSignal.NumTransmitAntennas) && ...
            segmentSignal.NumTransmitAntennas > 0
        expectedColumns = double(segmentSignal.NumTransmitAntennas);
    elseif isstruct(txInfo) && isfield(txInfo, 'NumTransmitAntennas') && ...
            isnumeric(txInfo.NumTransmitAntennas) && ...
            isscalar(txInfo.NumTransmitAntennas) && ...
            isfinite(txInfo.NumTransmitAntennas) && ...
            txInfo.NumTransmitAntennas > 0
        expectedColumns = double(txInfo.NumTransmitAntennas);
    else
        error('CSRD:Channel:MissingAntennaAuthority', ...
            'Channel propagation requires a positive NumTransmitAntennas on the segment or TxInfo.');
    end
    expectedColumns = round(expectedColumns);
end

function idText = localIdText(infoStruct, fallbackPrefix)
    % localIdText - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    if isstruct(infoStruct) && isfield(infoStruct, 'ID') && ~isempty(infoStruct.ID)
        idText = char(string(infoStruct.ID));
    else
        idText = char(string(fallbackPrefix));
    end
end

function mapProfile = getMapProfileFromLayout(layout)
    % getMapProfileFromLayout - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    mapProfile = struct();
    if isfield(layout, 'Environment')
        env = layout.Environment;
        if isfield(env, 'Map') && isfield(env.Map, 'MapProfile')
            mapProfile = env.Map.MapProfile;
        elseif isfield(env, 'MapProfile')
            mapProfile = env.MapProfile;
        end
    end
end

function activeTxInfos = localActiveTxInfosForChannelPrecompute(txsSignalSegments, TxInfos)
    % localActiveTxInfosForChannelPrecompute - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    activeTxInfos = {};
    numTx = min(numel(txsSignalSegments), numel(TxInfos));
    for txIdx = 1:numTx
        txInfo = TxInfos{txIdx};
        if ~isstruct(txInfo) || ~isfield(txInfo, 'ID') || ...
                (isfield(txInfo, 'Status') && contains(txInfo.Status, 'Error'))
            continue;
        end
        if ~localTxHasLiveSignalSegment(txsSignalSegments{txIdx})
            continue;
        end
        activeTxInfos{end + 1} = txInfo; %#ok<AGROW>
    end
end

function tf = localTxHasLiveSignalSegment(txSegments)
    % localTxHasLiveSignalSegment - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    tf = false;
    if isempty(txSegments) || ~iscell(txSegments)
        return;
    end
    for segIdx = 1:numel(txSegments)
        segmentSignal = txSegments{segIdx};
        if isstruct(segmentSignal) && isfield(segmentSignal, 'Signal') && ...
                ~isempty(segmentSignal.Signal)
            tf = true;
            return;
        end
    end
end

function activeRxInfos = localActiveRxInfosForChannelPrecompute(RxInfos)
    % localActiveRxInfosForChannelPrecompute - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    activeRxInfos = {};
    for rxIdx = 1:numel(RxInfos)
        rxInfo = RxInfos{rxIdx};
        if ~isstruct(rxInfo) || ~isfield(rxInfo, 'ID') || ...
                (isfield(rxInfo, 'Status') && contains(rxInfo.Status, 'Error'))
            continue;
        end
        activeRxInfos{end + 1} = rxInfo; %#ok<AGROW>
    end
end
function channelModel = resolveChannelModelFromScenario(mapProfile)
    % resolveChannelModelFromScenario - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    channelModel = '';
    if isstruct(mapProfile) && isfield(mapProfile, 'ChannelModel')
        channelModel = mapProfile.ChannelModel;
    end
end

function [shiftedSignal, dopplerHz, radialVelMps] = ...
        applyDopplerForComponent(channelOutput, txInfo, rxInfo)
    % applyDopplerForComponent - Apply external Doppler when the channel did not.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    % Phase 4 (§3.2.B): channel-type whitelist gate. If the channel block
    % already honoured Tx/Rx velocity internally (e.g. a future
    % phased.FreeSpace/Doppler-aware variant), it MUST set
    % channelOutput.ChannelInfo.HasInternalDoppler = true to opt out of
    % external double-shifting. Default (field absent or false) means we
    % must apply the shift here.
    shiftedSignal = channelOutput.Signal;
    dopplerHz    = 0;
    radialVelMps = 0;

    if isempty(channelOutput.Signal)
        csrd.runtime.performance.trace('count', ...
            'Channel.EmptyOutputBeforeDoppler');
        return;
    end

    if isfield(channelOutput, 'ChannelInfo') && ...
            isstruct(channelOutput.ChannelInfo) && ...
            isfield(channelOutput.ChannelInfo, 'HasInternalDoppler') && ...
            ~isempty(channelOutput.ChannelInfo.HasInternalDoppler) && ...
            logical(channelOutput.ChannelInfo.HasInternalDoppler)
        return;
    end

    if ~isfield(rxInfo, 'RealCarrierFrequency') || ...
            isempty(rxInfo.RealCarrierFrequency) || ...
            ~isfinite(rxInfo.RealCarrierFrequency) || ...
            rxInfo.RealCarrierFrequency <= 0
        return;
    end

    if ~isfield(txInfo, 'Position') || ~isfield(rxInfo, 'Position') || ...
            isempty(txInfo.Position) || isempty(rxInfo.Position)
        return;
    end

    relativeVel = csrd.core.ChangShuo.resolveRelativeVelocityForDoppler( ...
        txInfo, rxInfo);

    if all(relativeVel == 0)
        return;
    end

    fs = channelOutput.SampleRate;
    [shiftedSignal, dopplerHz, radialVelMps] = ...
        csrd.blocks.physical.channel.impairments.applyDopplerShift( ...
            channelOutput.Signal, fs, rxInfo.RealCarrierFrequency, ...
            txInfo.Position, relativeVel, rxInfo.Position);
end

function bwHz = measureModulatedBandwidth(segmentSignal)
    %MEASUREMODULATEDBANDWIDTH OBW of clean modulator output.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    % Phase 4 §3.4 promotes `Truth.Execution.ModulatedBandwidthHz` from
    % the modulator's analytical formula scalar to a real measurement on
    % the **clean** baseband waveform (no AWGN, no Doppler, no path
    % loss). The receiver-side `Truth.Measured.SourcePlane.OccupiedBandwidthHz`
    % then differs from this Execution number only by the noise-floor
    % estimator's residual bias — which is what the C8 < 3 % gate is
    % designed to police.
    %
    % Inputs:
    %   segmentSignal : struct with fields {Signal, SampleRate} produced
    %                   by ModulationFactory + TransmitFactory.
    %
    % Output:
    %   bwHz : occupied bandwidth in Hz, or NaN if the signal is missing,
    %          empty, or non-finite (the caller decides whether NaN is
    %          tolerable per the v2 schema's MeasurementCompleteness
    %          contract).

    bwHz = NaN;
    if ~isstruct(segmentSignal) || ...
            ~isfield(segmentSignal, 'Signal') || ...
            isempty(segmentSignal.Signal) || ...
            ~isfield(segmentSignal, 'SampleRate') || ...
            ~isnumeric(segmentSignal.SampleRate) || ...
            ~isscalar(segmentSignal.SampleRate) || ...
            ~isfinite(segmentSignal.SampleRate) || ...
            segmentSignal.SampleRate <= 0
        return;
    end

    sig = segmentSignal.Signal;
    if any(~isfinite(sig(:)))
        return;
    end

    try
        bwHz = csrd.pipeline.measurement.obwAntennaMax( ...
            sig, double(segmentSignal.SampleRate));
    catch
        bwHz = NaN;
    end
end

function diagnostic = localCleanObwDiagnostic(component, segmentSignal)
    % localCleanObwDiagnostic - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    diagnostic = struct();
    diagnostic.TxID = localStructText(component, 'TxID');
    diagnostic.BurstId = localStructText(component, 'BurstId');
    diagnostic.SegmentId = localStructText(component, 'SegmentId');
    diagnostic.ModulatedBandwidthHz = localStructNumber( ...
        component, 'ModulatedBandwidthHz');
    diagnostic.AnalyticalBandwidthHz = localStructNumber( ...
        component, 'AnalyticalBandwidthHz');
    diagnostic.SignalSamples = 0;
    diagnostic.SignalColumns = 0;
    diagnostic.SignalEnergy = NaN;
    diagnostic.SignalPeakAbs = NaN;
    diagnostic.SampleRate = NaN;
    if isstruct(segmentSignal)
        diagnostic.SampleRate = localStructNumber(segmentSignal, 'SampleRate');
        if isfield(segmentSignal, 'Signal') && isnumeric(segmentSignal.Signal)
            sig = segmentSignal.Signal;
            diagnostic.SignalSamples = size(sig, 1);
            diagnostic.SignalColumns = size(sig, 2);
            if ~isempty(sig)
                diagnostic.SignalEnergy = double(sum(abs(sig(:)).^2));
                diagnostic.SignalPeakAbs = double(max(abs(sig(:))));
            end
        end
        if isfield(segmentSignal, 'Planned') && isstruct(segmentSignal.Planned)
            planned = segmentSignal.Planned;
            diagnostic.ModulationFamily = localStructText( ...
                planned, 'ModulationFamily');
            diagnostic.ModulationOrder = localStructNumber( ...
                planned, 'ModulationOrder');
            diagnostic.PlannedBandwidthHz = localStructNumber( ...
                planned, 'PlannedBandwidthHz');
            diagnostic.PlannedDurationSec = localStructNumber( ...
                planned, 'DurationSec');
        end
    end
end

function textValue = localStructText(s, fieldName)
    % localStructText - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    textValue = '';
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        textValue = char(string(s.(fieldName)));
    end
end

function numericValue = localStructNumber(s, fieldName)
    % localStructNumber - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    numericValue = NaN;
    if isstruct(s) && isfield(s, fieldName) && ...
            isnumeric(s.(fieldName)) && isscalar(s.(fieldName)) && ...
            isfinite(s.(fieldName))
        numericValue = double(s.(fieldName));
    end
end

function bwHz = coerceScalarBandwidth(rawBw)
    %COERCESCALARBANDWIDTH Normalise a [lo,hi] / scalar BW field to Hz.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    %   The legacy modulator API stored bandwidth as `[lo, hi]`; some
    %   factories already collapse to a scalar. We accept either and
    %   always emit a non-negative scalar (or NaN on bad input).

    bwHz = NaN;
    if isempty(rawBw) || ~isnumeric(rawBw) || any(~isfinite(rawBw(:)))
        return;
    end

    if isscalar(rawBw)
        bwHz = double(abs(rawBw));
    elseif numel(rawBw) == 2
        bwHz = double(abs(rawBw(2) - rawBw(1)));
    else
        bwHz = double(abs(rawBw(1)));
    end
end
