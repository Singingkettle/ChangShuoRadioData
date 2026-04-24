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
    % checkIntervals - Thin wrapper around csrd.utils.scenario.checkTransmissionInterval.
    % Kept here so existing call sites stay short; the testable
    % implementation lives in +csrd/+utils/+scenario/.
    [isActive, intervalIdx, startTime, endTime] = ...
        csrd.utils.scenario.checkTransmissionInterval(frameId, pattern);
end
