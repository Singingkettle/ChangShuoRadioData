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

    prevEntities = previousState.entities;
    currentTime = frameId * timeResolution;

    % Use cell array to avoid struct field mismatch issues
    entityCell = cell(1, length(prevEntities));

    for i = 1:length(prevEntities)
        entity = prevEntities(i);

        deltaTime = timeResolution;
        newPosition = entity.Position + entity.Velocity * deltaTime;

        if isKey(obj.mobilityModels, entity.MobilityModel)
            mobilityModel = obj.mobilityModels(entity.MobilityModel);
            if ~isempty(mobilityModel) && isobject(mobilityModel)
                [newPosition, newVelocity] = mobilityModel.updateState(entity, deltaTime, obj.mapData);
                entity.Velocity = newVelocity;
            end
        end

        entity.Orientation = entity.Orientation + entity.AngularVelocity * deltaTime;
        entity.Orientation(1) = mod(entity.Orientation(1) + 180, 360) - 180;
        entity.Orientation(2) = max(-90, min(90, entity.Orientation(2)));

        entity.Position = applyBoundaryConstraints(obj, newPosition);

        entity.FrameId = frameId;
        entity.LastUpdateTime = currentTime;

        stateSnapshot = struct();
        stateSnapshot.frameId = frameId;
        stateSnapshot.time = currentTime;
        stateSnapshot.position = entity.Position;
        stateSnapshot.velocity = entity.Velocity;
        stateSnapshot.orientation = entity.Orientation;
        entity.StateHistory = [entity.StateHistory, stateSnapshot];

        if isfield(entity, 'Snapshots') && iscell(entity.Snapshots)
            if frameId > length(entity.Snapshots)
                entity.Snapshots{frameId} = struct();
            end
            
            if isempty(entity.Snapshots{frameId})
                if frameId > 1 && ~isempty(entity.Snapshots{frameId - 1})
                    entity.Snapshots{frameId} = entity.Snapshots{frameId - 1};
                else
                    entity.Snapshots{frameId} = struct();
                    entity.Snapshots{frameId}.Physical = struct();
                    entity.Snapshots{frameId}.Communication = struct();
                    entity.Snapshots{frameId}.Temporal = struct();
                end
            end
            
            entity.Snapshots{frameId}.FrameId = frameId;
            entity.Snapshots{frameId}.Timestamp = currentTime;
            entity.Snapshots{frameId}.Physical.Position = entity.Position;
            entity.Snapshots{frameId}.Physical.Velocity = entity.Velocity;
            entity.Snapshots{frameId}.Physical.Orientation = entity.Orientation;
            entity.Snapshots{frameId}.Physical.AngularVelocity = entity.AngularVelocity;
        end

        entityCell{i} = entity;

        obj.logger.debug('Frame %d: Updated %s %s to position [%.1f, %.1f, %.1f]', ...
            frameId, entity.Type, entity.ID, entity.Position);
    end

    % Reconstruct struct array from cell array
    entities = [entityCell{:}];

end
