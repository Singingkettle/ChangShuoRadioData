function signalsAtReceivers = processChannelPropagation(obj, FrameId, txsSignalSegments, TxInfos, RxInfos)
    % processChannelPropagation - Apply channel effects to transmitted signals
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

                    channelInputStruct = segmentSignal;
                    channelInputStruct.TxInfo = txInfo;
                    channelInputStruct.RxInfo = rxInfo;

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

                    % Apply channel effects using ChannelFactory
                    channelOutput = step(obj.Factories.Channel, channelInputStruct, ...
                        FrameId, txInfo, rxInfo, channelLinkInfo);

                    component = struct();
                    component.TxID = txInfo.ID;
                    if isfield(segmentSignal, 'SegmentId') && ~isempty(segmentSignal.SegmentId)
                        component.SegmentId = segmentSignal.SegmentId;
                    else
                        component.SegmentId = segIdx;
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
                             'truth required for annotation v2.'], ...
                            FrameId, string(txInfo.ID), string(rxInfo.ID), segIdx);
                    end
                    component.Planned = segmentSignal.Planned;

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
                        channelOutput, txInfo, rxInfo);
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
                    if isfield(channelOutput, 'StartTime')
                        component.StartTime = channelOutput.StartTime;
                    elseif isfield(segmentSignal, 'StartTime')
                        component.StartTime = segmentSignal.StartTime;
                    else
                        component.StartTime = 0;
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
                    if isfield(txInfo, 'Position')
                        component.TxPosition = txInfo.Position;
                    end
                    if isfield(txInfo, 'Velocity')
                        component.TxVelocity = txInfo.Velocity;
                    end
                    if isfield(rxInfo, 'Position')
                        component.RxPosition = rxInfo.Position;
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
                if csrd.utils.scenario.isScenarioSkipException(ME_channel)
                    rethrow(ME_channel);
                end
                rethrow(ME_channel);
            end
        end
    end

    obj.logger.debug("Frame %d: Channel propagation complete.", FrameId);
end

function mapProfile = getMapProfileFromLayout(layout)
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
function channelModel = resolveChannelModelFromScenario(mapProfile)
    channelModel = '';
    if isstruct(mapProfile) && isfield(mapProfile, 'ChannelModel')
        channelModel = mapProfile.ChannelModel;
    end
end

function [shiftedSignal, dopplerHz, radialVelMps] = ...
        applyDopplerForComponent(channelOutput, txInfo, rxInfo)
    % Phase 4 (§3.2.B): channel-type whitelist gate. If the channel block
    % already honoured Tx/Rx velocity internally (e.g. a future
    % phased.FreeSpace/Doppler-aware variant), it MUST set
    % channelOutput.ChannelInfo.HasInternalDoppler = true to opt out of
    % external double-shifting. Default (field absent or false) means we
    % must apply the shift here.
    shiftedSignal = channelOutput.Signal;
    dopplerHz    = 0;
    radialVelMps = 0;

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

    if ~isfield(txInfo, 'Velocity') || isempty(txInfo.Velocity)
        txVel = [0, 0, 0];
    else
        txVel = txInfo.Velocity;
    end

    if isequal(txVel(:).', [0, 0, 0])
        return;
    end

    fs = channelOutput.SampleRate;
    [shiftedSignal, dopplerHz, radialVelMps] = ...
        csrd.blocks.physical.channel.impairments.applyDopplerShift( ...
            channelOutput.Signal, fs, rxInfo.RealCarrierFrequency, ...
            txInfo.Position, txVel, rxInfo.Position);
end

function bwHz = measureModulatedBandwidth(segmentSignal)
    %MEASUREMODULATEDBANDWIDTH OBW of clean modulator output.
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
        bwHz = csrd.utils.measurement.obwActual( ...
            sig, double(segmentSignal.SampleRate));
    catch
        bwHz = NaN;
    end
end

function bwHz = coerceScalarBandwidth(rawBw)
    %COERCESCALARBANDWIDTH Normalise a [lo,hi] / scalar BW field to Hz.
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
