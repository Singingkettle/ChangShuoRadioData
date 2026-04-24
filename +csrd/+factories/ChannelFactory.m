classdef ChannelFactory < matlab.System

    properties
        % Config: Struct containing the configuration for channel models.
        Config struct
    end

    properties (Access = private)
        logger
        factoryConfig
        cachedChannelBlock
        selectedChannelModelName char = ''
        selectedChannelBlockHandle char = ''
        selectedChannelDefaultConfig struct = struct()
        isRayTracingSelected logical = false
    end

    methods

        function obj = ChannelFactory(varargin)
            setProperties(obj, nargin, varargin{:});
            obj.cachedChannelBlock = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

    end

    methods (Access = protected)

        function validateInputsImpl(~, ~, ~, ~, ~, ~)
        end

        function setupImpl(obj)
            if isempty(obj.Config) || ~isstruct(obj.Config) || ~isfield(obj.Config, 'ChannelModels')
                error('ChannelFactory:ConfigError', 'Config property must be a valid struct with a ChannelModels field.');
            end

            obj.factoryConfig = obj.Config;
            obj.logger = csrd.utils.logger.GlobalLogManager.getLogger();
            obj.cachedChannelBlock = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.logger.debug('ChannelFactory setup complete; channel model selection is scenario-driven.');
        end

        function receivedSignalStruct = stepImpl(obj, inputSignalStruct, frameId, txSpecificInfo, rxSpecificInfo, channelLinkSpecificInfo)
            if ~isstruct(channelLinkSpecificInfo)
                channelLinkSpecificInfo = struct();
            end

            txIdStr = string(getStructField(txSpecificInfo, 'ID', 'Tx'));
            rxIdStr = string(getStructField(rxSpecificInfo, 'ID', 'Rx'));

            channelModelName = obj.resolveChannelModelName(channelLinkSpecificInfo);
            cacheKey = obj.resolveChannelCacheKey(channelModelName, txIdStr, rxIdStr);
            currentChannelBlock = obj.getChannelBlock(channelModelName, cacheKey);
            obj.selectedChannelModelName = channelModelName;
            obj.isRayTracingSelected = contains(class(currentChannelBlock), 'RayTracing', 'IgnoreCase', true);

            obj.logger.debug('Frame %d, Tx %s to Rx %s: ChannelFactory selected model %s.', ...
                frameId, txIdStr, rxIdStr, channelModelName);

            [linkDistance_m, linkDistance_km] = obj.computeLinkDistance(txSpecificInfo, rxSpecificInfo, channelLinkSpecificInfo);
            computedPathLoss_dB = obj.computeFreeSpacePathLoss(linkDistance_m, rxSpecificInfo, channelLinkSpecificInfo);
            computedSNR_dB = obj.computeLinkBudgetSNR(computedPathLoss_dB, txSpecificInfo);

            inputSignalStruct.LinkDistance = linkDistance_m;
            inputSignalStruct.PathLoss = computedPathLoss_dB;
            inputSignalStruct.ComputedSNR = computedSNR_dB;
            inputSignalStruct.ChannelModel = channelModelName;

            channelLinkSpecificInfo.LinkDistance = linkDistance_m;
            channelLinkSpecificInfo.LinkDistanceKm = linkDistance_km;
            channelLinkSpecificInfo.ComputedPathLoss = computedPathLoss_dB;
            channelLinkSpecificInfo.ComputedSNR = computedSNR_dB;
            channelLinkSpecificInfo.ChannelModel = channelModelName;
            channelLinkSpecificInfo.NoValidPathFallback = getStructField( ...
                obj.factoryConfig, 'NoValidPathFallback', 'FreeSpaceAttenuation');

            obj.logger.debug('Link %s->%s: dist=%.1fm, PL=%.1fdB, SNR=%.1fdB', ...
                txIdStr, rxIdStr, linkDistance_m, computedPathLoss_dB, computedSNR_dB);

            if ~obj.isRayTracingSelected
                obj.configureStatisticalBlock(currentChannelBlock, frameId, txIdStr, rxIdStr, ...
                    txSpecificInfo, rxSpecificInfo, channelLinkSpecificInfo, linkDistance_km, computedSNR_dB);
            end

            try
                if ~isfield(inputSignalStruct, 'Signal')
                    error('ChannelFactory:InputError', 'inputSignalStruct missing Signal field.');
                end

                if obj.isRayTracingSelected
                    channelBlockOutput = step(currentChannelBlock, inputSignalStruct, ...
                        txSpecificInfo, rxSpecificInfo, channelLinkSpecificInfo);
                else
                    channelBlockOutput = step(currentChannelBlock, inputSignalStruct);
                end

                receivedSignalStruct = obj.mergeChannelOutput(inputSignalStruct, channelBlockOutput);
                receivedSignalStruct.LinkDistance = linkDistance_m;
                receivedSignalStruct.PathLoss = getStructField(receivedSignalStruct, 'PathLoss', computedPathLoss_dB);
                receivedSignalStruct.ComputedSNR = computedSNR_dB;
                receivedSignalStruct.ChannelModel = channelModelName;

                obj.logger.debug('Frame %d, Tx %s to Rx %s: Channel processing by %s successful.', ...
                    frameId, txIdStr, rxIdStr, class(currentChannelBlock));
            catch ME_step
                obj.logger.error('Frame %d, Tx %s to Rx %s: Error during step of channel block %s. Error: %s', ...
                    frameId, txIdStr, rxIdStr, class(currentChannelBlock), ME_step.message);
                obj.logger.error('Stack: %s', getReport(ME_step, 'extended', 'hyperlinks', 'off'));
                receivedSignalStruct = inputSignalStruct;
                if ~isfield(receivedSignalStruct, 'Signal'), receivedSignalStruct.Signal = []; end
                receivedSignalStruct.Error = 'ChannelBlockStepFailed';
            end
        end

        function releaseImpl(obj)
            obj.logger.debug('ChannelFactory releaseImpl called.');
            obj.releaseCachedBlocks();
            obj.cachedChannelBlock = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.logger.debug('Cached channel blocks released.');
        end

        function resetImpl(obj)
            obj.logger.debug('ChannelFactory resetImpl called.');
            if isa(obj.cachedChannelBlock, 'containers.Map')
                blockValues = values(obj.cachedChannelBlock);
                for idx = 1:numel(blockValues)
                    block = blockValues{idx};
                    if isa(block, 'matlab.System')
                        reset(block);
                    end
                end
            end
            obj.logger.debug('Cached channel blocks reset.');
        end

    end

    methods (Access = private)

        function modelName = resolveChannelModelName(obj, channelLinkInfo)
            requested = getStructField(channelLinkInfo, 'ChannelModel', '');
            mapProfile = getStructField(channelLinkInfo, 'MapProfile', struct());
            mode = getStructField(mapProfile, 'Mode', '');

            if isempty(requested) || strcmpi(requested, 'Statistical')
                requested = obj.getDefaultModelForMode(mode);
            end

            if isfield(obj.factoryConfig.ChannelModels, requested)
                modelName = requested;
                return;
            end

            fallback = obj.getDefaultModelForMode(mode);
            if isfield(obj.factoryConfig.ChannelModels, fallback)
                modelName = fallback;
                return;
            end

            if isfield(obj.factoryConfig.ChannelModels, 'AWGN')
                modelName = 'AWGN';
                return;
            end

            modelNames = fieldnames(obj.factoryConfig.ChannelModels);
            modelName = modelNames{1};
        end

        function defaultModel = getDefaultModelForMode(obj, mode)
            defaultModel = 'AWGN';
            if ~isfield(obj.factoryConfig, 'DefaultModels') || ~isstruct(obj.factoryConfig.DefaultModels)
                return;
            end

            defaults = obj.factoryConfig.DefaultModels;
            if ~isempty(mode) && isfield(defaults, mode)
                defaultModel = defaults.(mode);
            elseif isfield(defaults, 'Statistical')
                defaultModel = defaults.Statistical;
            end
        end

        function cacheKey = resolveChannelCacheKey(obj, modelName, txIdStr, rxIdStr)
            if obj.isRayTracingModelName(modelName)
                cacheKey = modelName;
            else
                cacheKey = sprintf('%s|Tx=%s|Rx=%s', modelName, char(txIdStr), char(rxIdStr));
            end
        end

        function tf = isRayTracingModelName(~, modelName)
            tf = contains(modelName, 'RayTracing', 'IgnoreCase', true);
        end

        function block = getChannelBlock(obj, modelName, cacheKey)
            if isempty(obj.cachedChannelBlock) || ~isa(obj.cachedChannelBlock, 'containers.Map')
                obj.cachedChannelBlock = containers.Map('KeyType', 'char', 'ValueType', 'any');
            end

            if isKey(obj.cachedChannelBlock, cacheKey)
                block = obj.cachedChannelBlock(cacheKey);
                return;
            end

            modelEntry = obj.factoryConfig.ChannelModels.(modelName);
            if ~isfield(modelEntry, 'handle') || isempty(modelEntry.handle)
                error('ChannelFactory:ConfigError', 'Channel model "%s" is missing a handle.', modelName);
            end

            blockHandle = modelEntry.handle;
            blockConfig = struct();
            if isfield(modelEntry, 'Config') && isstruct(modelEntry.Config)
                blockConfig = modelEntry.Config;
            end

            obj.logger.debug('Instantiating channel block %s for model %s.', blockHandle, modelName);
            block = feval(blockHandle);
            obj.applyBlockConfig(block, blockConfig);

            if isprop(block, 'NoValidPathFallback') && isfield(obj.factoryConfig, 'NoValidPathFallback')
                block.NoValidPathFallback = obj.factoryConfig.NoValidPathFallback;
            end

            obj.cachedChannelBlock(cacheKey) = block;
            obj.selectedChannelBlockHandle = blockHandle;
            obj.selectedChannelDefaultConfig = blockConfig;
        end

        function applyBlockConfig(obj, block, blockConfig)
            cfgFields = fieldnames(blockConfig);
            for idx = 1:numel(cfgFields)
                fieldName = cfgFields{idx};
                fieldValue = blockConfig.(fieldName);

                if strcmpi(fieldName, 'Seed') && ischar(fieldValue) && strcmpi(fieldValue, 'shuffle')
                    fieldValue = randi(2^31 - 1);
                    obj.logger.debug('Converted Seed "shuffle" to numeric: %d', fieldValue);
                end

                if isprop(block, fieldName)
                    try
                        block.(fieldName) = fieldValue;
                    catch ME_set
                        obj.logger.warning('Could not set channel property "%s": %s', fieldName, ME_set.message);
                    end
                elseif strcmp(fieldName, 'MaxReflections') && isprop(block, 'PropagationModelConfig')
                    pmConfig = block.PropagationModelConfig;
                    pmConfig.MaxNumReflections = fieldValue;
                    block.PropagationModelConfig = pmConfig;
                elseif strcmp(fieldName, 'FrequencyCarrier') && isprop(block, 'CarrierFrequency')
                    block.CarrierFrequency = fieldValue;
                end
            end
        end

        function configureStatisticalBlock(obj, currentChannelBlock, frameId, txIdStr, rxIdStr, ...
                txSpecificInfo, rxSpecificInfo, channelLinkSpecificInfo, linkDistance_km, computedSNR_dB)

            enableDistSNR = true;
            if isfield(obj.factoryConfig, 'LinkBudget') && isfield(obj.factoryConfig.LinkBudget, 'EnableDistanceBasedSNR')
                enableDistSNR = obj.factoryConfig.LinkBudget.EnableDistanceBasedSNR;
            end

            if enableDistSNR && linkDistance_km > 0
                if isprop(currentChannelBlock, 'SNRdB')
                    currentChannelBlock.SNRdB = computedSNR_dB;
                end
                if isprop(currentChannelBlock, 'Distance')
                    try
                        % BaseChannel.Distance is documented in METERS.
                        % Pass meters here so the path loss calculation
                        % inside the channel block stays unit-consistent.
                        currentChannelBlock.Distance = max(linkDistance_m, 1);
                    catch ME_dist
                        obj.logger.warning('Could not update channel Distance: %s', ME_dist.message);
                    end
                end
            end

            fieldsToSet = fieldnames(channelLinkSpecificInfo);
            for idx = 1:numel(fieldsToSet)
                propName = fieldsToSet{idx};
                if isprop(currentChannelBlock, propName)
                    try
                        currentChannelBlock.(propName) = channelLinkSpecificInfo.(propName);
                    catch ME_setprop_link
                        obj.logger.warning('Could not set channel prop "%s" from link info. Error: %s', ...
                            propName, ME_setprop_link.message);
                    end
                end
            end

            if isprop(currentChannelBlock, 'NumTransmitAntennas') && isfield(txSpecificInfo, 'NumTransmitAntennas')
                try
                    currentChannelBlock.NumTransmitAntennas = txSpecificInfo.NumTransmitAntennas;
                catch ME_txant
                    obj.logger.warning('Could not update NumTransmitAntennas: %s', ME_txant.message);
                end
            end

            if isprop(currentChannelBlock, 'NumReceiveAntennas') && isfield(rxSpecificInfo, 'NumAntennas')
                try
                    currentChannelBlock.NumReceiveAntennas = rxSpecificInfo.NumAntennas;
                catch ME_rxant
                    obj.logger.warning('Could not update NumReceiveAntennas: %s', ME_rxant.message);
                end
            end

            if isprop(currentChannelBlock, 'Seed')
                try
                    txHash = sum(double(char(txIdStr)));
                    rxHash = sum(double(char(rxIdStr)));
                    currentChannelBlock.Seed = mod(frameId * 10000 + txHash * 100 + rxHash, 2^31 - 1);
                catch ME_seed
                    obj.logger.warning('Could not update channel Seed: %s', ME_seed.message);
                end
            end
        end

        function [linkDistance_m, linkDistance_km] = computeLinkDistance(obj, txInfo, rxInfo, channelLinkInfo)
            linkDistance_m = 0;
            txPos = getStructField(txInfo, 'Position', []);
            rxPos = getStructField(rxInfo, 'Position', []);

            if isempty(txPos) || isempty(rxPos)
                linkDistance_km = 0;
                return;
            end

            mapProfile = getStructField(channelLinkInfo, 'MapProfile', struct());
            mode = getStructField(mapProfile, 'Mode', '');

            if any(strcmpi(mode, {'OSMBuildings', 'FlatTerrain'}))
                linkDistance_m = geographicDistance(txPos, rxPos);
            else
                linkDistance_m = norm(txPos - rxPos);
            end

            minDist_km = 0.01;
            if isfield(obj.factoryConfig, 'LinkBudget') && isfield(obj.factoryConfig.LinkBudget, 'MinDistance')
                minDist_km = obj.factoryConfig.LinkBudget.MinDistance;
            end
            linkDistance_km = max(linkDistance_m / 1000, minDist_km);
            linkDistance_m = linkDistance_km * 1000;
        end

        function pathLoss_dB = computeFreeSpacePathLoss(obj, linkDistance_m, rxInfo, channelLinkInfo)
            carrierFreq = obj.resolveCarrierFrequency(rxInfo, channelLinkInfo);
            waveLength = physconst('LightSpeed') / carrierFreq;
            pathLoss_dB = fspl(max(linkDistance_m, 1), waveLength);
        end

        function carrierFreq = resolveCarrierFrequency(obj, rxInfo, channelLinkInfo)
            carrierFreq = 2.4e9;
            if isfield(obj.factoryConfig, 'LinkBudget') && isfield(obj.factoryConfig.LinkBudget, 'CarrierFrequency')
                carrierFreq = obj.factoryConfig.LinkBudget.CarrierFrequency;
            end

            rxScenarioConfig = getStructField(channelLinkInfo, 'RxScenarioConfig', struct());
            if isfield(rxScenarioConfig, 'Observation') && isfield(rxScenarioConfig.Observation, 'RealCarrierFrequency')
                carrierFreq = rxScenarioConfig.Observation.RealCarrierFrequency;
            elseif isfield(rxInfo, 'RealCarrierFrequency')
                carrierFreq = rxInfo.RealCarrierFrequency;
            end
        end

        function snr_dB = computeLinkBudgetSNR(obj, pathLoss_dB, txInfo)
            txPower_dBm = getStructField(txInfo, 'Power', 20);
            noisePSD = -174;
            noiseBW = 50e6;
            noiseFig = 6;

            if isfield(obj.factoryConfig, 'LinkBudget')
                lb = obj.factoryConfig.LinkBudget;
                noisePSD = getStructField(lb, 'ThermalNoisePSD', noisePSD);
                noiseBW = getStructField(lb, 'NoiseBandwidth', noiseBW);
                noiseFig = getStructField(lb, 'NoiseFigure', noiseFig);
            end

            noisePower_dBm = noisePSD + 10 * log10(noiseBW) + noiseFig;
            snr_dB = txPower_dBm - pathLoss_dB - noisePower_dBm;
        end

        function receivedSignalStruct = mergeChannelOutput(~, inputSignalStruct, channelBlockOutput)
            if isstruct(channelBlockOutput) && isfield(channelBlockOutput, 'Signal')
                receivedSignalStruct = channelBlockOutput;
            elseif isstruct(channelBlockOutput)
                receivedSignalStruct = inputSignalStruct;
                outputFields = fieldnames(channelBlockOutput);
                for idx = 1:numel(outputFields)
                    receivedSignalStruct.(outputFields{idx}) = channelBlockOutput.(outputFields{idx});
                end
            else
                receivedSignalStruct = inputSignalStruct;
                receivedSignalStruct.Signal = channelBlockOutput;
            end
        end

        function releaseCachedBlocks(obj)
            if ~isa(obj.cachedChannelBlock, 'containers.Map')
                return;
            end

            blockValues = values(obj.cachedChannelBlock);
            for idx = 1:numel(blockValues)
                block = blockValues{idx};
                if ~isempty(block) && isa(block, 'matlab.System') && isLocked(block)
                    release(block);
                end
            end
        end

    end

end

function value = getStructField(s, fieldName, defaultValue)
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    else
        value = defaultValue;
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
