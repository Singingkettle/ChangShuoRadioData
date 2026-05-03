function isValid = validateSegmentMessageConfig(obj, currentSegmentScenario, FrameId, currentTxId, segIdx)
    % validateSegmentMessageConfig - Validate segment message configuration
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 validateSegmentMessageConfig 实现。
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
