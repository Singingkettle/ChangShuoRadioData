function initializeOSMMap(obj)
    % initializeOSMMap - Initialize OSM map for ray tracing
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 initializeOSMMap 实现。
    %
    % Loads OSM file and creates site viewer for ray tracing channel modeling

    osmFile = '';

    if isfield(obj.Config, 'Environment') && isfield(obj.Config.Environment, 'OSMMapFile')
        osmFile = obj.Config.Environment.OSMMapFile;
    elseif isfield(obj.Config, 'Map') && isfield(obj.Config.Map, 'OSMFile')
        osmFile = obj.Config.Map.OSMFile;
    end

    if isempty(osmFile) || ~isfile(osmFile)
        obj.logger.warning('OSM map file not found or not specified: %s. Falling back to statistical mode.', osmFile);
        initializeStatisticalMap(obj);
        return;
    end

    if ~isfield(obj.Config, 'Environment') || ~isstruct(obj.Config.Environment)
        obj.Config.Environment = struct();
    end
    if ~isfield(obj.Config, 'Map') || ~isstruct(obj.Config.Map)
        obj.Config.Map = struct();
    end

    obj.logger.debug('Loading OSM map: %s', osmFile);

    % Initialize boundaries from OSM filename
    [~, fname, ~] = fileparts(osmFile);
    pattern = '_(-?\d+\.?\d*)_(-?\d+\.?\d*)$';
    tokens = regexp(fname, pattern, 'tokens');

    % Initialize default boundaries
    defaultBoundaries = struct( ...
        'MinLatitude', -90, ...
        'MaxLatitude', 90, ...
        'MinLongitude', -180, ...
        'MaxLongitude', 180, ...
        'CenterLatitude', 0, ...
        'CenterLongitude', 0);

    if ~isempty(tokens) && numel(tokens{1}) == 2
        centerLat = str2double(tokens{1}{1});
        centerLon = str2double(tokens{1}{2});

        if ~isnan(centerLat) && ~isnan(centerLon)
            % Calculate bounding box for OSM file
            [minLat, minLon, maxLat, maxLon] = calculateBoundingBox(obj, centerLat, centerLon, obj.BoxSizeKM);

            obj.mapData.Boundaries = struct( ...
                'MinLatitude', minLat, ...
                'MaxLatitude', maxLat, ...
                'MinLongitude', minLon, ...
                'MaxLongitude', maxLon, ...
                'CenterLatitude', centerLat, ...
                'CenterLongitude', centerLon);
            obj.logger.debug('OSM boundaries extracted from filename: [%.6f, %.6f, %.6f, %.6f]', ...
                minLat, maxLat, minLon, maxLon);
        else
            obj.logger.warning('Invalid coordinates in OSM filename. Using default boundaries.');
            obj.mapData.Boundaries = defaultBoundaries;
        end

    else
        obj.logger.warning('Could not parse coordinates from OSM filename. Using default boundaries.');
        obj.mapData.Boundaries = defaultBoundaries;
    end

    % Check if OSM file contains building data before loading
    hasBuildingData = checkOSMHasBuildings(obj, osmFile);
    osmConfig = getOSMConfig(obj);
    emptyGeometryPolicy = getFieldOrDefault(osmConfig, 'EmptyGeometryPolicy', 'FlatTerrain');
    flatTerrainConfig = getFieldOrDefault(osmConfig, 'FlatTerrain', struct());
    flatTerrain = getFieldOrDefault(flatTerrainConfig, 'Terrain', 'none');
    flatTerrainMaterial = getFieldOrDefault(flatTerrainConfig, 'Material', 'seawater');
    flatMaxReflections = getFieldOrDefault(flatTerrainConfig, 'MaxNumReflections', 1);
    channelModel = resolveOSMChannelModel(obj);

    try

        if hasBuildingData
            obj.logger.debug('OSM file contains building data, loading with buildings');
            obj.siteViewer = siteviewer('Basemap', 'openstreetmap', ...
                'Buildings', osmFile, ...
                'Hidden', true);
            obj.logger.debug('OSM map loaded successfully with buildings');
            obj.Config.Map.Type = 'OSM';
            obj.Config.Map.OSMFile = osmFile;
            obj.Config.Map.HasBuildings = true;

            mapProfile = buildMapProfile('OSMBuildings', osmFile, true, ...
                'gmted2010', 'auto', [], obj.mapData.Boundaries, channelModel);
            obj.mapData.MapProfile = mapProfile;
            obj.Config.Map.MapProfile = mapProfile;
            obj.Config.Environment.MapProfile = mapProfile;
            obj.Config.Environment.ChannelModel = channelModel;
        else
            if ~strcmpi(emptyGeometryPolicy, 'FlatTerrain')
                error('PhysicalEnvironmentSimulator:NoBuildingData', ...
                    'OSM file "%s" contains no building data and EmptyGeometryPolicy is "%s".', ...
                    osmFile, emptyGeometryPolicy);
            end

            obj.logger.warning('OSM file has no building data: %s. Using flat terrain ray tracing fallback.', osmFile);
            obj.siteViewer = [];
            obj.logger.debug('Flat terrain fallback initialized without site viewer. Ray tracing will use Map="%s".', flatTerrain);

            obj.Config.Map.Type = 'OSM';
            obj.Config.Map.OSMFile = osmFile;
            obj.Config.Map.HasBuildings = false;

            mapProfile = buildMapProfile('FlatTerrain', osmFile, false, ...
                flatTerrain, flatTerrainMaterial, flatMaxReflections, ...
                obj.mapData.Boundaries, channelModel);
            obj.mapData.MapProfile = mapProfile;
            obj.Config.Map.MapProfile = mapProfile;
            obj.Config.Environment.MapProfile = mapProfile;
            obj.Config.Environment.ChannelModel = channelModel;
        end

    catch ME_viewer

        if strcmp(ME_viewer.identifier, 'PhysicalEnvironmentSimulator:NoBuildingData')
            rethrow(ME_viewer);
        end

        if strcmpi(channelModel, 'RayTracing')
            error('PhysicalEnvironmentSimulator:OSMBuildingRayTracingUnavailable', ...
                ['Failed to create OSM building site viewer for RayTracing: %s. ', ...
                 'This environment limitation must be handled as an explicit skip ', ...
                 'or annotated fallback by the caller.'], ME_viewer.message);
        end

        obj.logger.error('Failed to create site viewer: %s. Using configured statistical mode.', ME_viewer.message);
        initializeStatisticalMap(obj);
    end

