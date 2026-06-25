function initializeStatisticalMap(obj)
    % initializeStatisticalMap - Initialize statistical/logical map
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
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

    channelModel = resolveStatisticalChannelModel(obj);

    % The Statistical-map boundaries are LOCAL METERS [xmin xmax ymin ymax],
    % but createEntity/applyBoundaryConstraints consume a geographic
    % {Min/MaxLat,Min/MaxLon} struct and run it through geoToLocalMeters
    % (meters = deg2rad(deg) * earthRadius). Storing the raw metre extents as
    % degrees made a +/-2000 m map become +/-2000 DEGREES, which
    % geoToLocalMeters then blew up by deg2rad*earthRadius (~37000x): emitters
    % were placed hundreds of thousands of km away, giving ~200 dB path loss
    % and ~-90 dB SNR for every link. Convert metres to degrees with the exact
    % inverse of geoToLocalMeters so the geographic round-trip reproduces the
    % intended metre extents.
    metresPerDegree = getEarthRadiusMeters() * pi / 180; % inverse of geoToLocalMeters
    obj.mapData.Boundaries = struct( ...
        'MinLatitude', boundaries(3) / metresPerDegree, ...
        'MaxLatitude', boundaries(4) / metresPerDegree, ...
        'MinLongitude', boundaries(1) / metresPerDegree, ...
        'MaxLongitude', boundaries(2) / metresPerDegree, ...
        'CenterLatitude', ((boundaries(3) + boundaries(4)) / 2) / metresPerDegree, ...
        'CenterLongitude', ((boundaries(1) + boundaries(2)) / 2) / metresPerDegree);
    obj.mapData.MapProfile = struct( ...
        'Mode', 'Statistical', ...
        'OSMFile', '', ...
        'HasBuildings', false, ...
        'Terrain', '', ...
        'TerrainMaterial', '', ...
        'MaxNumReflections', [], ...
        'ChannelModel', channelModel, ...
        'Boundaries', obj.mapData.Boundaries);

    % Update configuration
    obj.Config.Map.Type = 'Grid';
    obj.Config.Map.Boundaries = boundaries;
    obj.Config.Map.MapProfile = obj.mapData.MapProfile;
    if ~isfield(obj.Config, 'Environment') || ~isstruct(obj.Config.Environment)
        obj.Config.Environment = struct();
    end
    obj.Config.Environment.MapProfile = obj.mapData.MapProfile;
    obj.Config.Environment.ChannelModel = channelModel;

    obj.logger.debug(['Statistical map initialized with boundaries: ', ...
        '[%.0f, %.0f, %.0f, %.0f] meters and channel model %s'], ...
        boundaries(1), boundaries(2), boundaries(3), boundaries(4), channelModel);
end

function channelModel = resolveStatisticalChannelModel(obj)
    % resolveStatisticalChannelModel - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    channelModel = 'Statistical';
    if isfield(obj.Config, 'Environment') && ...
            isstruct(obj.Config.Environment) && ...
            isfield(obj.Config.Environment, 'ChannelModel') && ...
            ~isempty(obj.Config.Environment.ChannelModel)
        channelModel = char(string(obj.Config.Environment.ChannelModel));
    elseif isfield(obj.Config, 'Map') && isstruct(obj.Config.Map) && ...
            isfield(obj.Config.Map, 'Statistical') && ...
            isstruct(obj.Config.Map.Statistical) && ...
            isfield(obj.Config.Map.Statistical, 'ChannelModel') && ...
            ~isempty(obj.Config.Map.Statistical.ChannelModel)
        channelModel = char(string(obj.Config.Map.Statistical.ChannelModel));
    end
end
