function isValid = validateSegmentMessageConfig(obj, currentSegmentScenario, FrameId, currentTxId, segIdx)
    % validateSegmentMessageConfig - Validate segment message configuration
    %
    % This method validates that the segment has proper message configuration
    % including Length and TypeID fields.
    %
    % Inputs:
    %   currentSegmentScenario - Current segment scenario configuration
    %   FrameId - Global frame identifier
    %   currentTxId - Current transmitter ID
    %   segIdx - Segment index
    %
    % Outputs:
    %   isValid - Boolean indicating if configuration is valid

    isValid = true;

    if ~isfield(currentSegmentScenario, 'Message') || ~isstruct(currentSegmentScenario.Message) || ...
            ~isfield(currentSegmentScenario.Message, 'Length') || ~isfield(currentSegmentScenario.Message, 'TypeID')
        obj.logger.error('Frame %d, TxID %s, Seg %d: Message config, Length or TypeID missing.', ...
            FrameId, string(currentTxId), segIdx);
        isValid = false;
    end

end
