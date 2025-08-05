function initializeTransmissionScheduler(obj)
    % initializeTransmissionScheduler - Initialize transmission scheduling engine
    obj.transmissionScheduler = struct();

    % Set default type with fallback
    if isfield(obj.Config, 'TransmissionPattern') && isfield(obj.Config.TransmissionPattern, 'DefaultType')
        obj.transmissionScheduler.defaultType = obj.Config.TransmissionPattern.DefaultType;
    else
        obj.logger.warning('TransmissionPattern.DefaultType not found in config, using default: Continuous');
        obj.transmissionScheduler.defaultType = 'Continuous';
    end

    obj.logger.debug('Transmission scheduler initialized with default type: %s', ...
        obj.transmissionScheduler.defaultType);
end
