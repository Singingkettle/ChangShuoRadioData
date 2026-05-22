function entities = applyEnvironmentalConstraints(obj, entities, environment)
    % applyEnvironmentalConstraints - Apply physical constraints and collision detection
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    % Ensures entities remain within valid physical boundaries and
    % handles collision detection with obstacles and other entities.

    for i = 1:length(entities)
        entity = entities(i);

        % Apply map boundary constraints
        entity.Position = applyBoundaryConstraints(obj, entity.Position);

        % Check collision with static obstacles
        if checkObstacleCollision(obj, entity.Position, environment)
            entity = resolveObstacleCollision(obj, entity, environment);
        end

        % Apply terrain constraints
        entity.Position(3) = max(entity.Position(3), getTerrainHeight(obj, entity.Position(1:2)) + 5);
        entity.PositionUnit = 'meters';
        if isfield(obj.mapData, 'Boundaries') && ...
                isstruct(obj.mapData.Boundaries) && ...
                isfield(obj.mapData.Boundaries, 'MinLatitude')
            entity.GeoPositionDeg = localMetersToGeo(entity.Position, ...
                obj.mapData.Boundaries);
        elseif ~isfield(entity, 'GeoPositionDeg')
            entity.GeoPositionDeg = [];
        end

        entities(i) = entity;
    end

end
