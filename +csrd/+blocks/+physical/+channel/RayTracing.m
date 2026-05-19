classdef RayTracing < matlab.System
% 中文说明：提供 CSRD 生产链路中的 RayTracing 实现。

    properties
        MapFilename char = ''
        SampleRate (1, 1) {mustBePositive, mustBeFinite} = 1e6
        CarrierFrequency (1, 1) {mustBePositive, mustBeFinite} = 2.4e9
        PropagationModelConfig struct = struct()
        NoValidPathFallback char = 'FreeSpaceAttenuation'
        UseGPU char = 'auto'
        GpuMinSamples (1, 1) {mustBeNonnegative, mustBeFinite} = 8192
    end

    properties (SetAccess = private)
        GeneratedTxSites
        GeneratedRxSites
    end

    properties (Access = private)
        logger
        siteViewerCache
        siteViewerKey char = ''
        propagationModelCache
        propagationModelKey char = ''
        sitePairCache
        raySetCache
    end

    methods

        function obj = RayTracing(varargin)
            % RayTracing - Production declaration in CSRD.
            % 中文说明：RayTracing 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            setProperties(obj, nargin, varargin{:});
        end

        function precomputeFrameRays(obj, txInfos, rxInfos, channelLinkInfos, frameId)
            %PRECOMPUTEFRAMERAYS Batch raytrace stable Tx/Rx geometry for a frame.
            % 中文说明：按帧批量计算 Tx×Rx rays，segment 处理时复用 raySetCache。
            obj.ensureRuntimeCaches();
            if nargin < 5 || isempty(frameId)
                frameId = NaN;
            end
            if nargin < 4 || isempty(channelLinkInfos) || ...
                    isempty(txInfos) || isempty(rxInfos)
                return;
            end
            if ~iscell(channelLinkInfos)
                channelLinkInfos = {channelLinkInfos};
            end

            mapProfile = obj.resolveMapProfile(channelLinkInfos{1});

            txSiteCells = {};
            rxSiteCells = {};
            txKeyToIndex = containers.Map('KeyType', 'char', 'ValueType', 'double');
            rxKeyToIndex = containers.Map('KeyType', 'char', 'ValueType', 'double');
            pending = struct('RayCacheKey', {}, 'TxIndex', {}, 'RxIndex', {});

            linkIdx = 0;
            for txIdx = 1:numel(txInfos)
                txInfo = localCellOrArrayEntry(txInfos, txIdx);
                if ~isstruct(txInfo) || localHasErrorStatus(txInfo)
                    continue;
                end
                for rxIdx = 1:numel(rxInfos)
                    rxInfo = localCellOrArrayEntry(rxInfos, rxIdx);
                    if ~isstruct(rxInfo) || localHasErrorStatus(rxInfo)
                        continue;
                    end
                    linkIdx = linkIdx + 1;
                    if numel(channelLinkInfos) >= linkIdx
                        linkInfo = channelLinkInfos{linkIdx};
                    else
                        linkInfo = channelLinkInfos{1};
                    end
                    carrierFrequency = obj.resolveCarrierFrequency( ...
                        txInfo, rxInfo, linkInfo);
                    [txSite, rxSite] = obj.createSites(txInfo, rxInfo, carrierFrequency);
                    rayKey = raySetCacheKey(txSite, rxSite, mapProfile);
                    if isa(obj.raySetCache, 'containers.Map') && ...
                            isKey(obj.raySetCache, rayKey)
                        continue;
                    end

                    txKey = siteKeyPart(txSite, true);
                    rxKey = siteKeyPart(rxSite, false);
                    if isKey(txKeyToIndex, txKey)
                        txUniqueIdx = txKeyToIndex(txKey);
                    else
                        txSiteCells{end + 1} = txSite; %#ok<AGROW>
                        txUniqueIdx = numel(txSiteCells);
                        txKeyToIndex(txKey) = txUniqueIdx;
                    end
                    if isKey(rxKeyToIndex, rxKey)
                        rxUniqueIdx = rxKeyToIndex(rxKey);
                    else
                        rxSiteCells{end + 1} = rxSite; %#ok<AGROW>
                        rxUniqueIdx = numel(rxSiteCells);
                        rxKeyToIndex(rxKey) = rxUniqueIdx;
                    end
                    pending(end + 1) = struct( ... %#ok<AGROW>
                        'RayCacheKey', rayKey, ...
                        'TxIndex', txUniqueIdx, ...
                        'RxIndex', rxUniqueIdx);
                end
            end

            if isempty(pending)
                return;
            end

            try
                pm = obj.createPropagationModel(mapProfile);
                mapArg = obj.resolveMapArgument(mapProfile);
                txSiteArray = [txSiteCells{:}];
                rxSiteArray = [rxSiteCells{:}];
                batchMeta = localMapProfileTraceMetadata(mapProfile, ...
                    'NumTxSites', numel(txSiteCells), ...
                    'NumRxSites', numel(rxSiteCells), ...
                    'NumRequestedLinks', numel(pending), ...
                    'FrameId', frameId);
                csrd.runtime.performance.trace('heartbeat', ...
                    'RayTracing.BatchedRaytraceCall', 'begin', batchMeta);
                batchStart = tic;
                if isempty(mapArg)
                    rays = raytrace(txSiteArray, rxSiteArray, pm);
                else
                    rays = raytrace(txSiteArray, rxSiteArray, pm, 'Map', mapArg);
                end
                elapsedSec = toc(batchStart);
                csrd.runtime.performance.trace('count', ...
                    'RayTracing.BatchedRaytraceCall');
                csrd.runtime.performance.trace('event', ...
                    'RayTracing.BatchedRaytraceCall', elapsedSec, batchMeta);
                batchMeta.ElapsedSec = elapsedSec;
                csrd.runtime.performance.trace('heartbeat', ...
                    'RayTracing.BatchedRaytraceCall', 'end', batchMeta);

                for idx = 1:numel(pending)
                    linkRays = localBatchedRayCell(rays, pending(idx).TxIndex, ...
                        pending(idx).RxIndex);
                    [raySet, rayCount, pathLoss] = normalizeRaytraceOutput(linkRays);
                    obj.raySetCache(pending(idx).RayCacheKey) = struct( ...
                        'RaySet', raySet, 'RayCount', rayCount, ...
                        'PathLoss', pathLoss);
                    csrd.runtime.performance.trace('event', ...
                        'RayTracing.RaySetPrecomputeStore', 0, ...
                        localMapProfileTraceMetadata(mapProfile, ...
                            'FrameId', frameId, ...
                            'KeyHash', rayKeyHash(pending(idx).RayCacheKey), ...
                            'RayCount', rayCount, ...
                            'CacheSize', raySetCacheSize(obj.raySetCache)));
                end
            catch ME
                csrd.runtime.performance.trace('event', ...
                    'RayTracing.BatchedRaytraceFailed', 0, ...
                    localMapProfileTraceMetadata(mapProfile, ...
                        'ErrorIdentifier', ME.identifier, ...
                        'ErrorMessage', ME.message, ...
                        'NumRequestedLinks', numel(pending), ...
                        'FrameId', frameId));
                csrd.runtime.performance.trace('heartbeat', ...
                    'RayTracing.BatchedRaytraceCall', 'failed', ...
                    localMapProfileTraceMetadata(mapProfile, ...
                        'ErrorIdentifier', ME.identifier, ...
                        'ErrorMessage', ME.message, ...
                        'NumRequestedLinks', numel(pending), ...
                        'FrameId', frameId));
                if ~isempty(obj.logger)
                    obj.logger.debug('Batched RayTracing precompute skipped: %s', ...
                        ME.message);
                end
                if ~localRayTraceErrorAllowsFallback(ME)
                    rethrow(ME);
                end
            end
        end

    end

    methods (Access = protected)

        function setupImpl(obj, varargin) %#ok<INUSD>
            % setupImpl - Production declaration in CSRD.
            % 中文说明：setupImpl 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            obj.logger = csrd.runtime.logger.GlobalLogManager.getLogger();
            obj.PropagationModelConfig = normalizePropagationConfig(obj.PropagationModelConfig);
            obj.ensureRuntimeCaches();
        end

        function validateInputsImpl(~, ~, ~, ~, ~)
            % validateInputsImpl - Production declaration in CSRD.
            % 中文说明：validateInputsImpl 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
        end

        function out = stepImpl(obj, x, txInfo, rxInfo, channelLinkInfo)
            % stepImpl - Production declaration in CSRD.
            % 中文说明：stepImpl 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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

            executionStage = 'RayTrace';
            try
                pm = obj.createPropagationModel(mapProfile);
                [raySet, rayCount, rayPathLoss, rayFailure] = ...
                    obj.computeRays(txSite, rxSite, pm, mapProfile);

                if rayCount == 0
                    out = obj.applyNoPathFallback(out, txInfo, rxInfo, ...
                        channelLinkInfo, mapProfile, carrierFrequency, rayFailure);
                    return;
                end

                executionStage = 'ChannelConstruct';
                constructMeta = localMapProfileTraceMetadata(mapProfile, ...
                    'RayCount', rayCount);
                csrd.runtime.performance.trace('heartbeat', ...
                    'RayTracing.RayTracingChannelConstruct', 'begin', ...
                    constructMeta);
                rtChannelStart = tic;
                rtChan = comm.RayTracingChannel(raySet, txSite, rxSite);
                constructElapsed = toc(rtChannelStart);
                csrd.runtime.performance.trace('count', ...
                    'RayTracing.RayTracingChannelConstruct');
                csrd.runtime.performance.trace('event', ...
                    'RayTracing.RayTracingChannelConstruct', ...
                    constructElapsed, constructMeta);
                constructMeta.ElapsedSec = constructElapsed;
                csrd.runtime.performance.trace('heartbeat', ...
                    'RayTracing.RayTracingChannelConstruct', 'end', ...
                    constructMeta);
                rtChan.SampleRate = obj.resolveSampleRate(x, rxInfo);
                obj.assertInputAntennaColumns(x, txInfo, rxInfo, channelLinkInfo);
                obj.configureGpuPolicy(rtChan, x.Signal);
                executionStage = 'ChannelApply';
                applyMeta = localMapProfileTraceMetadata(mapProfile, ...
                    'InputSamples', size(x.Signal, 1), ...
                    'InputColumns', size(x.Signal, 2));
                csrd.runtime.performance.trace('heartbeat', ...
                    'RayTracing.RayTracingChannelApply', 'begin', ...
                    applyMeta);
                channelApplyStart = tic;
                out.Signal = rtChan(x.Signal);
                applyElapsed = toc(channelApplyStart);
                csrd.runtime.performance.trace('event', ...
                    'RayTracing.RayTracingChannelApply', ...
                    applyElapsed, applyMeta);
                applyMeta.ElapsedSec = applyElapsed;
                csrd.runtime.performance.trace('heartbeat', ...
                    'RayTracing.RayTracingChannelApply', 'end', applyMeta);
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
                csrd.runtime.performance.trace('heartbeat', ...
                    ['RayTracing.', executionStage], 'failed', ...
                    localMapProfileTraceMetadata(mapProfile, ...
                        'ErrorIdentifier', ME.identifier, ...
                        'ErrorMessage', ME.message));
                if strcmp(executionStage, 'RayTrace') && ...
                        obj.shouldFallback(mapProfile, channelLinkInfo) && ...
                        localRayTraceErrorAllowsFallback(ME)
                    obj.logger.warning('RayTracing failed for map mode %s; applying %s fallback. Error: %s', ...
                        string(getStructField(mapProfile, 'Mode', 'Unknown')), obj.NoValidPathFallback, ME.message);
                    out = obj.applyNoPathFallback(out, txInfo, rxInfo, channelLinkInfo, mapProfile, carrierFrequency, ME.message);
                else
                    error('RayTracing:ExecutionFailed', ...
                        'Ray tracing %s failed: %s', executionStage, ME.message);
                end
            end
        end

        function releaseImpl(obj)
            % releaseImpl - Production declaration in CSRD.
            % 中文说明：releaseImpl 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            obj.siteViewerCache = [];
            obj.siteViewerKey = '';
            csrd.runtime.map.osmSiteViewerCache('release');
            obj.propagationModelCache = [];
            obj.propagationModelKey = '';
            obj.sitePairCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.raySetCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

    end

    methods (Access = private)

        function mapProfile = resolveMapProfile(obj, channelLinkInfo)
            % resolveMapProfile - Production declaration in CSRD.
            % 中文说明：resolveMapProfile 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            mapProfile = getStructField(channelLinkInfo, 'MapProfile', struct());
            if ~isempty(fieldnames(mapProfile))
                return;
            end

            hasBuildings = ~isempty(obj.MapFilename) && isfile(obj.MapFilename) && ...
                csrd.runtime.map.osmHasBuildings(obj.MapFilename);

            mapProfile = struct();
            if hasBuildings
                mapProfile.Mode = 'OSMBuildings';
                mapProfile.HasBuildings = true;
                mapProfile.Terrain = 'none';
                mapProfile.TerrainMaterial = 'auto';
                mapProfile.MaxNumReflections = [];
                mapProfile.TerrainPolicy = 'NoOnlineTerrainForBatchRayTracing';
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
            % resolveCarrierFrequency - Production declaration in CSRD.
            % 中文说明：resolveCarrierFrequency 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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
            % resolveSampleRate - Production declaration in CSRD.
            % 中文说明：resolveSampleRate 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            sampleRate = obj.SampleRate;
            if isfield(x, 'SampleRate') && ~isempty(x.SampleRate) && x.SampleRate > 0
                sampleRate = x.SampleRate;
            elseif isfield(rxInfo, 'SampleRate') && ~isempty(rxInfo.SampleRate) && rxInfo.SampleRate > 0
                sampleRate = rxInfo.SampleRate;
            end
        end

        function [txSite, rxSite] = createSites(obj, txInfo, rxInfo, carrierFrequency)
            % createSites - Production declaration in CSRD.
            % 中文说明：createSites 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            txPos = getStructField(txInfo, 'Position', [0, 0, 30]);
            rxPos = getStructField(rxInfo, 'Position', [0, 0, 10]);
            txGeo = getSiteGeoPosition(txInfo, txPos, 'Tx');
            rxGeo = getSiteGeoPosition(rxInfo, rxPos, 'Rx');

            txHeight = max(getPositionComponent(txGeo, 3, 30), 0.1);
            rxHeight = max(getPositionComponent(rxGeo, 3, 10), 0.1);
            txName = char(string(getStructField(txInfo, 'ID', 'Tx')));
            rxName = char(string(getStructField(rxInfo, 'ID', 'Rx')));

            txArgs = {'Name', txName, ...
                      'Latitude', getPositionComponent(txGeo, 1, 0), ...
                      'Longitude', getPositionComponent(txGeo, 2, 0), ...
                      'AntennaHeight', txHeight, ...
                      'TransmitterFrequency', carrierFrequency};
            rxArgs = {'Name', rxName, ...
                      'Latitude', getPositionComponent(rxGeo, 1, 0), ...
                      'Longitude', getPositionComponent(rxGeo, 2, 0), ...
                      'AntennaHeight', rxHeight};

            numTxAntennas = max(1, round(getStructField(txInfo, 'NumTransmitAntennas', 1)));
            numRxAntennas = max(1, round(getStructField(rxInfo, 'NumAntennas', 1)));
            cacheKey = sitePairCacheKey(txName, rxName, txGeo, rxGeo, ...
                numTxAntennas, numRxAntennas, carrierFrequency);
            if isa(obj.sitePairCache, 'containers.Map') && isKey(obj.sitePairCache, cacheKey)
                pair = obj.sitePairCache(cacheKey);
                txSite = pair.TxSite;
                rxSite = pair.RxSite;
                csrd.runtime.performance.trace('count', ...
                    'RayTracing.SitePairCacheHit');
                return;
            end
            csrd.runtime.performance.trace('count', ...
                'RayTracing.SitePairCacheMiss');

            try
                txArgs = [txArgs, {'Antenna', arrayConfig('Size', [numTxAntennas, 1], 'ElementSpacing', 0.5)}];
                rxArgs = [rxArgs, {'Antenna', arrayConfig('Size', [numRxAntennas, 1], 'ElementSpacing', 0.5)}];
            catch
                % txsite/rxsite can use default antennas if arrayConfig is unavailable.
            end

            siteStart = tic;
            txSite = txsite(txArgs{:});
            rxSite = rxsite(rxArgs{:});
            csrd.runtime.performance.trace('count', ...
                'RayTracing.SitePairConstruct');
            csrd.runtime.performance.trace('event', ...
                'RayTracing.SitePairConstruct', toc(siteStart), struct( ...
                    'TxId', txName, 'RxId', rxName, ...
                    'CarrierFrequency', carrierFrequency));
            if isa(obj.sitePairCache, 'containers.Map')
                obj.sitePairCache(cacheKey) = struct('TxSite', txSite, 'RxSite', rxSite);
            end
        end

        function pm = createPropagationModel(obj, mapProfile)
            % createPropagationModel - Production declaration in CSRD.
            % 中文说明：createPropagationModel 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            cfg = normalizePropagationConfig(obj.PropagationModelConfig);
            mode = getStructField(mapProfile, 'Mode', '');

            if strcmpi(mode, 'FlatTerrain')
                flatReflections = getStructField(mapProfile, 'MaxNumReflections', []);
                if ~isempty(flatReflections)
                    cfg.MaxNumReflections = flatReflections;
                end
                cfg.MaxNumDiffractions = 0;
            end

            cacheKey = propagationCacheKey(cfg, mapProfile);
            if strcmp(obj.propagationModelKey, cacheKey) && ...
                    localIsUsablePropagationModel(obj.propagationModelCache)
                pm = obj.propagationModelCache;
                csrd.runtime.performance.trace('count', ...
                    'RayTracing.PropagationModelCacheHit');
                return;
            elseif strcmp(obj.propagationModelKey, cacheKey) && ...
                    ~isempty(obj.propagationModelCache)
                cachedClass = class(obj.propagationModelCache);
                obj.propagationModelCache = [];
                obj.propagationModelKey = '';
                csrd.runtime.performance.trace('event', ...
                    'RayTracing.PropagationModelCacheInvalidated', 0, ...
                    struct('CacheKey', cacheKey, ...
                        'CachedClass', cachedClass));
            end

            csrd.runtime.performance.trace('count', ...
                'RayTracing.PropagationModelCacheMiss');
            pmStart = tic;
            pm = propagationModel('raytracing');
            localAssertUsablePropagationModel(pm);
            setPropagationProperty(obj, pm, 'Method', cfg.Method);
            setPropagationProperty(obj, pm, 'MaxNumReflections', cfg.MaxNumReflections);
            setPropagationProperty(obj, pm, 'MaxNumDiffractions', cfg.MaxNumDiffractions);

            if strcmpi(mode, 'FlatTerrain')
                material = getStructField(mapProfile, 'TerrainMaterial', 'seawater');
                if ~setPropagationProperty(obj, pm, 'TerrainMaterial', material) && strcmpi(material, 'seawater')
                    setPropagationProperty(obj, pm, 'TerrainMaterial', 'water');
                end
            elseif strcmpi(mode, 'OSMBuildings')
                % OSM fixtures can contain empty/unsupported material names.
                % MathWorks recommends explicitly overriding material use
                % instead of depending on the file/table material catalog.
                buildingsMaterial = getStructField(mapProfile, ...
                    'BuildingsMaterial', 'concrete');
                surfaceMaterial = getStructField(mapProfile, ...
                    'SurfaceMaterial', 'plasterboard');
                terrainMaterial = getStructField(mapProfile, ...
                    'TerrainMaterial', 'concrete');
                if isempty(buildingsMaterial) || strcmpi(buildingsMaterial, 'auto')
                    buildingsMaterial = 'concrete';
                end
                if isempty(surfaceMaterial) || strcmpi(surfaceMaterial, 'auto')
                    surfaceMaterial = 'plasterboard';
                end
                if isempty(terrainMaterial) || strcmpi(terrainMaterial, 'auto')
                    terrainMaterial = 'concrete';
                end
                setPropagationProperty(obj, pm, 'BuildingsMaterial', buildingsMaterial);
                setPropagationProperty(obj, pm, 'SurfaceMaterial', surfaceMaterial);
                setPropagationProperty(obj, pm, 'TerrainMaterial', terrainMaterial);
            end

            obj.propagationModelCache = pm;
            obj.propagationModelKey = cacheKey;
            csrd.runtime.performance.trace('event', ...
                'RayTracing.PropagationModelConstruct', toc(pmStart), ...
                struct('CacheKey', cacheKey));
        end

        function configureGpuPolicy(obj, rtChan, signal)
            % configureGpuPolicy - Enable comm.RayTracingChannel GPU only when useful.
            % 中文说明：只在配置允许、样本量足够且 GPU 可用时启用 UseGPU。
            if ~isprop(rtChan, 'UseGPU')
                return;
            end
            policy = lower(char(string(obj.UseGPU)));
            switch policy
                case {'false', 'off', 'none', 'cpu'}
                    rtChan.UseGPU = "off";
                case {'true', 'on', 'gpu'}
                    if gpuIsAvailable()
                        rtChan.UseGPU = "on";
                    else
                        rtChan.UseGPU = "off";
                    end
                otherwise
                    if gpuIsAvailable() && numel(signal) >= obj.GpuMinSamples
                        rtChan.UseGPU = "auto";
                    else
                        rtChan.UseGPU = "off";
                    end
            end
        end

        function [raySet, rayCount, pathLoss, failureMessage] = computeRays(obj, txSite, rxSite, pm, mapProfile)
            % computeRays - Production declaration in CSRD.
            % 中文说明：computeRays 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            raySet = [];
            rayCount = 0;
            pathLoss = [];
            failureMessage = '';
            cacheKey = raySetCacheKey(txSite, rxSite, mapProfile);
            if isa(obj.raySetCache, 'containers.Map') && isKey(obj.raySetCache, cacheKey)
                cached = obj.raySetCache(cacheKey);
                raySet = cached.RaySet;
                rayCount = cached.RayCount;
                pathLoss = cached.PathLoss;
                if isfield(cached, 'FailureMessage')
                    failureMessage = cached.FailureMessage;
                end
                csrd.runtime.performance.trace('count', ...
                    'RayTracing.RaySetCacheHit');
                csrd.runtime.performance.trace('event', ...
                    'RayTracing.RaySetCacheHit', 0, ...
                    localMapProfileTraceMetadata(mapProfile, ...
                        'KeyHash', rayKeyHash(cacheKey), ...
                        'RayCount', rayCount, ...
                        'CacheSize', raySetCacheSize(obj.raySetCache)));
                return;
            end
            csrd.runtime.performance.trace('count', ...
                'RayTracing.RaySetCacheMiss');
            csrd.runtime.performance.trace('event', ...
                'RayTracing.RaySetCacheMiss', 0, ...
                localMapProfileTraceMetadata(mapProfile, ...
                    'KeyHash', rayKeyHash(cacheKey), ...
                    'CacheSize', raySetCacheSize(obj.raySetCache)));

            mapArg = obj.resolveMapArgument(mapProfile);
            raytraceMeta = localMapProfileTraceMetadata(mapProfile);
            csrd.runtime.performance.trace('heartbeat', ...
                'RayTracing.RaytraceCall', 'begin', raytraceMeta);
            raytraceStart = tic;
            if isempty(mapArg)
                rays = raytrace(txSite, rxSite, pm);
            else
                rays = raytrace(txSite, rxSite, pm, 'Map', mapArg);
            end
            raytraceElapsed = toc(raytraceStart);
            csrd.runtime.performance.trace('count', 'RayTracing.RaytraceCall');
            csrd.runtime.performance.trace('event', 'RayTracing.RaytraceCall', ...
                raytraceElapsed, raytraceMeta);
            raytraceMeta.ElapsedSec = raytraceElapsed;
            csrd.runtime.performance.trace('heartbeat', ...
                'RayTracing.RaytraceCall', 'end', raytraceMeta);

            [raySet, rayCount, pathLoss] = normalizeRaytraceOutput(rays);
            if isa(obj.raySetCache, 'containers.Map')
                obj.raySetCache(cacheKey) = struct( ...
                    'RaySet', raySet, 'RayCount', rayCount, ...
                    'PathLoss', pathLoss);
            end
        end

        function mapArg = resolveMapArgument(obj, mapProfile)
            % resolveMapArgument - Production declaration in CSRD.
            % 中文说明：resolveMapArgument 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            mapArg = [];
            mode = getStructField(mapProfile, 'Mode', '');
            osmFile = getStructField(mapProfile, 'OSMFile', obj.MapFilename);

            if strcmpi(mode, 'FlatTerrain')
                terrain = getStructField(mapProfile, 'Terrain', 'none');
                if ~(ischar(terrain) || isstring(terrain))
                    error('CSRD:RayTracing:InvalidMapArgument', ...
                        ['FlatTerrain Map argument must be a terrain name ', ...
                         'string, not %s.'], class(terrain));
                end
                mapArg = terrain;
            elseif strcmpi(mode, 'OSMBuildings') && ~isempty(osmFile) && isfile(osmFile)
                key = sprintf('OSMBuildings:%s', osmFile);
                if strcmp(obj.siteViewerKey, key) && ~isempty(obj.siteViewerCache)
                    if localIsUsableMapArgument(obj.siteViewerCache)
                        mapArg = obj.siteViewerCache;
                        return;
                    end
                    csrd.runtime.performance.trace('event', ...
                        'RayTracing.SiteviewerLocalCacheInvalidated', 0, ...
                        localMapProfileTraceMetadata(mapProfile, ...
                            'CachedClass', class(obj.siteViewerCache)));
                    obj.siteViewerCache = [];
                    obj.siteViewerKey = '';
                end

                siteviewerMeta = localMapProfileTraceMetadata(mapProfile);
                csrd.runtime.performance.trace('heartbeat', ...
                    'RayTracing.SiteviewerGet', 'begin', siteviewerMeta);
                siteviewerStart = tic;
                [obj.siteViewerCache, ~] = ...
                    csrd.runtime.map.osmSiteViewerCache('get', osmFile);
                localAssertUsableMapArgument(obj.siteViewerCache, osmFile);
                siteviewerElapsed = toc(siteviewerStart);
                csrd.runtime.performance.trace('count', ...
                    'RayTracing.SiteviewerGet');
                csrd.runtime.performance.trace('event', ...
                    'RayTracing.SiteviewerGet', siteviewerElapsed, ...
                    siteviewerMeta);
                siteviewerMeta.ElapsedSec = siteviewerElapsed;
                csrd.runtime.performance.trace('heartbeat', ...
                    'RayTracing.SiteviewerGet', 'end', siteviewerMeta);
                obj.siteViewerKey = key;
                mapArg = obj.siteViewerCache;
            end
        end

        function tf = shouldFallback(obj, mapProfile, channelLinkInfo)
            % shouldFallback - Production declaration in CSRD.
            % 中文说明：shouldFallback 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            fallbackPolicy = getStructField(channelLinkInfo, 'NoValidPathFallback', obj.NoValidPathFallback);
            mode = getStructField(mapProfile, 'Mode', '');
            tf = strcmpi(fallbackPolicy, 'FreeSpaceAttenuation') || strcmpi(mode, 'FlatTerrain');
        end

        function out = applyNoPathFallback(obj, out, txInfo, rxInfo, channelLinkInfo, mapProfile, carrierFrequency, errorMessage)
            % applyNoPathFallback - Production declaration in CSRD.
            % 中文说明：applyNoPathFallback 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            fallbackPolicy = getStructField(channelLinkInfo, 'NoValidPathFallback', obj.NoValidPathFallback);
            if ~strcmpi(fallbackPolicy, 'FreeSpaceAttenuation') && ~strcmpi(getStructField(mapProfile, 'Mode', ''), 'FlatTerrain')
                error('RayTracing:NoValidPaths', 'Ray tracing returned no valid paths.');
            end

            pathLoss = getStructField(channelLinkInfo, 'ComputedPathLoss', []);
            if isempty(pathLoss)
                linkDistance = getStructField(channelLinkInfo, 'LinkDistance', []);
                if isempty(linkDistance)
                    txGeo = getSiteGeoPosition(txInfo, ...
                        getStructField(txInfo, 'Position', [0, 0, 0]), 'Tx');
                    rxGeo = getSiteGeoPosition(rxInfo, ...
                        getStructField(rxInfo, 'Position', [0, 0, 0]), 'Rx');
                    linkDistance = geographicDistance(txGeo, rxGeo);
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
            % buildChannelInfo - Production declaration in CSRD.
            % 中文说明：buildChannelInfo 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            channelInfo = struct();
            channelInfo.Model = 'RayTracing';
            channelInfo.MapProfile = mapProfile;
            channelInfo.CarrierFrequency = carrierFrequency;
            channelInfo.RayCount = rayCount;
            channelInfo.PathLoss = pathLoss;
            channelInfo.Fallback = fallback;
        end

        function ok = setPropagationProperty(obj, pm, propName, value)
            % setPropagationProperty - Production declaration in CSRD.
            % 中文说明：setPropagationProperty 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            ok = false;
            try
                pm.(propName) = value;
                ok = true;
            catch ME
                obj.logger.warning('Could not set RayTracing propagation property %s=%s: %s', ...
                    propName, valueToText(value), ME.message);
            end
        end

        function ensureRuntimeCaches(obj)
            %ENSURERUNTIMECACHES Lazily initialise caches for public precompute calls.
            if isempty(obj.logger)
                obj.logger = csrd.runtime.logger.GlobalLogManager.getLogger();
            end
            obj.PropagationModelConfig = normalizePropagationConfig(obj.PropagationModelConfig);
            if isempty(obj.sitePairCache) || ~isa(obj.sitePairCache, 'containers.Map')
                obj.sitePairCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end
            if isempty(obj.raySetCache) || ~isa(obj.raySetCache, 'containers.Map')
                obj.raySetCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end
        end

        function assertInputAntennaColumns(~, x, txInfo, rxInfo, channelLinkInfo)
            expectedColumns = max(1, round(getStructField(txInfo, 'NumTransmitAntennas', 1)));
            actualColumns = size(x.Signal, 2);
            if actualColumns == expectedColumns
                return;
            end

            txId = char(string(getStructField(txInfo, 'ID', 'Tx')));
            rxId = char(string(getStructField(rxInfo, 'ID', 'Rx')));
            burstId = char(string(getStructField(channelLinkInfo, 'BurstId', '')));
            signalSize = size(x.Signal);
            if numel(signalSize) < 2
                signalSize(2) = 1;
            end

            error('RayTracing:InputAntennaColumnMismatch', ...
                ['RayTracing input signal columns=%d but Tx %s declares ', ...
                 'NumTransmitAntennas=%d for Rx %s BurstId=%s. ', ...
                 'SignalSize=[%d %d]. Upstream modulation/TRF must preserve ', ...
                 'samples-by-antennas shape before channel application.'], ...
                actualColumns, txId, expectedColumns, rxId, burstId, ...
                signalSize(1), signalSize(2));
        end

    end

