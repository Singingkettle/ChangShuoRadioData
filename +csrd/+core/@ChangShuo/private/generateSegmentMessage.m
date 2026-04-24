function rawMessageStruct = generateSegmentMessage(obj, FrameId, currentTxId, segIdx, currentSegmentScenario)
    % generateSegmentMessage - Generate message for a single segment
    %
    % This method uses the MessageFactory to generate message data for a segment.
    %
    % Inputs:
    %   FrameId - Global frame identifier
    %   currentTxId - Current transmitter ID
    %   segIdx - Segment index
    %   currentSegmentScenario - Current segment scenario configuration
    %
    % Outputs:
    %   rawMessageStruct - Generated message structure

    msgConfig = currentSegmentScenario.Message;
    messageTypeID = msgConfig.TypeID;

    obj.logger.debug("Frame %d, TxID %s, Seg %d: Generating message (TypeID: %s).", ...
        FrameId, string(currentTxId), segIdx, num2str(messageTypeID));

    if isempty(obj.Factories.Message)
        obj.logger.error("Frame %d, TxID %s, Seg %d: Message factory not initialized.", FrameId, string(currentTxId), segIdx);
        rawMessageStruct = [];
        return;
    end

    segmentInfo = struct();
    segmentInfo.SegmentId = sprintf('%s_Seg%d', string(currentTxId), segIdx);
    segmentInfo.Message = msgConfig;
    if isfield(currentSegmentScenario, 'Modulation') && isfield(currentSegmentScenario.Modulation, 'SymbolRate')
        segmentInfo.Message.SymbolRate = currentSegmentScenario.Modulation.SymbolRate;
    end
    if isfield(currentSegmentScenario, 'Modulation') && isfield(currentSegmentScenario.Modulation, 'BitsPerSymbol')
        segmentInfo.Message.BitsPerSymbol = currentSegmentScenario.Modulation.BitsPerSymbol;
    end
    if isfield(currentSegmentScenario, 'Placement') && isfield(currentSegmentScenario.Placement, 'Duration')
        segmentInfo.Message.Duration = currentSegmentScenario.Placement.Duration;
    end

    rawMessageStruct = step(obj.Factories.Message, FrameId, segmentInfo, messageTypeID);

    if isempty(rawMessageStruct) || ~isfield(rawMessageStruct, 'data') || isempty(rawMessageStruct.data)
        obj.logger.warning('Frame %d, TxID %s, Seg %d: MessageFactory returned empty/invalid data.', FrameId, string(currentTxId), segIdx);
        rawMessageStruct = [];
    end

end
