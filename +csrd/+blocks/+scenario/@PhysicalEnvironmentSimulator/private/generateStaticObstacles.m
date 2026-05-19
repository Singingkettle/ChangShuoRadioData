function obstacles = generateStaticObstacles(obj)
    % generateStaticObstacles - Generate random static obstacles within map boundaries
    % 中文说明：提供 CSRD 生产链路中的 generateStaticObstacles 实现。
    %
    % Output Arguments:
    %   obstacles - Array of obstacle structures with position and size

    if ~isfield(obj.mapData, 'Boundaries') || isempty(obj.mapData.Boundaries)
        error('CSRD:Construction:MissingMapBoundaries', ...
            'generateStaticObstacles requires explicit map boundaries.');
    end
    bounds = obj.mapData.Boundaries;

    numObstacles = randi([5, 15]);
    obstacles = [];

    for i = 1:numObstacles
        obstacle = struct();

        if isfield(bounds, 'MinLatitude')
            latDeg = randomInRange(obj, bounds.MinLatitude, bounds.MaxLatitude);
            lonDeg = randomInRange(obj, bounds.MinLongitude, bounds.MaxLongitude);
            obstacle.center = geoToLocalMeters(latDeg, lonDeg, bounds);
            obstacle.geoCenterDeg = [latDeg, lonDeg];
            obstacle.PositionUnit = 'meters';
        else
            obstacle.center = [
                               randomInRange(obj, bounds(1), bounds(2)),
                               randomInRange(obj, bounds(3), bounds(4))
                               ];
            obstacle.geoCenterDeg = [];
            obstacle.PositionUnit = 'meters';
        end

        obstacle.radius = randomInRange(obj, 20, 100); % meters
        obstacle.height = randomInRange(obj, 10, 50); % meters
        obstacles = [obstacles, obstacle];
    end

end
