function previousState = getPreviousState(obj, frameId)
    % getPreviousState - Get previous frame state from internal history
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 getPreviousState 实现。
    %
    % Retrieves the previous frame state from the internal frame history
    % for temporal continuity in simulation.

    previousState = [];

    if frameId > 1 && isKey(obj.frameHistory, frameId - 1)
        previousState = obj.frameHistory(frameId - 1);
        obj.logger.debug('Frame %d: Retrieved previous state from frame %d', frameId, frameId - 1);
    else
        obj.logger.debug('Frame %d: No previous state available', frameId);
    end

end
