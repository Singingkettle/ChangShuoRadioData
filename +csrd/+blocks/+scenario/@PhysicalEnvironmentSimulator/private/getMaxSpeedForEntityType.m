function maxSpeed = getMaxSpeedForEntityType(obj, entityType)
    % getMaxSpeedForEntityType - Get maximum speed constraint for entity type
    %
    % Input Arguments:
    %   entityType - Type of entity ('Transmitter', 'Receiver', etc.)
    %
    % Output Arguments:
    %   maxSpeed - Maximum speed in m/s

    switch entityType
        case 'Transmitter'
            maxSpeed = 10; % m/s (vehicular speeds)
        case 'Receiver'
            maxSpeed = 2; % m/s (pedestrian speeds or stationary)
        otherwise
            maxSpeed = 5; % m/s (default)
    end

end
