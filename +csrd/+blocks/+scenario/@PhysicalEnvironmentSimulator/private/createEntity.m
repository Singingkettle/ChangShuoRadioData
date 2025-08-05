function entity = createEntity(obj, entityType, entityID, frameId)
    % createEntity - Create a single entity with physical properties
    %
    % Creates a comprehensive entity structure with position, velocity,
    % physical properties, and mobility model assignment.

    entity = struct();
    entity.ID = entityID;
    entity.Type = entityType;
    entity.FrameId = frameId;
    entity.CreationTime = frameId * obj.timeResolution;

    % Initialize position within map boundaries
    if isfield(obj.mapData, 'Boundaries') && ~isempty(obj.mapData.Boundaries)
        bounds = obj.mapData.Boundaries;

        if isfield(bounds, 'MinLatitude')
            % OSM-style boundaries
            entity.Position = [
                               randomInRange(obj, bounds.MinLongitude, bounds.MaxLongitude), % X coordinate
                               randomInRange(obj, bounds.MinLatitude, bounds.MaxLatitude), % Y coordinate
                               randomInRange(obj, 10, 100) % Z coordinate (height)
                               ];
        else
            % Grid-style boundaries
            entity.Position = [
                               randomInRange(obj, bounds(1), bounds(2)), % X coordinate
                               randomInRange(obj, bounds(3), bounds(4)), % Y coordinate
                               randomInRange(obj, 10, 100) % Z coordinate (height)
                               ];
        end

    else
        % Use default boundaries if not set
        obj.logger.warning('Map boundaries not set, using default boundaries for entity creation');
        entity.Position = [
                           randomInRange(obj, -1000, 1000), % X coordinate
                           randomInRange(obj, -1000, 1000), % Y coordinate
                           randomInRange(obj, 10, 100) % Z coordinate (height)
                           ];
    end

    % Initialize velocity and motion parameters
    maxSpeed = getMaxSpeedForEntityType(obj, entityType);
    entity.Velocity = [
                       randomInRange(obj, -maxSpeed, maxSpeed), % X velocity (m/s)
                       randomInRange(obj, -maxSpeed, maxSpeed), % Y velocity (m/s)
                       0 % Z velocity (stationary altitude)
                       ];

    % Initialize orientation (azimuth, elevation in degrees)
    entity.Orientation = [
                          randi([-180, 180]), % Azimuth
                          randi([-30, 30]) % Elevation
                          ];

    % Initialize angular velocity (deg/s)
    entity.AngularVelocity = [
                              randomInRange(obj, -10, 10), % Azimuth rate
                              randomInRange(obj, -5, 5) % Elevation rate
                              ];

    % Assign mobility model
    entity.MobilityModel = assignMobilityModel(obj, entityType, entityID);

    % Initialize physical properties
    entity.Properties = initializeEntityProperties(obj, entityType);

    % Initialize state tracking
    entity.StateHistory = [];
    entity.LastUpdateTime = entity.CreationTime;

    obj.logger.debug('Created %s entity %s at position [%.1f, %.1f, %.1f]', ...
        entityType, entityID, entity.Position);
end
