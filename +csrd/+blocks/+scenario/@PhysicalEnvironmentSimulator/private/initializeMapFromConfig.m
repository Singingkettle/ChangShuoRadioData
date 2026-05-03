function initializeMapFromConfig(obj)
    % initializeMapFromConfig - Initialize map based on configuration
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 initializeMapFromConfig 实现。
    %
    % This method initializes the map based on the MapType in configuration:
    % - 'Statistical': Uses logical boundaries for statistical channel modeling
    % - 'OSM': Loads OSM file and creates site viewer for ray tracing

    if obj.mapInitialized
        return; % Already initialized
    end

    % Determine map type from configuration
    mapType = 'Statistical'; % Default

    if isfield(obj.Config, 'Environment') && isfield(obj.Config.Environment, 'MapType')
        mapType = obj.Config.Environment.MapType;
    elseif isfield(obj.Config, 'Map') && isfield(obj.Config.Map, 'Type')
        mapType = obj.Config.Map.Type;
    end

    obj.logger.debug('Initializing map with type: %s', mapType);

    switch mapType
        case 'OSM'
            initializeOSMMap(obj);
        case {'Statistical', 'Grid'}
            initializeStatisticalMap(obj);
        otherwise
            obj.logger.warning('Unknown map type: %s, defaulting to Statistical', mapType);
            initializeStatisticalMap(obj);
    end

    obj.mapInitialized = true;
end
