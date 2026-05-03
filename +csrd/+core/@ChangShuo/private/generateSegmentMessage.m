function rawMessageStruct = generateSegmentMessage(obj, FrameId, currentTxId, segIdx, currentSegmentScenario)
    % generateSegmentMessage - Generate message for a single segment
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 generateSegmentMessage 实现。
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
    segmentInfo.SegmentId = sprintf('%s.Seg%03d', char(string(currentTxId)), segIdx);
    segmentInfo.BurstId = sprintf('%s.Burst%03d', char(string(currentTxId)), segIdx);
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
