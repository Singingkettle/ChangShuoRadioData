classdef RayTracing < matlab.System

    properties
        MapFilename char = ''
        SampleRate (1, 1) {mustBePositive, mustBeFinite} = 1e6
        CarrierFrequency (1, 1) {mustBePositive, mustBeFinite} = 2.4e9
        PropagationModelConfig struct = struct()
        NoValidPathFallback char = 'FreeSpaceAttenuation'
    end

    properties (SetAccess = private)
        GeneratedTxSites
        GeneratedRxSites
    end

    properties (Access = private)
        logger
        siteViewerCache
        siteViewerKey char = ''
    end

    methods

        function obj = RayTracing(varargin)
            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function setupImpl(obj, varargin) %#ok<INUSD>
            obj.logger = csrd.utils.logger.GlobalLogManager.getLogger();
            obj.PropagationModelConfig = normalizePropagationConfig(obj.PropagationModelConfig);
        end

        function validateInputsImpl(~, ~, ~, ~, ~)
        end

        function out = stepImpl(obj, x, txInfo, rxInfo, channelLinkInfo)
            if nargin < 5 || ~isstruct(channelLinkInfo)
                channelLinkInfo = struct();
            end

            out = x;
            if ~isfield(x, 'Signal') || isempty(x.Signal)
                out.RayCount = 0;
                out.ChannelModel = 'RayTracing';
                return;
            end

            mapProfile = obj.resolveMapProfile(channelLinkInfo);
            carrierFrequency = obj.resolveCarrierFrequency(txInfo, rxInfo, channelLinkInfo);
            [txSite, rxSite] = obj.createSites(txInfo, rxInfo, carrierFrequency);
            obj.GeneratedTxSites = txSite;
            obj.GeneratedRxSites = rxSite;

            try
                pm = obj.createPropagationModel(mapProfile);
                [raySet, rayCount, rayPathLoss] = obj.computeRays(txSite, rxSite, pm, mapProfile);

                if rayCount == 0
                    out = obj.applyNoPathFallback(out, txInfo, rxInfo, channelLinkInfo, mapProfile, carrierFrequency, []);
                    return;
                end

                rtChan = comm.RayTracingChannel(raySet, txSite, rxSite);
                rtChan.SampleRate = obj.resolveSampleRate(x, rxInfo);
                out.Signal = rtChan(x.Signal);
                out.RayCount = rayCount;
                out.ChannelModel = 'RayTracing';
                out.ChannelFallback = '';
                if ~isempty(rayPathLoss)
                    out.PathLoss = rayPathLoss;
                    out.AppliedPathLoss = rayPathLoss;
                end
                out.ChannelInfo = obj.buildChannelInfo(mapProfile, carrierFrequency, rayCount, ...
                    getStructField(out, 'PathLoss', []), '');
            catch ME
                if obj.shouldFallback(mapProfile, channelLinkInfo)
                    obj.logger.warning('RayTracing failed for map mode %s; applying %s fallback. Error: %s', ...
                        string(getStructField(mapProfile, 'Mode', 'Unknown')), obj.NoValidPathFallback, ME.message);
                    out = obj.applyNoPathFallback(out, txInfo, rxInfo, channelLinkInfo, mapProfile, carrierFrequency, ME.message);
                else
                    error('RayTracing:ExecutionFailed', 'Ray tracing failed: %s', ME.message);
                end
            end
        end

        function releaseImpl(obj)
            tryDeleteSiteViewer(obj.siteViewerCache);
            obj.siteViewerCache = [];
            obj.siteViewerKey = '';
        end

    end

    methods (Access = private)

        function mapProfile = resolveMapProfile(obj, channelLinkInfo)
            mapProfile = getStructField(channelLinkInfo, 'MapProfile', struct());
            if ~isempty(fieldnames(mapProfile))
                return;
            end

            hasBuildings = ~isempty(obj.MapFilename) && isfile(obj.MapFilename) && ...
                csrd.utils.osmHasBuildings(obj.MapFilename);

            mapProfile = struct();
            if hasBuildings
                mapProfile.Mode = 'OSMBuildings';
                mapProfile.HasBuildings = true;
                mapProfile.Terrain = 'gmted2010';
                mapProfile.TerrainMaterial = 'auto';
                mapProfile.MaxNumReflections = [];
            else
                mapProfile.Mode = 'FlatTerrain';
                mapProfile.HasBuildings = false;
                mapProfile.Terrain = 'none';
                mapProfile.TerrainMaterial = 'seawater';
                mapProfile.MaxNumReflections = 1;
            end
            mapProfile.OSMFile = obj.MapFilename;
            mapProfile.ChannelModel = 'RayTracing';
        end

        function carrierFrequency = resolveCarrierFrequency(obj, txInfo, rxInfo, channelLinkInfo)
            carrierFrequency = obj.CarrierFrequency;
            rxScenarioConfig = getStructField(channelLinkInfo, 'RxScenarioConfig', struct());

            if isfield(rxScenarioConfig, 'Observation') && isfield(rxScenarioConfig.Observation, 'RealCarrierFrequency')
                carrierFrequency = rxScenarioConfig.Observation.RealCarrierFrequency;
            elseif isfield(rxInfo, 'RealCarrierFrequency')
                carrierFrequency = rxInfo.RealCarrierFrequency;
            elseif isfield(txInfo, 'RealCarrierFrequency')
                carrierFrequency = txInfo.RealCarrierFrequency;
            end
        end

        function sampleRate = resolveSampleRate(obj, x, rxInfo)
            sampleRate = obj.SampleRate;
            if isfield(x, 'SampleRate') && ~isempty(x.SampleRate) && x.SampleRate > 0
                sampleRate = x.SampleRate;
            elseif isfield(rxInfo, 'SampleRate') && ~isempty(rxInfo.SampleRate) && rxInfo.SampleRate > 0
                sampleRate = rxInfo.SampleRate;
            end
        end

        function [txSite, rxSite] = createSites(~, txInfo, rxInfo, carrierFrequency)
            txPos = getStructField(txInfo, 'Position', [0, 0, 30]);
            rxPos = getStructField(rxInfo, 'Position', [0, 0, 10]);

            txHeight = max(getPositionComponent(txPos, 3, 30), 0.1);
            rxHeight = max(getPositionComponent(rxPos, 3, 10), 0.1);
            txName = char(string(getStructField(txInfo, 'ID', 'Tx')));
            rxName = char(string(getStructField(rxInfo, 'ID', 'Rx')));

            txArgs = {'Name', txName, ...
                      'Latitude', getPositionComponent(txPos, 2, 0), ...
                      'Longitude', getPositionComponent(txPos, 1, 0), ...
                      'AntennaHeight', txHeight, ...
                      'TransmitterFrequency', carrierFrequency};
            rxArgs = {'Name', rxName, ...
                      'Latitude', getPositionComponent(rxPos, 2, 0), ...
                      'Longitude', getPositionComponent(rxPos, 1, 0), ...
                      'AntennaHeight', rxHeight};

            numTxAntennas = max(1, round(getStructField(txInfo, 'NumTransmitAntennas', 1)));
            numRxAntennas = max(1, round(getStructField(rxInfo, 'NumAntennas', 1)));

            try
                txArgs = [txArgs, {'Antenna', arrayConfig('Size', [numTxAntennas, 1], 'ElementSpacing', 0.5)}];
                rxArgs = [rxArgs, {'Antenna', arrayConfig('Size', [numRxAntennas, 1], 'ElementSpacing', 0.5)}];
            catch
                % txsite/rxsite can use default antennas if arrayConfig is unavailable.
            end

            txSite = txsite(txArgs{:});
            rxSite = rxsite(rxArgs{:});
        end

        function pm = createPropagationModel(obj, mapProfile)
            cfg = normalizePropagationConfig(obj.PropagationModelConfig);
            mode = getStructField(mapProfile, 'Mode', '');

            if strcmpi(mode, 'FlatTerrain')
                flatReflections = getStructField(mapProfile, 'MaxNumReflections', []);
                if ~isempty(flatReflections)
                    cfg.MaxNumReflections = flatReflections;
                end
                cfg.MaxNumDiffractions = 0;
            end

            pm = propagationModel('raytracing');
            setPropagationProperty(obj, pm, 'Method', cfg.Method);
            setPropagationProperty(obj, pm, 'MaxNumReflections', cfg.MaxNumReflections);
            setPropagationProperty(obj, pm, 'MaxNumDiffractions', cfg.MaxNumDiffractions);

            if strcmpi(mode, 'FlatTerrain')
                material = getStructField(mapProfile, 'TerrainMaterial', 'seawater');
                if ~setPropagationProperty(obj, pm, 'TerrainMaterial', material) && strcmpi(material, 'seawater')
                    setPropagationProperty(obj, pm, 'TerrainMaterial', 'water');
                end
            end
        end

        function [raySet, rayCount, pathLoss] = computeRays(obj, txSite, rxSite, pm, mapProfile)
            raySet = [];
            rayCount = 0;
            pathLoss = [];
            mapArg = obj.resolveMapArgument(mapProfile);

            if isempty(mapArg)
                rays = raytrace(txSite, rxSite, pm);
            else
                rays = raytrace(txSite, rxSite, pm, 'Map', mapArg);
            end

            if iscell(rays)
                if isempty(rays) || isempty(rays{1})
                    return;
                end
                raySet = rays{1};
            else
                raySet = rays;
            end

            rayCount = numel(raySet);
            pathLoss = extractMinimumPathLoss(raySet);
        end

        function mapArg = resolveMapArgument(obj, mapProfile)
            mapArg = [];
            mode = getStructField(mapProfile, 'Mode', '');
            osmFile = getStructField(mapProfile, 'OSMFile', obj.MapFilename);

            if strcmpi(mode, 'FlatTerrain')
                terrain = getStructField(mapProfile, 'Terrain', 'none');
                mapArg = terrain;
            elseif strcmpi(mode, 'OSMBuildings') && ~isempty(osmFile) && isfile(osmFile)
                key = sprintf('OSMBuildings:%s', osmFile);
                if strcmp(obj.siteViewerKey, key) && ~isempty(obj.siteViewerCache)
                    mapArg = obj.siteViewerCache;
                    return;
                end

                obj.siteViewerCache = siteviewer('Basemap', 'openstreetmap', ...
                    'Buildings', osmFile, 'Hidden', true);
                obj.siteViewerKey = key;
                mapArg = obj.siteViewerCache;
            end
        end

        function tf = shouldFallback(obj, mapProfile, channelLinkInfo)
            fallbackPolicy = getStructField(channelLinkInfo, 'NoValidPathFallback', obj.NoValidPathFallback);
            mode = getStructField(mapProfile, 'Mode', '');
            tf = strcmpi(fallbackPolicy, 'FreeSpaceAttenuation') || strcmpi(mode, 'FlatTerrain');
        end

        function out = applyNoPathFallback(obj, out, txInfo, rxInfo, channelLinkInfo, mapProfile, carrierFrequency, errorMessage)
            fallbackPolicy = getStructField(channelLinkInfo, 'NoValidPathFallback', obj.NoValidPathFallback);
            if ~strcmpi(fallbackPolicy, 'FreeSpaceAttenuation') && ~strcmpi(getStructField(mapProfile, 'Mode', ''), 'FlatTerrain')
                error('RayTracing:NoValidPaths', 'Ray tracing returned no valid paths.');
            end

            pathLoss = getStructField(channelLinkInfo, 'ComputedPathLoss', []);
            if isempty(pathLoss)
                linkDistance = getStructField(channelLinkInfo, 'LinkDistance', []);
                if isempty(linkDistance)
                    linkDistance = geographicDistance(getStructField(txInfo, 'Position', [0, 0, 0]), ...
                        getStructField(rxInfo, 'Position', [0, 0, 0]));
                end
                pathLoss = fspl(max(linkDistance, 1), physconst('LightSpeed') / carrierFrequency);
            end

            attenuation = 10.^(-pathLoss / 20);
            out.Signal = out.Signal .* attenuation;
            out.PathLoss = pathLoss;
            out.AppliedPathLoss = pathLoss;
            out.RayCount = 0;
            out.ChannelModel = 'RayTracing';
            out.ChannelFallback = 'FreeSpaceAttenuation';
            out.ChannelInfo = obj.buildChannelInfo(mapProfile, carrierFrequency, 0, pathLoss, out.ChannelFallback);
            if ~isempty(errorMessage)
                out.ChannelInfo.RayTracingError = errorMessage;
            end
        end

        function channelInfo = buildChannelInfo(~, mapProfile, carrierFrequency, rayCount, pathLoss, fallback)
            channelInfo = struct();
            channelInfo.Model = 'RayTracing';
            channelInfo.MapProfile = mapProfile;
            channelInfo.CarrierFrequency = carrierFrequency;
            channelInfo.RayCount = rayCount;
            channelInfo.PathLoss = pathLoss;
            channelInfo.Fallback = fallback;
        end

        function ok = setPropagationProperty(obj, pm, propName, value)
            ok = false;
            try
                pm.(propName) = value;
                ok = true;
            catch ME
                obj.logger.warning('Could not set RayTracing propagation property %s=%s: %s', ...
                    propName, valueToText(value), ME.message);
            end
        end

    end