end

function channelModel = resolveOSMChannelModel(obj)
    % resolveOSMChannelModel - Production declaration in CSRD.
    % 中文说明：resolveOSMChannelModel 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    channelModel = 'RayTracing';
    if isfield(obj.Config, 'Environment') && ...
            isstruct(obj.Config.Environment) && ...
            isfield(obj.Config.Environment, 'ChannelModel') && ...
            ~isempty(obj.Config.Environment.ChannelModel)
        channelModel = char(string(obj.Config.Environment.ChannelModel));
    elseif isfield(obj.Config, 'Map') && isstruct(obj.Config.Map) && ...
            isfield(obj.Config.Map, 'OSM') && isstruct(obj.Config.Map.OSM) && ...
            isfield(obj.Config.Map.OSM, 'ChannelModel') && ...
            ~isempty(obj.Config.Map.OSM.ChannelModel)
        channelModel = char(string(obj.Config.Map.OSM.ChannelModel));
    end
end

function osmConfig = getOSMConfig(obj)
    % getOSMConfig - Production declaration in CSRD.
    % 中文说明：getOSMConfig 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    osmConfig = struct();
    if isfield(obj.Config, 'Map') && isfield(obj.Config.Map, 'OSM') && isstruct(obj.Config.Map.OSM)
        osmConfig = obj.Config.Map.OSM;
    end
end

function value = getFieldOrDefault(s, fieldName, defaultValue)
    % getFieldOrDefault - Production declaration in CSRD.
    % 中文说明：getFieldOrDefault 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end

function mapProfile = buildMapProfile(mode, osmFile, hasBuildings, ...
        terrain, terrainMaterial, maxNumReflections, boundaries, channelModel)
            % buildMapProfile - Production declaration in CSRD.
            % 中文说明：buildMapProfile 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
    mapProfile = struct();
    mapProfile.Mode = mode;
    mapProfile.OSMFile = osmFile;
    mapProfile.HasBuildings = hasBuildings;
    mapProfile.Terrain = terrain;
    mapProfile.TerrainMaterial = terrainMaterial;
    mapProfile.MaxNumReflections = maxNumReflections;
    mapProfile.ChannelModel = channelModel;
    mapProfile.Boundaries = boundaries;
end
