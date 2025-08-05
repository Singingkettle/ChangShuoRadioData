function mobilityModel = assignMobilityModel(obj, entityType, entityID)
    % assignMobilityModel - Assign appropriate mobility model to entity
    %
    % Input Arguments:
    %   entityType - Type of entity
    %   entityID - Unique identifier for the entity
    %
    % Output Arguments:
    %   mobilityModel - Assigned mobility model name

    if strcmp(entityType, 'Receiver')
        % Receivers are typically stationary monitoring stations
        mobilityModel = 'Stationary';
    else
        % Transmitters may be mobile
        models = {'RandomWalk', 'Waypoint', 'Stationary'};
        mobilityModel = models{randi(length(models))};
    end

end