end

function tryDeleteSiteViewer(viewerHandle)
    if isempty(viewerHandle)
        return;
    end

    try
        delete(viewerHandle);
    catch
        % Best-effort cleanup only.
    end
end

function cfg = normalizePropagationConfig(cfg)
    if ~isstruct(cfg)
        cfg = struct();
    end
    if ~isfield(cfg, 'Method') || isempty(cfg.Method)
        cfg.Method = 'sbr';
    end
    if ~isfield(cfg, 'MaxNumReflections') || isempty(cfg.MaxNumReflections)
        cfg.MaxNumReflections = 2;
    end
    if ~isfield(cfg, 'MaxNumDiffractions') || isempty(cfg.MaxNumDiffractions)
        cfg.MaxNumDiffractions = 0;
    end
end

function value = getStructField(s, fieldName, defaultValue)
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end

function value = getPositionComponent(position, idx, defaultValue)
    if isnumeric(position) && numel(position) >= idx
        value = position(idx);
    else
        value = defaultValue;
    end
end

function pathLoss = extractMinimumPathLoss(raySet)
    pathLoss = [];
    try
        losses = [raySet.PathLoss];
        if ~isempty(losses)
            pathLoss = min(losses);
        end
    catch
        pathLoss = [];
    end
end

function txt = valueToText(value)
    if ischar(value)
        txt = value;
    elseif isstring(value)
        txt = char(strjoin(value, ','));
    elseif isnumeric(value)
        txt = mat2str(value);
    else
        txt = class(value);
    end
end

function distance_m = geographicDistance(txPos, rxPos)
    earthRadius_m = 6371000;
    lat1 = deg2rad(txPos(2));
    lon1 = deg2rad(txPos(1));
    lat2 = deg2rad(rxPos(2));
    lon2 = deg2rad(rxPos(1));

    dLat = lat2 - lat1;
    dLon = lon2 - lon1;
    a = sin(dLat / 2).^2 + cos(lat1) .* cos(lat2) .* sin(dLon / 2).^2;
    c = 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)));
    horizontalDistance = earthRadius_m * c;

    dz = 0;
    if numel(txPos) >= 3 && numel(rxPos) >= 3
        dz = rxPos(3) - txPos(3);
    end
    distance_m = sqrt(horizontalDistance.^2 + dz.^2);
end
