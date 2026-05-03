function entities = applyEnvironmentalConstraints(obj, entities, environment)
    % applyEnvironmentalConstraints - Apply physical constraints and collision detection
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 applyEnvironmentalConstraints 实现。
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

        entities(i) = entity;
    end

end