end

function cfg = normalizePropagationConfig(cfg)
    % normalizePropagationConfig - Production declaration in CSRD.
    % 中文说明：normalizePropagationConfig 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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

function key = propagationCacheKey(cfg, mapProfile)
    % propagationCacheKey - Stable key for map/profile scoped propagation model.
    mode = char(string(getStructField(mapProfile, 'Mode', '')));
    terrain = char(string(getStructField(mapProfile, 'Terrain', '')));
    material = char(string(getStructField(mapProfile, 'TerrainMaterial', '')));
    buildingsMaterial = char(string(getStructField(mapProfile, ...
        'BuildingsMaterial', '')));
    surfaceMaterial = char(string(getStructField(mapProfile, ...
        'SurfaceMaterial', '')));
    maxReflections = getStructField(mapProfile, 'MaxNumReflections', cfg.MaxNumReflections);
    key = sprintf(['Method=%s|Mode=%s|Ref=%s|Diff=%s|Terrain=%s|', ...
        'Mat=%s|BuildMat=%s|SurfMat=%s'], ...
        char(string(cfg.Method)), mode, mat2str(maxReflections), ...
        mat2str(cfg.MaxNumDiffractions), terrain, material, ...
        buildingsMaterial, surfaceMaterial);
end

function key = sitePairCacheKey(txName, rxName, txGeo, rxGeo, ...
        numTxAntennas, numRxAntennas, carrierFrequency)
    % sitePairCacheKey - Geometry-aware key for txsite/rxsite reuse.
    key = sprintf(['Tx=%s|Rx=%s|TxGeo=%s|RxGeo=%s|TxAnt=%d|', ...
        'RxAnt=%d|Fc=%.17g'], ...
        txName, rxName, mat2str(double(txGeo), 17), ...
        mat2str(double(rxGeo), 17), numTxAntennas, numRxAntennas, ...
        double(carrierFrequency));
