function transmissionState = updateScheduledState(obj, frameId, txConfig)
    % updateScheduledState - Update scheduled transmission state
    transmissionState = calculateTransmissionState(obj, frameId, txConfig);

    % Add schedule-specific parameters
    if isfield(txConfig.TransmissionPattern, 'Schedule')
        transmissionState.Schedule = txConfig.TransmissionPattern.Schedule;
    end

end
