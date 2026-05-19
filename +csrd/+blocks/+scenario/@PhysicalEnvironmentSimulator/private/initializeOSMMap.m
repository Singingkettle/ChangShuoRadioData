function initializeOSMMap(obj)
    % initializeOSMMap - Initialize OSM map for ray tracing
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 initializeOSMMap 实现。
    %
    % Loads lightweight OSM metadata. The heavy siteviewer/map handle is
    % owned by the RayTracing channel block so one OSM file is not loaded
    % once by the physical layer and again by the propagation layer.

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

    osmConfig = getOSMConfig(obj);
    if isfield(osmConfig, 'MaxFileSizeMB') && ~isempty(osmConfig.MaxFileSizeMB)
        error('CSRD:Scenario:DeprecatedOsmSizeCap', ...
            ['PhysicalEnvironment.Map.OSM.MaxFileSizeMB is deprecated. ', ...
             'OSM file selection must use file-level balanced coverage, not size caps.']);
    end
    osmFileSizeMB = getFieldOrDefault(osmConfig, ...
        'SelectedFileSizeMB', localFileSizeMB(osmFile));
    selectionPolicy = getFieldOrDefault(osmConfig, ...
        'SelectionPolicy', 'Unknown');
    coverageOrdinal = getFieldOrDefault(osmConfig, 'CoverageOrdinal', NaN);
    candidateFileCount = getFieldOrDefault(osmConfig, 'CandidateFileCount', NaN);

    % Check if OSM file contains building data before loading
    hasBuildingData = checkOSMHasBuildings(obj, osmFile);
    emptyGeometryPolicy = getFieldOrDefault(osmConfig, 'EmptyGeometryPolicy', 'FlatTerrain');
    flatTerrainConfig = getFieldOrDefault(osmConfig, 'FlatTerrain', struct());
    flatTerrain = getFieldOrDefault(flatTerrainConfig, 'Terrain', 'none');
    flatTerrainMaterial = getFieldOrDefault(flatTerrainConfig, 'Material', 'seawater');
    flatMaxReflections = getFieldOrDefault(flatTerrainConfig, 'MaxNumReflections', 1);
    channelModel = resolveOSMChannelModel(obj);

    try

        if hasBuildingData
            obj.logger.debug(['OSM file contains building data; deferring ', ...
                'heavy map handle creation to RayTracing.']);
            obj.siteViewer = [];
            obj.Config.Map.Type = 'OSM';
            obj.Config.Map.OSMFile = osmFile;
            obj.Config.Map.HasBuildings = true;

            mapProfile = buildMapProfile('OSMBuildings', osmFile, true, ...
                'none', 'concrete', [], obj.mapData.Boundaries, channelModel);
            mapProfile = stampOsmRuntimeMetadata(mapProfile, osmFileSizeMB, ...
                selectionPolicy, coverageOrdinal, candidateFileCount);
            mapProfile.MapResourcePolicy = 'LazyRayTracingSiteViewer';
            mapProfile.TerrainPolicy = 'NoOnlineTerrainForBatchRayTracing';
            mapProfile.MaterialPolicy = 'OverrideUnsupportedOsmMaterials';
            mapProfile.MaterialSanitizationPolicy = 'UnsupportedOsmMaterialsBecomeConcreteCopy';
            mapProfile.BuildingsMaterial = 'concrete';
            mapProfile.SurfaceMaterial = 'plasterboard';
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
            mapProfile = stampOsmRuntimeMetadata(mapProfile, osmFileSizeMB, ...
                selectionPolicy, coverageOrdinal, candidateFileCount);
            mapProfile.MapResourcePolicy = 'NoSiteViewer';
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
            error('PhysicalEnvironmentSimulator:OSMMetadataUnavailable', ...
                ['Failed to initialize OSM metadata for RayTracing: %s. ', ...
                 'Do not silently downgrade a RayTracing scenario to ', ...
                 'statistical propagation.'], ME_viewer.message);
        end

        obj.logger.error('Failed to initialize OSM metadata: %s. Using configured statistical mode.', ME_viewer.message);
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

function mapProfile = stampOsmRuntimeMetadata(mapProfile, osmFileSizeMB, ...
        selectionPolicy, coverageOrdinal, candidateFileCount)
    %STAMPOSMRUNTIMEMETADATA Attach OSM file-coverage provenance.
    % 中文说明：这些字段进入 MapProfile，供 RayTracing trace 和 annotation 使用。
    mapProfile.OSMFileSizeMB = osmFileSizeMB;
    mapProfile.SelectionPolicy = char(string(selectionPolicy));
    mapProfile.CoverageOrdinal = coverageOrdinal;
    mapProfile.CandidateFileCount = candidateFileCount;
end

function sizeMB = localFileSizeMB(pathText)
    sizeMB = NaN;
    if isempty(pathText)
        return;
    end
    info = dir(char(string(pathText)));
    if ~isempty(info)
        sizeMB = double(info.bytes) / 1024 / 1024;
    end
end