end

function key = raySetCacheKey(txSite, rxSite, mapProfile)
    % raySetCacheKey - Stable key for rays reused across bursts on one link.
    mode = char(string(getStructField(mapProfile, 'Mode', '')));
    osmFile = char(string(getStructField(mapProfile, 'OSMFile', '')));
    terrain = char(string(getStructField(mapProfile, 'Terrain', '')));
    material = char(string(getStructField(mapProfile, 'TerrainMaterial', '')));
    buildingsMaterial = char(string(getStructField(mapProfile, ...
        'BuildingsMaterial', '')));
    surfaceMaterial = char(string(getStructField(mapProfile, ...
        'SurfaceMaterial', '')));
    maxReflections = getStructField(mapProfile, 'MaxNumReflections', []);
    key = sprintf(['Map=%s|File=%s|Terrain=%s|Mat=%s|BuildMat=%s|', ...
        'SurfMat=%s|Refl=%s|Tx=%s|Rx=%s'], ...
        mode, osmFile, terrain, material, buildingsMaterial, ...
        surfaceMaterial, mat2str(maxReflections), ...
        siteKeyPart(txSite, true), siteKeyPart(rxSite, false));
end

function hashValue = rayKeyHash(key)
    hashValue = csrd.support.hash.shortInt32Hash(key);
