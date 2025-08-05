function transmissionState = updateBurstState(obj, frameId, txConfig)
    % updateBurstState - Update burst transmission state
    transmissionState = calculateTransmissionState(obj, frameId, txConfig);

    % Add burst-specific parameters
    if isfield(txConfig.TransmissionPattern, 'DutyCycle')
        transmissionState.DutyCycle = txConfig.TransmissionPattern.DutyCycle;
    end

end
