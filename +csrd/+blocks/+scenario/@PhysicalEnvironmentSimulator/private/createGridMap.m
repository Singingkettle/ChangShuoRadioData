function grid = createGridMap(obj)
    % createGridMap - Create grid-based map representation
    %
    % Output Arguments:
    %   grid - Grid map structure

    if ~isfield(obj.mapData, 'Boundaries') || isempty(obj.mapData.Boundaries)
        error('CSRD:Construction:MissingMapBoundaries', ...
            'createGridMap requires explicit map boundaries.');
    end
    bounds = obj.mapData.Boundaries;
    if isfield(bounds, 'MinLatitude')
        bounds = geoBoundsToLocalMeterBounds(bounds);
    end

    resolution = 100; % meters per grid cell

    gridSizeX = ceil((bounds(2) - bounds(1)) / resolution);
    gridSizeY = ceil((bounds(4) - bounds(3)) / resolution);

    grid = struct();
    grid.resolution = resolution;
    grid.size = [gridSizeX, gridSizeY];
    grid.occupancy = zeros(gridSizeY, gridSizeX); % 0 = free, 1 = occupied
end
