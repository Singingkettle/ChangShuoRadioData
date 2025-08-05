function modulatedSignalSegment = processSingleSegment(obj, FrameId, currentTxScenario, currentTxId, segIdx)
    % processSingleSegment - Process a single segment for message generation and modulation
    %
    % This method handles the complete processing of one segment including
    % message generation and modulation.
    %
    % Inputs:
    %   FrameId - Global frame identifier
    %   currentTxScenario - Current transmitter scenario configuration
    %   currentTxId - Current transmitter ID
    %   segIdx - Segment index
    %
    % Outputs:
    %   modulatedSignalSegment - Modulated signal segment

    % Validate segment configuration
    if ~isfield(currentTxScenario, 'Segments') || segIdx > length(currentTxScenario.Segments) || ...
            ~isstruct(currentTxScenario.Segments(segIdx))
        obj.logger.warning('Frame %d, TxID %s, Segment Index %d: Segment definition missing or not a struct.', ...
            FrameId, string(currentTxId), segIdx);
        modulatedSignalSegment = [];
        return;
    end

    currentSegmentScenario = currentTxScenario.Segments(segIdx);

    % Validate message configuration
    if ~validateSegmentMessageConfig(obj, currentSegmentScenario, FrameId, currentTxId, segIdx)
        modulatedSignalSegment = [];
        return;
    end

    % Validate modulation configuration
    if ~validateSegmentModulationConfig(obj, currentSegmentScenario, FrameId, currentTxId, segIdx)
        modulatedSignalSegment = [];
        return;
    end

    % Generate message
    rawMessageStruct = generateSegmentMessage(obj, FrameId, currentTxId, segIdx, currentSegmentScenario);

    if isempty(rawMessageStruct)
        modulatedSignalSegment = [];
        return;
    end

    % Modulate message
    modulatedSignalSegment = modulateSegmentMessage(obj, FrameId, currentTxId, segIdx, ...
        currentSegmentScenario, rawMessageStruct);
end
