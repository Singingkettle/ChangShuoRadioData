function hasCollision = checkObstacleCollision(obj, position, environment)
    % checkObstacleCollision - Simple collision detection with static obstacles
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
