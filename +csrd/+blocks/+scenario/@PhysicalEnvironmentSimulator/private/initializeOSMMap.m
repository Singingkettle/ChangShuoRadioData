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

    try

        if hasBuildingData
            % Create site viewer with OSM buildings
            obj.logger.debug('OSM file contains building data, loading with buildings');
            obj.siteViewer = siteviewer('Basemap', 'openstreetmap', ...
                'Buildings', osmFile, ...
                'Hidden', true);
            obj.logger.debug('OSM map loaded successfully with buildings');
        else
            % Create site viewer without buildings (just the basemap)
            obj.logger.debug('OSM file has no building data, loading basemap only');
            obj.siteViewer = siteviewer('Basemap', 'openstreetmap', ...
                'Hidden', true);
            obj.logger.debug('OSM basemap loaded without building data');
        end

        obj.Config.Map.Type = 'OSM';
        obj.Config.Map.OSMFile = osmFile;

    catch ME_viewer
        obj.logger.error('Failed to create site viewer: %s. Using statistical mode.', ME_viewer.message);
        initializeStatisticalMap(obj);
    end

end
