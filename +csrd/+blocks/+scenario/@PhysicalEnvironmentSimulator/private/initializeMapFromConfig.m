function initializeMapFromConfig(obj)
    %INITIALIZEMAPFROMCONFIG Initialize the explicitly configured map model.

    if obj.mapInitialized
        return;
    end

    mapType = localResolveMapType(obj.Config);
    obj.logger.debug('Initializing map with type: %s', mapType);

    switch mapType
        case 'OSM'
            initializeOSMMap(obj);
        case {'Statistical', 'Grid'}
            initializeStatisticalMap(obj);
        otherwise
            error('CSRD:Scenario:UnsupportedMapType', ...
                'Unsupported map type "%s". Supported map types are OSM, Statistical, and Grid.', ...
                mapType);
    end

    obj.mapInitialized = true;
end

function mapType = localResolveMapType(config)
if ~isstruct(config)
    error('CSRD:Scenario:MissingMapType', ...
        'PhysicalEnvironmentSimulator.Config must be a struct with Map.Type or Environment.MapType.');
end

if isfield(config, 'Environment') && isstruct(config.Environment) && ...
        isfield(config.Environment, 'MapType') && ~isempty(config.Environment.MapType)
    mapType = char(string(config.Environment.MapType));
    return;
end

if isfield(config, 'Map') && isstruct(config.Map) && ...
        isfield(config.Map, 'Type') && ~isempty(config.Map.Type)
    mapType = char(string(config.Map.Type));
    return;
end

error('CSRD:Scenario:MissingMapType', ...
    'PhysicalEnvironmentSimulator requires Config.Map.Type or Config.Environment.MapType.');
end
