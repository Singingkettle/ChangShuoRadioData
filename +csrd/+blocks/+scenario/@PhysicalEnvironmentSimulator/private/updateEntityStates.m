function entities = updateEntityStates(obj, frameId, timeResolution, previousState)
    % updateEntityStates - Update entity positions based on mobility models
    %
    % Updates all entity positions and states based on their assigned
    % mobility models and the elapsed time since the previous frame.
    %
    % Input Arguments:
    %   frameId - Current frame identifier
    %   timeResolution - Time step for updates (seconds)
    %   previousState - Previous frame state containing entity data
    %
    % Output Arguments:
    %   entities - Updated entity array with new positions and states

    if isempty(previousState) || ~isfield(previousState, 'entities')
        obj.logger.warning('Frame %d: No previous state available, reinitializing entities', frameId);
        entities = initializeEntities(obj, frameId);
        return;
    end

    entities = previousState.entities;
    currentTime = frameId * timeResolution;

    for i = 1:length(entities)
        entity = entities(i);

        % Update position based on velocity and time step
        deltaTime = timeResolution;
        newPosition = entity.Position + entity.Velocity * deltaTime;

        % Apply mobility model updates
        if isKey(obj.mobilityModels, entity.MobilityModel)
            mobilityModel = obj.mobilityModels(entity.MobilityModel);
            [newPosition, newVelocity] = mobilityModel.updateState(entity, deltaTime, obj.mapData);
            entity.Velocity = newVelocity;
        end

        % Update orientation based on angular velocity
        entity.Orientation = entity.Orientation + entity.AngularVelocity * deltaTime;

        % Normalize angles
        entity.Orientation(1) = mod(entity.Orientation(1) + 180, 360) - 180; % Azimuth [-180, 180]
        entity.Orientation(2) = max(-90, min(90, entity.Orientation(2))); % Elevation [-90, 90]

        % Apply boundary constraints
        entity.Position = applyBoundaryConstraints(obj, newPosition);

        % Update temporal properties
        entity.FrameId = frameId;
        entity.LastUpdateTime = currentTime;

        % Store state in history
        stateSnapshot = struct();
        stateSnapshot.frameId = frameId;
        stateSnapshot.time = currentTime;
        stateSnapshot.position = entity.Position;
        stateSnapshot.velocity = entity.Velocity;
        stateSnapshot.orientation = entity.Orientation;
        entity.StateHistory = [entity.StateHistory, stateSnapshot];

        entities(i) = entity;

        obj.logger.debug('Frame %d: Updated %s %s to position [%.1f, %.1f, %.1f]', ...
            frameId, entity.Type, entity.ID, entity.Position);
    end

end
