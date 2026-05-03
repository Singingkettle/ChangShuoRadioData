function entity = resolveObstacleCollision(obj, entity, environment)
    % resolveObstacleCollision - Resolve collision by adjusting entity position and velocity
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 resolveObstacleCollision 实现。
    %
    % Simple implementation: reverse velocity direction

    entity.Velocity = -entity.Velocity * 0.5;
    obj.logger.debug('Resolved obstacle collision for entity %s', entity.ID);
end
