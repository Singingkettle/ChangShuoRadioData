function hasCollision = checkObstacleCollision(obj, position, environment)
    % checkObstacleCollision - Simple collision detection with static obstacles
    % 中文说明：提供 CSRD 生产链路中的 checkObstacleCollision 实现。
    %
    % Input Arguments:
    %   position - Entity position vector [x, y, z]
    %   environment - Current environment state
    %
    % Output Arguments:
    %   hasCollision - Boolean indicating collision with obstacles

    hasCollision = false;

    if isfield(environment, 'StaticObstacles')

        for i = 1:length(environment.StaticObstacles)
            obstacle = environment.StaticObstacles(i);
            distance = norm(position(1:2) - obstacle.center);

            if distance < obstacle.radius
                hasCollision = true;
                break;
            end

        end

    end

end
