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
                    component.Signal = channelOutput.Signal;
                    if isfield(channelOutput, 'SampleRate') && ~isempty(channelOutput.SampleRate) && channelOutput.SampleRate > 0
                        component.SampleRate = channelOutput.SampleRate;
                    elseif isfield(segmentSignal, 'SampleRate') && ~isempty(segmentSignal.SampleRate) && segmentSignal.SampleRate > 0
                        component.SampleRate = segmentSignal.SampleRate;
                    elseif isfield(rxInfo, 'SampleRate') && ~isempty(rxInfo.SampleRate) && rxInfo.SampleRate > 0
                        component.SampleRate = rxInfo.SampleRate;
                        obj.logger.warning(['Frame %d, Tx %s -> Rx %s, Seg %d: ', ...
                            'channel/segment SampleRate missing; ', ...
                            'falling back to receiver SampleRate %.0f Hz. ', ...
                            'Upstream stages should populate SampleRate.'], ...
                            FrameId, string(txInfo.ID), string(rxInfo.ID), segIdx, ...
                            rxInfo.SampleRate);
                    else
                        error('CSRD:Core:MissingSampleRate', ...
                            ['Frame %d, Tx %s -> Rx %s, Seg %d: cannot ', ...
                             'determine signal SampleRate (channel, segment ', ...
                             'and receiver values are all missing).'], ...
                            FrameId, string(txInfo.ID), string(rxInfo.ID), segIdx);
                    end
                    component.FrequencyOffset = channelOutput.FrequencyOffset;
                    component.Bandwidth = channelOutput.Bandwidth;
                    if isfield(channelOutput, 'StartTime')
                        component.StartTime = channelOutput.StartTime;
                    elseif isfield(segmentSignal, 'StartTime')
                        component.StartTime = segmentSignal.StartTime;
                    else
                        component.StartTime = 0;
                    end
                    if isfield(channelOutput, 'Planned')
                        component.Planned = channelOutput.Planned;
                    end
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
