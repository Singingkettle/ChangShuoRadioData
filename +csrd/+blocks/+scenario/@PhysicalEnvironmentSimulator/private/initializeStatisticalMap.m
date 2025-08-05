function initializeStatisticalMap(obj)
    % initializeStatisticalMap - Initialize statistical/logical map
    %
    % Sets up logical boundaries for statistical channel modeling

    % Get boundaries from configuration
    if isfield(obj.Config, 'Environment') && isfield(obj.Config.Environment, 'MapBoundaries')
        boundaries = obj.Config.Environment.MapBoundaries;
    elseif isfield(obj.Config, 'Map') && isfield(obj.Config.Map, 'Boundaries')
        boundaries = obj.Config.Map.Boundaries;
    else
        boundaries = [-2000, 2000, -2000, 2000]; % Default 4km x 4km
    end

    % Initialize default boundaries in mapData
    obj.mapData.Boundaries = struct( ...
        'MinLatitude', boundaries(3), ...
        'MaxLatitude', boundaries(4), ...
        'MinLongitude', boundaries(1), ...
        'MaxLongitude', boundaries(2), ...
        'CenterLatitude', (boundaries(3) + boundaries(4)) / 2, ...
        'CenterLongitude', (boundaries(1) + boundaries(2)) / 2);

    % Update configuration
    obj.Config.Map.Type = 'Grid';
    obj.Config.Map.Boundaries = boundaries;

    obj.logger.debug('Statistical map initialized with boundaries: [%.0f, %.0f, %.0f, %.0f] meters', ...
        boundaries(1), boundaries(2), boundaries(3), boundaries(4));
end