end

function countValue = raySetCacheSize(cacheMap)
    countValue = 0;
    if isa(cacheMap, 'containers.Map')
        countValue = cacheMap.Count;
    end
end

function meta = localMapProfileTraceMetadata(mapProfile, varargin)
    %LOCALMAPPROFILETRACEMETADATA Include OSM coverage metadata in perf traces.
    % 中文说明：性能证据记录被选中的 OSM 文件和均匀覆盖序号，不再记录大小分级。
    meta = struct();
    meta.MapMode = char(string(getStructField(mapProfile, 'Mode', '')));
    meta.OSMFile = char(string(getStructField(mapProfile, 'OSMFile', '')));
    meta.OSMFileSizeMB = getStructField(mapProfile, 'OSMFileSizeMB', NaN);
    meta.SelectionPolicy = char(string(getStructField(mapProfile, ...
        'SelectionPolicy', 'Unknown')));
    meta.CoverageOrdinal = getStructField(mapProfile, 'CoverageOrdinal', NaN);
    meta.CandidateFileCount = getStructField(mapProfile, 'CandidateFileCount', NaN);
    for idx = 1:2:numel(varargin)
        fieldName = char(string(varargin{idx}));
        meta.(fieldName) = varargin{idx + 1};
    end
end

function item = localCellOrArrayEntry(collection, idx)
    if iscell(collection)
        item = collection{idx};
    else
        item = collection(idx);
    end
