function previousState = getPreviousState(obj, frameId)
    % getPreviousState - Get previous frame state from internal history
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
