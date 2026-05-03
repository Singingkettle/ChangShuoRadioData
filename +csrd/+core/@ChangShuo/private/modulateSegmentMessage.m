function modulatedSignalSegment = modulateSegmentMessage(obj, FrameId, currentTxId, segIdx, currentSegmentScenario, rawMessageStruct)
    % modulateSegmentMessage - Modulate message for a single segment
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 modulateSegmentMessage 实现。
    %
    % This method uses the ModulationFactory to modulate message data.
    %
    % Inputs:
    %   FrameId - Global frame identifier
    %   currentTxId - Current transmitter ID
    %   segIdx - Segment index
    %   currentSegmentScenario - Current segment scenario configuration
    %   rawMessageStruct - Generated message structure
    %
    % Outputs:
    %   modulatedSignalSegment - Modulated signal segment

    modConfig = currentSegmentScenario.Modulation;
    modulationConfigIdentifier = modConfig.TypeID;

    obj.logger.debug("Frame %d, TxID %s, Seg %d: Modulating message (Modulation TypeID: %s).", ...
        FrameId, string(currentTxId), segIdx, num2str(modulationConfigIdentifier));

    if isempty(obj.Factories.Modulation)
        obj.logger.error("Frame %d, TxID %s, Seg %d: Modulation factory not initialized.", FrameId, string(currentTxId), segIdx);
        modulatedSignalSegment = [];
        return;
    end

    % Setup placement configuration
    currentPlacementConfig = struct();
    if isfield(currentSegmentScenario, 'Placement')
        currentPlacementConfig = currentSegmentScenario.Placement;
    end

    modulatedSignalSegment = step(obj.Factories.Modulation, ...
        rawMessageStruct.data, ...
        FrameId, ...
        string(currentTxId), ...
        segIdx, ...
        currentSegmentScenario.Modulation, ...
        currentPlacementConfig);
end