end

function tf = localHasErrorStatus(info)
    tf = isstruct(info) && isfield(info, 'Status') && ...
        contains(string(info.Status), "Error");
end

function [raySet, rayCount, pathLoss] = normalizeRaytraceOutput(rays)
    raySet = [];
    rayCount = 0;
    pathLoss = [];
    if iscell(rays)
        if isempty(rays) || isempty(rays{1})
            return;
        end
        raySet = rays{1};
    else
        if isempty(rays)
            return;
        end
        raySet = rays;
    end
    rayCount = numel(raySet);
    pathLoss = extractMinimumPathLoss(raySet);
end

function rays = localBatchedRayCell(allRays, txIdx, rxIdx)
    rays = [];
    if iscell(allRays)
        if ndims(allRays) >= 2 && size(allRays, 1) >= txIdx && ...
                size(allRays, 2) >= rxIdx
            rays = allRays(txIdx, rxIdx);
        elseif numel(allRays) >= txIdx
            rays = allRays(txIdx);
        end
    elseif txIdx == 1 && rxIdx == 1
        rays = allRays;
    end
end

function part = siteKeyPart(siteObj, includeFrequency)
    values = nan(1, 4);
    try
        values(1) = double(siteObj.Latitude);
    catch
    end
    try
        values(2) = double(siteObj.Longitude);
    catch
    end
    try
        values(3) = double(siteObj.AntennaHeight);
    catch
    end
    if includeFrequency
        try
            values(4) = double(siteObj.TransmitterFrequency);
        catch
        end
    end
    part = mat2str(values, 17);
