function entity = resolveObstacleCollision(obj, entity, environment)
    % resolveObstacleCollision - Resolve collision by adjusting entity position and velocity
    %
    % Simple implementation: reverse velocity direction

    entity.Velocity = -entity.Velocity * 0.5;
    obj.logger.debug('Resolved obstacle collision for entity %s', entity.ID);
end
