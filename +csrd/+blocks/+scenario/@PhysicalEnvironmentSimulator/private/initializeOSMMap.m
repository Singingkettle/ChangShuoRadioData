function initializeOSMMap(obj)
    % initializeOSMMap - Initialize OSM map for ray tracing
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
                'gmted2010', 'auto', [], obj.mapData.Boundaries);
            obj.mapData.MapProfile = mapProfile;
            obj.Config.Map.MapProfile = mapProfile;
            obj.Config.Environment.MapProfile = mapProfile;
            obj.Config.Environment.ChannelModel = 'RayTracing';
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
                flatTerrain, flatTerrainMaterial, flatMaxReflections, obj.mapData.Boundaries);
            obj.mapData.MapProfile = mapProfile;
            obj.Config.Map.MapProfile = mapProfile;
            obj.Config.Environment.MapProfile = mapProfile;
            obj.Config.Environment.ChannelModel = 'RayTracing';
        end

    catch ME_viewer

        if strcmp(ME_viewer.identifier, 'PhysicalEnvironmentSimulator:NoBuildingData')
            rethrow(ME_viewer);
        end

        obj.logger.error('Failed to create site viewer: %s. Using statistical mode.', ME_viewer.message);
        initializeStatisticalMap(obj);
    end

end

function osmConfig = getOSMConfig(obj)
    osmConfig = struct();
    if isfield(obj.Config, 'Map') && isfield(obj.Config.Map, 'OSM') && isstruct(obj.Config.Map.OSM)
        osmConfig = obj.Config.Map.OSM;
    end
end

function value = getFieldOrDefault(s, fieldName, defaultValue)
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end

function mapProfile = buildMapProfile(mode, osmFile, hasBuildings, terrain, terrainMaterial, maxNumReflections, boundaries)
    mapProfile = struct();
    mapProfile.Mode = mode;
    mapProfile.OSMFile = osmFile;
    mapProfile.HasBuildings = hasBuildings;
    mapProfile.Terrain = terrain;
    mapProfile.TerrainMaterial = terrainMaterial;
    mapProfile.MaxNumReflections = maxNumReflections;
    mapProfile.ChannelModel = 'RayTracing';
    mapProfile.Boundaries = boundaries;
end