end

function tf = gpuIsAvailable()
    % gpuIsAvailable - Best-effort GPU availability probe without requiring one.
    tf = false;
    try
        tf = gpuDeviceCount("available") > 0;
    catch
        try
            tf = gpuDeviceCount > 0;
        catch
            tf = false;
        end
    end
end

function localAssertUsablePropagationModel(pm)
    if localIsUsablePropagationModel(pm)
        return;
    end
    error('CSRD:RayTracing:InvalidPropagationModelHandle', ...
        ['propagationModel(''raytracing'') returned %s; raytrace ', ...
         'requires a valid propagation model object.'], class(pm));
end

function tf = localIsUsablePropagationModel(pm)
    tf = ~isempty(pm) && isobject(pm) && ~isstruct(pm);
end

function localAssertUsableMapArgument(mapArg, osmFile)
    if localIsUsableMapArgument(mapArg)
        return;
    end
    error('CSRD:RayTracing:InvalidMapArgument', ...
        ['OSM RayTracing Map for "%s" resolved to %s; raytrace(Map=...) ', ...
         'requires a valid siteviewer/map object.'], ...
        char(string(osmFile)), class(mapArg));
end

function tf = localIsUsableMapArgument(mapArg)
    tf = ~isempty(mapArg) && isobject(mapArg) && ~isstruct(mapArg);
    if ~tf
        return;
    end
    try
        tf = isvalid(mapArg);
    catch
        % Some MATLAB value objects accepted by raytrace do not implement
        % isvalid. They remain acceptable as long as they are real objects;
        % the production bug guard is rejecting structs and stale handles.
        tf = true;
    end
