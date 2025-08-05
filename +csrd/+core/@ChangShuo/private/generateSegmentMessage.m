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
    msgLength = msgConfig.Length;
    messageConfigIdentifier = msgConfig.TypeID;
    symbolRateForMsgFactory = currentSegmentScenario.Modulation.SymbolRate;

    obj.logger.debug("Frame %d, TxID %s, Seg %d: Generating message (TypeID: %s, Length: %d, SymRate: %g).", ...
        FrameId, string(currentTxId), segIdx, num2str(messageConfigIdentifier), msgLength, symbolRateForMsgFactory);

    if isempty(obj.pMessageFactory)
        obj.logger.error("Frame %d, TxID %s, Seg %d: MessageFactory not initialized.", FrameId, string(currentTxId), segIdx);
        rawMessageStruct = [];
        return;
    end

    rawMessageStruct = step(obj.pMessageFactory, FrameId, messageConfigIdentifier, segIdx, msgLength, symbolRateForMsgFactory);

    if isempty(rawMessageStruct) || ~isfield(rawMessageStruct, 'data') || isempty(rawMessageStruct.data)
        obj.logger.warning('Frame %d, TxID %s, Seg %d: MessageFactory returned empty/invalid data.', FrameId, string(currentTxId), segIdx);
        rawMessageStruct = [];
    end

end
