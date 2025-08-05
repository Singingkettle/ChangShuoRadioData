function obstacles = generateStaticObstacles(obj)
    % generateStaticObstacles - Generate random static obstacles within map boundaries
    %
    % Output Arguments:
    %   obstacles - Array of obstacle structures with position and size

    % Check if boundaries exist, if not use default
    if isfield(obj.mapData, 'Boundaries') && ~isempty(obj.mapData.Boundaries)
        bounds = obj.mapData.Boundaries;
    else
        % Use default boundaries if not set
        obj.logger.warning('Map boundaries not set, using default boundaries for obstacle generation');
        bounds = struct( ...
            'MinLatitude', -1000, ...
            'MaxLatitude', 1000, ...
            'MinLongitude', -1000, ...
            'MaxLongitude', 1000);
    end

    numObstacles = randi([5, 15]);
    obstacles = [];

    for i = 1:numObstacles
        obstacle = struct();

        if isfield(bounds, 'MinLatitude')
            % OSM-style boundaries
            obstacle.center = [
                               randomInRange(obj, bounds.MinLongitude, bounds.MaxLongitude),
                               randomInRange(obj, bounds.MinLatitude, bounds.MaxLatitude)
                               ];
        else
            % Grid-style boundaries
            obstacle.center = [
                               randomInRange(obj, bounds(1), bounds(2)),
                               randomInRange(obj, bounds(3), bounds(4))
                               ];
        end

        obstacle.radius = randomInRange(obj, 20, 100); % meters
        obstacle.height = randomInRange(obj, 10, 50); % meters
        obstacles = [obstacles, obstacle];
    end

end