end

function tf = localRayTraceErrorAllowsFallback(ME)
    msg = lower(char(string(ME.message)));
    id = lower(char(string(ME.identifier)));

    % Internal type/handle errors are programming/configuration faults. They
    % must surface as hard failures instead of being relabeled as no-path RF.
    hardFragments = {'isvalid', 'undefined function', '未定义与', ...
        'invalidmapargument', 'invalidpropagationmodelhandle', ...
        'unable to access terrain', 'gmted2010', 'terrain data'};
    if any(contains(msg, hardFragments)) || any(contains(id, hardFragments))
        tf = false;
        return;
    end

    noPathFragments = {'no valid path', 'no valid propagation path', ...
        'no propagation path', 'no ray found', 'no rays were found', ...
        'unable to find a propagation path', 'valid propagation paths'};
    tf = contains(id, 'novalidpath') || any(contains(msg, noPathFragments));
end

function value = getStructField(s, fieldName, defaultValue)
    % getStructField - Production declaration in CSRD.
    % 中文说明：getStructField 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end

function value = getPositionComponent(position, idx, defaultValue)
    % getPositionComponent - Production declaration in CSRD.
    % 中文说明：getPositionComponent 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    if isnumeric(position) && numel(position) >= idx
        value = position(idx);
    else
        value = defaultValue;
    end
