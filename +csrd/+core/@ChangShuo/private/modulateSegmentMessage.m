function modulatedSignalSegment = modulateSegmentMessage(obj, FrameId, currentTxId, segIdx, currentSegmentScenario, rawMessageStruct)
    % modulateSegmentMessage - Modulate message for a single segment
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

    if isempty(obj.pModulationFactory)
        obj.logger.error("Frame %d, TxID %s, Seg %d: ModulationFactory not initialized.", FrameId, string(currentTxId), segIdx);
        modulatedSignalSegment = [];
        return;
    end

    % Setup placement configuration
    currentPlacementConfig = struct(); % Initialize empty

    if isfield(currentSegmentScenario, 'Placement')
        currentPlacementConfig = currentSegmentScenario.Placement;
    end

    modulatedSignalSegment = step(obj.pModulationFactory, ...
        rawMessageStruct.data, ...
        FrameId, ...
        string(currentTxId), ...
        segIdx, ...
        currentSegmentScenario.Modulation, ...
        currentPlacementConfig);
end
