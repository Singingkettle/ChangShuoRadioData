function transmissionState = calculateTransmissionState(obj, frameId, txConfig)
    % calculateTransmissionState - Calculate transmission state for current frame
    %
    % Determines whether the transmitter should be active in the current frame
    % based on its transmission pattern and frame timing.

    transmissionState = struct();
    transmissionState.IsActive = true; % Default to active
    transmissionState.StartTime = 0;
    transmissionState.Duration = Inf;
    transmissionState.CurrentIntervalIdx = 1; % Default to first interval

    % Get temporal pattern with fallback
    if isfield(txConfig, 'Temporal') && isstruct(txConfig.Temporal)
        pattern = txConfig.Temporal;
    else
        pattern = struct('Type', 'Continuous', 'ObservationDuration', 1.0, 'Intervals', [0, 1.0]);
        obj.logger.warning('txConfig missing Temporal field, defaulting to Continuous');
    end

    patternType = 'Continuous';
    if isfield(pattern, 'Type')
        patternType = pattern.Type;
    end

    % Calculate based on transmission pattern
    switch patternType
        case 'Continuous'
            transmissionState.IsActive = true;
            transmissionState.StartTime = 0;
            transmissionState.Duration = pattern.ObservationDuration;
            transmissionState.CurrentIntervalIdx = 1;

        case 'Burst'
            % Calculate if we're in a burst period based on intervals
            if isfield(pattern, 'Intervals') && ~isempty(pattern.Intervals)
                [isActive, intervalIdx, startTime, endTime] = checkIntervals(frameId, pattern);
                transmissionState.IsActive = isActive;
                transmissionState.CurrentIntervalIdx = intervalIdx;
                transmissionState.StartTime = startTime;
                transmissionState.Duration = endTime - startTime;
            else
                transmissionState.IsActive = true;
            end

        case 'Scheduled'
            % Check scheduled intervals
            if isfield(pattern, 'Intervals') && ~isempty(pattern.Intervals)
                [isActive, intervalIdx, startTime, endTime] = checkIntervals(frameId, pattern);
                transmissionState.IsActive = isActive;
                transmissionState.CurrentIntervalIdx = intervalIdx;
                transmissionState.StartTime = startTime;
                transmissionState.Duration = endTime - startTime;
            else
                transmissionState.IsActive = (mod(frameId, 3) == 0);
                transmissionState.CurrentIntervalIdx = 1;
            end

        case 'Random'
            % Check random intervals
            if isfield(pattern, 'Intervals') && ~isempty(pattern.Intervals)
                [isActive, intervalIdx, startTime, endTime] = checkIntervals(frameId, pattern);
                transmissionState.IsActive = isActive;
                transmissionState.CurrentIntervalIdx = intervalIdx;
                transmissionState.StartTime = startTime;
                transmissionState.Duration = endTime - startTime;
            else
                transmissionState.IsActive = true;
            end

        otherwise
            transmissionState.IsActive = true;
            transmissionState.CurrentIntervalIdx = 1;
    end

end

function [isActive, intervalIdx, startTime, endTime] = checkIntervals(frameId, pattern)
    % checkIntervals - Check if frameId falls within any transmission interval
    
    isActive = false;
    intervalIdx = 0;
    startTime = 0;
    endTime = 0;
    
    intervals = pattern.Intervals;
    observationDuration = pattern.ObservationDuration;
    
    if isfield(pattern, 'NumFrames') && ~isempty(pattern.NumFrames)
        numFrames = pattern.NumFrames;
    else
        numFrames = 10;
    end
    
    % Calculate frame time (assuming equal frame distribution)
    frameTime = (frameId - 1) / numFrames * observationDuration;
    
    for i = 1:size(intervals, 1)
        if frameTime >= intervals(i, 1) && frameTime < intervals(i, 2)
            isActive = true;
            intervalIdx = i;
            startTime = intervals(i, 1);
            endTime = intervals(i, 2);
            return;
        end
    end
end