end

function geoPosition = getSiteGeoPosition(siteInfo, position, roleName)
    % getSiteGeoPosition - Resolve [lat lon height] degrees for txsite/rxsite.
    % 中文说明：RayTracing 只消费 GeoPositionDeg；米制 Position 留给距离/Doppler。
    if isstruct(siteInfo) && isfield(siteInfo, 'GeoPositionDeg') && ...
            ~isempty(siteInfo.GeoPositionDeg)
        geoPosition = double(siteInfo.GeoPositionDeg(:)).';
        if numel(geoPosition) ~= 3 || any(~isfinite(geoPosition))
            error('CSRD:RayTracing:InvalidGeoPosition', ...
                '%s GeoPositionDeg must be a finite [lat lon height] vector.', roleName);
        end
        return;
    end

    positionUnit = '';
    if isstruct(siteInfo) && isfield(siteInfo, 'PositionUnit') && ...
            ~isempty(siteInfo.PositionUnit)
        positionUnit = char(string(siteInfo.PositionUnit));
    end
    if strcmpi(positionUnit, 'meters')
        error('CSRD:RayTracing:MissingGeoPosition', ...
            ['%s uses meter Position; RayTracing requires GeoPositionDeg ', ...
             'for txsite/rxsite construction.'], roleName);
    end

    % Legacy direct RayTracing tests may still provide Position as
    % [lon lat height]. Production OSM paths publish GeoPositionDeg.
    if ~isnumeric(position) || numel(position) < 2 || ...
            any(~isfinite(position(1:min(3, numel(position)))))
        error('CSRD:RayTracing:InvalidLegacyPosition', ...
            '%s Position must be finite when GeoPositionDeg is absent.', roleName);
    end
    height = getPositionComponent(position, 3, 0);
    geoPosition = [position(2), position(1), height];
end

function pathLoss = extractMinimumPathLoss(raySet)
    % extractMinimumPathLoss - Production declaration in CSRD.
    % 中文说明：extractMinimumPathLoss 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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
    % valueToText - Production declaration in CSRD.
    % 中文说明：valueToText 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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

function distance_m = geographicDistance(txGeo, rxGeo)
    % geographicDistance - Production declaration in CSRD.
    % 中文说明：geographicDistance 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    earthRadius_m = 6371000;
    lat1 = deg2rad(txGeo(1));
    lon1 = deg2rad(txGeo(2));
    lat2 = deg2rad(rxGeo(1));
    lon2 = deg2rad(rxGeo(2));

    dLat = lat2 - lat1;
    dLon = lon2 - lon1;
    a = sin(dLat / 2).^2 + cos(lat1) .* cos(lat2) .* sin(dLon / 2).^2;
    c = 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)));
    horizontalDistance = earthRadius_m * c;

    dz = 0;
    if numel(txGeo) >= 3 && numel(rxGeo) >= 3
        dz = rxGeo(3) - txGeo(3);
    end
    distance_m = sqrt(horizontalDistance.^2 + dz.^2);
end
