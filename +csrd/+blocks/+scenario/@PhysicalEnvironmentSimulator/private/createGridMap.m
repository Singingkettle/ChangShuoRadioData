function grid = createGridMap(obj)
    % createGridMap - Create grid-based map representation
    %
    % Output Arguments:
    %   grid - Grid map structure

    % Check if boundaries exist, if not use default
    if isfield(obj.mapData, 'Boundaries') && ~isempty(obj.mapData.Boundaries)
        bounds = obj.mapData.Boundaries;

        % Handle both OSM-style and grid-style boundaries
        if isfield(bounds, 'MinLatitude')
            % OSM-style boundaries - convert to grid format
            bounds = [bounds.MinLongitude, bounds.MaxLongitude, bounds.MinLatitude, bounds.MaxLatitude];
        end

    else
        % Use default grid boundaries if not set
        obj.logger.warning('Map boundaries not set, using default boundaries for grid map');
        bounds = [-1000, 1000, -1000, 1000]; % [xmin, xmax, ymin, ymax]
    end

    resolution = 100; % meters per grid cell

    gridSizeX = ceil((bounds(2) - bounds(1)) / resolution);
    gridSizeY = ceil((bounds(4) - bounds(3)) / resolution);

    grid = struct();
    grid.resolution = resolution;
    grid.size = [gridSizeX, gridSizeY];
    grid.occupancy = zeros(gridSizeY, gridSizeX); % 0 = free, 1 = occupied
end
