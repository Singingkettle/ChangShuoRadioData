function transmissionState = calculateTransmissionState(obj, frameId, txConfig)
    % calculateTransmissionState - Calculate transmission state for current frame
    %
    % Determines whether the transmitter should be active in the current frame
    % based on its transmission pattern and frame timing.

    transmissionState = struct();
    transmissionState.IsActive = true; % Default to active
    transmissionState.StartTime = 0;
    transmissionState.Duration = Inf;

    % Calculate based on transmission pattern
    switch txConfig.TransmissionPattern.Type
        case 'Continuous'
            transmissionState.IsActive = true;
            transmissionState.StartTime = 0;
            transmissionState.Duration = Inf;

        case 'Burst'
            % Calculate if we're in a burst period
            if isfield(txConfig.TransmissionPattern, 'BurstPeriod')
                period = txConfig.TransmissionPattern.BurstPeriod;
                duration = txConfig.TransmissionPattern.Duration;

                % Simple modulo-based burst timing
                frameTime = frameId * 0.1; % Assume 0.1s per frame
                cycleTime = mod(frameTime, period);

                transmissionState.IsActive = (cycleTime < duration);
                transmissionState.StartTime = max(0, duration - cycleTime);
                transmissionState.Duration = min(duration, duration - cycleTime);
            else
                transmissionState.IsActive = true;
            end

        case 'Scheduled'
            % Placeholder for scheduled transmission logic
            transmissionState.IsActive = (mod(frameId, 3) == 0); % Every 3rd frame
            transmissionState.StartTime = 0;
            transmissionState.Duration = 0.1; % One frame duration

        otherwise
            transmissionState.IsActive = true;
    end

end
