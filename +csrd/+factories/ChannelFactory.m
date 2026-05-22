classdef ChannelFactory < matlab.System
% ChannelFactory - CSRD MATLAB declaration.

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
            % ChannelFactory - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            setProperties(obj, nargin, varargin{:});
            obj.cachedChannelBlock = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

        function precomputeRayTracingFrame(obj, frameId, txInfos, rxInfos, ...
                scenarioMapProfile, scenarioConfig)
            %PRECOMPUTERAYTRACINGFRAME Batch per-frame RayTracing geometry.
            % Inputs: see function signature and validation.
            % Outputs: see return values and contract fields.
            obj.ensurePrecomputeReady();
            if isempty(obj.factoryConfig) || ~isstruct(obj.factoryConfig) || ...
                    isempty(txInfos) || isempty(rxInfos)
                return;
            end
            if nargin < 6 || ~isstruct(scenarioConfig)
                scenarioConfig = struct();
            end

            try
                linkInfo = struct();
                linkInfo.MapProfile = scenarioMapProfile;
                linkInfo.ChannelModel = getStructField(scenarioMapProfile, ...
                    'ChannelModel', '');
                modelName = obj.resolveChannelModelName(linkInfo);
                if ~obj.isRayTracingModelName(modelName)
                    return;
                end
                cacheKey = obj.resolveChannelCacheKey(modelName, ...
                    "Frame", "Batch", linkInfo);
                channelBlock = obj.getChannelBlock(modelName, cacheKey);
                if ~ismethod(channelBlock, 'precomputeFrameRays')
                    return;
                end

                linkInfos = localBuildFrameLinkInfos( ...
                    txInfos, rxInfos, scenarioMapProfile, scenarioConfig);
                channelBlock.precomputeFrameRays(txInfos, rxInfos, linkInfos, frameId);
                csrd.runtime.performance.trace('count', ...
                    'RayTracing.FramePrecomputeRequested', 1, ...
                    struct('FrameId', frameId));
            catch ME
                csrd.runtime.performance.trace('event', ...
                    'RayTracing.FramePrecomputeFailed', 0, struct( ...
                        'FrameId', frameId, ...
                        'ErrorIdentifier', ME.identifier, ...
                        'ErrorMessage', ME.message));
                if ~isempty(obj.logger)
                    obj.logger.debug('Frame %d RayTracing precompute skipped: %s', ...
                        frameId, ME.message);
                end
            end
        end

    end

    methods (Access = private)

        function ensurePrecomputeReady(obj)
            %ENSUREPRECOMPUTEREADY Initialise state for public precompute calls.
            % Inputs: see function signature and validation.
            % Outputs: see return values and contract fields.
            %
            % MATLAB System objects run setupImpl before step(), but
            % precomputeRayTracingFrame is a normal public method called before
            % the first channel step in each frame. Without this guard the first
            % frame of every scenario silently skipped batching and fell back to
            % per-link raytrace.
            if isempty(obj.factoryConfig) && isstruct(obj.Config) && ...
                    isfield(obj.Config, 'ChannelModels')
                obj.factoryConfig = obj.Config;
            end
            if isempty(obj.logger)
                obj.logger = csrd.runtime.logger.GlobalLogManager.getLogger();
            end
            if isempty(obj.cachedChannelBlock) || ...
                    ~isa(obj.cachedChannelBlock, 'containers.Map')
                obj.cachedChannelBlock = containers.Map( ...
                    'KeyType', 'char', 'ValueType', 'any');
            end
        end

    end

    methods (Access = protected)

        function validateInputsImpl(~, ~, ~, ~, ~, ~)
            % validateInputsImpl - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
        end

        function setupImpl(obj)
            % setupImpl - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            if isempty(obj.Config) || ~isstruct(obj.Config) || ~isfield(obj.Config, 'ChannelModels')
                error('ChannelFactory:ConfigError', 'Config property must be a valid struct with a ChannelModels field.');
            end

            obj.factoryConfig = obj.Config;
            obj.logger = csrd.runtime.logger.GlobalLogManager.getLogger();
            % Phase 22: frame-level RayTracing precompute may populate the
            % channel block before the first step() call triggers setupImpl.
            % Keep that block cache alive; releaseImpl owns teardown.
            if isempty(obj.cachedChannelBlock) || ...
                    ~isa(obj.cachedChannelBlock, 'containers.Map')
                obj.cachedChannelBlock = containers.Map( ...
                    'KeyType', 'char', 'ValueType', 'any');
            end
            obj.logger.debug('ChannelFactory setup complete; channel model selection is scenario-driven.');
        end

        function receivedSignalStruct = stepImpl(obj, inputSignalStruct, frameId, txSpecificInfo, rxSpecificInfo, channelLinkSpecificInfo)
            % stepImpl - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            if ~isstruct(channelLinkSpecificInfo)
                channelLinkSpecificInfo = struct();
            end

            txIdStr = string(getStructField(txSpecificInfo, 'ID', 'Tx'));
            rxIdStr = string(getStructField(rxSpecificInfo, 'ID', 'Rx'));

            channelModelName = obj.resolveChannelModelName(channelLinkSpecificInfo);
            cacheKey = obj.resolveChannelCacheKey( ...
                channelModelName, txIdStr, rxIdStr, channelLinkSpecificInfo);
            currentChannelBlock = obj.getChannelBlock(channelModelName, cacheKey);
            obj.selectedChannelModelName = channelModelName;
            obj.isRayTracingSelected = contains(class(currentChannelBlock), 'RayTracing', 'IgnoreCase', true);

            obj.logger.debug('Frame %d, Tx %s to Rx %s: ChannelFactory selected model %s.', ...
                frameId, txIdStr, rxIdStr, channelModelName);

            [linkDistance_m, linkDistance_km] = obj.computeLinkDistance(txSpecificInfo, rxSpecificInfo, channelLinkSpecificInfo);
            computedPathLoss_dB = obj.computeFreeSpacePathLoss(linkDistance_m, rxSpecificInfo, channelLinkSpecificInfo);
            computedSNR_dB = obj.computeLinkBudgetSNR(computedPathLoss_dB, txSpecificInfo, ...
                inputSignalStruct, rxSpecificInfo);

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
                    txSpecificInfo, rxSpecificInfo, channelLinkSpecificInfo, linkDistance_m, computedSNR_dB);
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

                % Always preserve the analytical FSPL value so AI/ML
                % consumers can reason about the link budget that the
                % planning layer used. AppliedPathLoss reflects what the
                % actual channel block produced (e.g. RayTracing) when
                % available; otherwise it equals the analytical value.
                receivedSignalStruct.AnalyticalPathLoss = computedPathLoss_dB;
                if isfield(channelBlockOutput, 'PathLoss') && ~isempty(channelBlockOutput.PathLoss)
                    receivedSignalStruct.AppliedPathLoss = channelBlockOutput.PathLoss;
                elseif isfield(receivedSignalStruct, 'PathLoss') && ~isempty(receivedSignalStruct.PathLoss)
                    receivedSignalStruct.AppliedPathLoss = receivedSignalStruct.PathLoss;
                else
                    receivedSignalStruct.AppliedPathLoss = computedPathLoss_dB;
                end
                % Backwards-compat alias, keep as the analytical value.
                receivedSignalStruct.PathLoss = computedPathLoss_dB;

                receivedSignalStruct.ComputedSNR = computedSNR_dB;
                if isfield(channelBlockOutput, 'AppliedSNRdB') && ...
                        ~isempty(channelBlockOutput.AppliedSNRdB)
                    receivedSignalStruct.AppliedSNRdB = ...
                        channelBlockOutput.AppliedSNRdB;
                elseif ~isfield(receivedSignalStruct, 'AppliedSNRdB') || ...
                        isempty(receivedSignalStruct.AppliedSNRdB)
                    receivedSignalStruct.AppliedSNRdB = computedSNR_dB;
                end
                receivedSignalStruct.ChannelModel = channelModelName;

                obj.logger.debug('Frame %d, Tx %s to Rx %s: Channel processing by %s successful.', ...
                    frameId, txIdStr, rxIdStr, class(currentChannelBlock));
            catch ME_step
                obj.logger.error('Frame %d, Tx %s to Rx %s: Error during step of channel block %s. Error: %s', ...
                    frameId, txIdStr, rxIdStr, class(currentChannelBlock), ME_step.message);
                obj.logger.error('Stack: %s', getReport(ME_step, 'extended', 'hyperlinks', 'off'));

                % Scenario-level identifiers are still classified through
                % the shared predicate, but Phase 5 removes the generic
                % sentinel-output path as well: a failed channel block must
                % not write a half-corrupted frame or partial annotation.
                if csrd.pipeline.scenario.isScenarioSkipException(ME_step)
                    rethrow(ME_step);
                end
                rethrow(ME_step);
            end
        end

        function releaseImpl(obj)
            % releaseImpl - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            obj.logger.debug('ChannelFactory releaseImpl called.');
            obj.releaseCachedBlocks();
            obj.cachedChannelBlock = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.logger.debug('Cached channel blocks released.');
        end

        function resetImpl(obj)
            % resetImpl - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
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
            % Thin instance-level adapter; the actual resolution policy
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            % lives in the Hidden static helper so unit tests can
            % exercise every branch without spinning up matlab.System
            % setupImpl. Phase 2 (audit D5 / §3.6) removed the
            % `modelNames{1}` arbitrary-first-key silent fallback that
            % used to live at the end of this method.
            requested = getStructField(channelLinkInfo, 'ChannelModel', '');
            mapProfile = getStructField(channelLinkInfo, 'MapProfile', struct());
            mode = getStructField(mapProfile, 'Mode', '');

            modelName = csrd.factories.ChannelFactory.resolveChannelModelNameFromConfig( ...
                requested, mode, obj.factoryConfig);
        end

        function defaultModel = getDefaultModelForMode(obj, mode)
            % Phase 2 (D5): instance-level adapter. The actual policy is
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            % a Hidden static helper so unit tests can drive it without
            % spinning up matlab.System.
            defaultModel = csrd.factories.ChannelFactory.getDefaultModelForModeFromConfig( ...
                mode, obj.factoryConfig);
        end

        function cacheKey = resolveChannelCacheKey(obj, modelName, txIdStr, rxIdStr, channelLinkInfo) %#ok<INUSL>
            % Statistical/fading channel models are cached per Tx-Rx link.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            % RayTracing itself is stateless per link except for generated
            % site handles used for diagnostics; the expensive siteviewer and
            % propagation-model resources are map/profile-scoped, so Phase 21
            % caches one RayTracing block per map profile instead of per link.
            if obj.isRayTracingModelName(modelName)
                mapProfile = getStructField(channelLinkInfo, 'MapProfile', struct());
                mode = char(string(getStructField(mapProfile, 'Mode', 'Unknown')));
                osmFile = char(string(getStructField(mapProfile, 'OSMFile', '')));
                terrain = char(string(getStructField(mapProfile, 'Terrain', '')));
                material = char(string(getStructField(mapProfile, 'TerrainMaterial', '')));
                buildingsMaterial = char(string(getStructField(mapProfile, ...
                    'BuildingsMaterial', '')));
                surfaceMaterial = char(string(getStructField(mapProfile, ...
                    'SurfaceMaterial', '')));
                maxRefl = getStructField(mapProfile, 'MaxNumReflections', []);
                cacheKey = sprintf(['%s|Map=%s|File=%s|Terrain=%s|Mat=%s|', ...
                    'BuildMat=%s|SurfMat=%s|Refl=%s'], ...
                    modelName, mode, osmFile, terrain, material, ...
                    buildingsMaterial, surfaceMaterial, mat2str(maxRefl));
                return;
            end
            cacheKey = sprintf('%s|Tx=%s|Rx=%s', modelName, char(txIdStr), char(rxIdStr));
        end

        function tf = isRayTracingModelName(~, modelName)
            % isRayTracingModelName - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            tf = contains(modelName, 'RayTracing', 'IgnoreCase', true);
        end

        function block = getChannelBlock(obj, modelName, cacheKey)
            % getChannelBlock - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
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
            % applyBlockConfig - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
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
                        error('CSRD:Channel:BlockConfigAssignmentFailed', ...
                            'Could not set channel property "%s": %s', ...
                            fieldName, ME_set.message);
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
                txSpecificInfo, rxSpecificInfo, channelLinkSpecificInfo, linkDistance_m, computedSNR_dB)
            % NOTE: linkDistance_m is in METERS to match the documented
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            % BaseChannel.Distance unit. The previous signature used
            % linkDistance_km but the body referenced linkDistance_m,
            % which would crash with an undefined-variable error if the
            % distance-based SNR branch was ever taken on a statistical
            % channel.

            enableDistSNR = true;
            if isfield(obj.factoryConfig, 'LinkBudget') && isfield(obj.factoryConfig.LinkBudget, 'EnableDistanceBasedSNR')
                enableDistSNR = obj.factoryConfig.LinkBudget.EnableDistanceBasedSNR;
            end

            if enableDistSNR && linkDistance_m > 0
                if isprop(currentChannelBlock, 'SNRdB')
                    currentChannelBlock.SNRdB = computedSNR_dB;
                end
                if isprop(currentChannelBlock, 'Distance')
                    try
                        % BaseChannel.Distance is documented in METERS.
                        currentChannelBlock.Distance = max(linkDistance_m, 1);
                    catch ME_dist
                        error('CSRD:Channel:DistanceAssignmentFailed', ...
                            'Could not update channel Distance: %s', ME_dist.message);
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
                        error('CSRD:Channel:LinkInfoAssignmentFailed', ...
                            'Could not set channel prop "%s" from link info. Error: %s', ...
                            propName, ME_setprop_link.message);
                    end
                end
            end

            if isprop(currentChannelBlock, 'NumTransmitAntennas') && isfield(txSpecificInfo, 'NumTransmitAntennas')
                try
                    currentChannelBlock.NumTransmitAntennas = txSpecificInfo.NumTransmitAntennas;
                catch ME_txant
                    error('CSRD:Channel:TxAntennaAssignmentFailed', ...
                        'Could not update NumTransmitAntennas: %s', ME_txant.message);
                end
            end

            if isprop(currentChannelBlock, 'NumReceiveAntennas') && isfield(rxSpecificInfo, 'NumAntennas')
                try
                    currentChannelBlock.NumReceiveAntennas = rxSpecificInfo.NumAntennas;
                catch ME_rxant
                    error('CSRD:Channel:RxAntennaAssignmentFailed', ...
                        'Could not update NumReceiveAntennas: %s', ME_rxant.message);
                end
            end

            if isprop(currentChannelBlock, 'Seed')
                try
                    % Phase 1 / H13: Channel Seed must be derived from
                    % (TxId, RxId, BurstId) so the **same burst** keeps
                    % the **same fading realisation** across frames, and
                    % so different bursts on the same Tx-Rx link see
                    % independent fading. The previous frameId-based
                    % formula re-randomised the channel every frame and
                    % collapsed two distinct bursts on the same Tx onto
                    % the same seed within one frame, breaking physical
                    % consistency.
                    currentChannelBlock.Seed = obj.deriveChannelSeed( ...
                        frameId, txIdStr, rxIdStr, channelLinkSpecificInfo);
                catch ME_seed
                    error('CSRD:Channel:SeedAssignmentFailed', ...
                        'Could not update channel Seed: %s', ME_seed.message);
                end
            end
        end

    end

    methods

        function seedValue = deriveChannelSeed(~, frameId, txIdStr, rxIdStr, channelLinkInfo)
            % deriveChannelSeed Compute a burst-aware deterministic seed
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            % for statistical channel blocks.
            %
            % This method is intentionally PUBLIC so unit tests and
            % downstream consumers (e.g. annotation enrichers in later
            % phases) can verify and reproduce the channel seed without
            % running the full step() pipeline.
            %
            % Inputs:
            %   frameId          : current observation frame id, retained
            %                      only for API stability; it is not part
            %                      of the seed key.
            %   txIdStr, rxIdStr : transmitter / receiver identifier (char
            %                      or string).
            %   channelLinkInfo  : channelLinkSpecificInfo struct that
            %                      MUST carry a non-empty BurstId field.
            %
            % Output:
            %   seedValue : non-negative double in [1, 2^31 - 1].
            %
            % Formula:
            %   key = "Tx=<txIdStr>|Rx=<rxIdStr>|Burst=<burstKey>"
            %   seed = shortInt32Hash(key) (clamped to >= 1)
            %
            % burstKey selection:
            burstKey = '';
            if isstruct(channelLinkInfo) && isfield(channelLinkInfo, 'BurstId') && ...
                    ~isempty(channelLinkInfo.BurstId)
                burstKey = char(string(channelLinkInfo.BurstId));
            end
            if isempty(burstKey)
                error('CSRD:Channel:MissingBurstId', ...
                    ['channelLinkInfo.BurstId is required for deterministic ', ...
                     'burst-aware channel seeding.']);
            end
            key = sprintf('Tx=%s|Rx=%s|Burst=%s', ...
                char(txIdStr), char(rxIdStr), burstKey);
            seedValue = csrd.support.hash.shortInt32Hash(key);
            if seedValue <= 0
                seedValue = 1;
            end
        end

        function receivedSignalStruct = mergeChannelOutput(~, inputSignalStruct, channelBlockOutput)
            % mergeChannelOutput Whitelist-based merge of a channel block
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            % output into the upstream signal struct.
            %
            % Phase 1 / H14 contract (see docs/audits/phases/phase-1-dataflow.md §3.5):
            %
            %   1. The upstream inputSignalStruct (which already carries
            %      ID / TxId / BurstId / SegmentId / SubBurstId /
            %      ModulatorConfig / Header / Planned / etc.) is the
            %      base. Its fields are ALWAYS preserved unless they
            %      appear in CHANNEL_OWNED_FIELDS below.
            %   2. The channel block ONLY owns: 'Signal' plus the
            %      channel-specific physics fields enumerated in
            %      CHANNEL_OWNED_FIELDS. These overwrite the upstream
            %      values when the channel actually produced them.
            %   3. Any **new** field returned by the channel block that
            %      is NOT present upstream is added (forward-compatible
            %      injection of new physics metadata).
            %   4. A non-struct channelBlockOutput is treated as a raw
            %      Signal payload, attached to the upstream struct.
            %
            % This replaces the previous "if isfield(channelBlockOutput,
            % 'Signal') return channelBlockOutput end" branch, which
            % silently dropped every upstream field whenever the channel
            % block returned a struct containing a Signal field
            % (e.g. RayTracing).
            %
            % The method is intentionally public so unit tests can verify
            % the whitelist contract directly.

            CHANNEL_OWNED_FIELDS = { ...
                'Signal', ...
                'PathLoss', ...
                'AppliedPathLoss', ...
                'ChannelInfo', ...
                'PathDelays', ...
                'PathGains', ...
                'NumValidPaths', ...
                'RayInfo', ...
                'AntennaConfig', ...
                'ChannelImpulseResponse', ...
                'PropagationDelay', ...
                'NoiseRealization' ...
            };

            if ~isstruct(channelBlockOutput)
                receivedSignalStruct = inputSignalStruct;
                receivedSignalStruct.Signal = channelBlockOutput;
                return;
            end

            receivedSignalStruct = inputSignalStruct;
            outputFields = fieldnames(channelBlockOutput);
            for idx = 1:numel(outputFields)
                fieldName = outputFields{idx};
                if any(strcmp(fieldName, CHANNEL_OWNED_FIELDS))
                    receivedSignalStruct.(fieldName) = channelBlockOutput.(fieldName);
                elseif ~isfield(receivedSignalStruct, fieldName)
                    receivedSignalStruct.(fieldName) = channelBlockOutput.(fieldName);
                else
                    % Field exists upstream and is not channel-owned:
                    % preserve the upstream value (e.g. ID, TxId,
                    % BurstId, ModulatorConfig, Header, Planned, ...).
                end
            end
        end

    end

    methods (Access = private)

        function [linkDistance_m, linkDistance_km] = computeLinkDistance(obj, txInfo, rxInfo, channelLinkInfo)
            % computeLinkDistance - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            linkDistance_m = 0;
            txPos = getStructField(txInfo, 'Position', []);
            rxPos = getStructField(rxInfo, 'Position', []);

            if isempty(txPos) || isempty(rxPos)
                linkDistance_km = 0;
                return;
            end

            mapProfile = getStructField(channelLinkInfo, 'MapProfile', struct());
            mode = getStructField(mapProfile, 'Mode', '');

            if localUsesMeterPosition(txInfo) && localUsesMeterPosition(rxInfo)
                linkDistance_m = norm(txPos - rxPos);
            elseif any(strcmpi(mode, {'OSMBuildings', 'FlatTerrain'}))
                txGeo = localResolveGeoPosition(txInfo, txPos, 'Tx');
                rxGeo = localResolveGeoPosition(rxInfo, rxPos, 'Rx');
                linkDistance_m = geographicDistance(txGeo, rxGeo);
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
            % computeFreeSpacePathLoss - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            carrierFreq = obj.resolveCarrierFrequency(rxInfo, channelLinkInfo);
            waveLength = physconst('LightSpeed') / carrierFreq;
            pathLoss_dB = fspl(max(linkDistance_m, 1), waveLength);
        end

        function carrierFreq = resolveCarrierFrequency(obj, rxInfo, channelLinkInfo)
            % resolveCarrierFrequency - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            rxScenarioConfig = getStructField(channelLinkInfo, 'RxScenarioConfig', struct());
            if isfield(rxScenarioConfig, 'Observation') && ...
                    isfield(rxScenarioConfig.Observation, 'RealCarrierFrequency') && ...
                    ~isempty(rxScenarioConfig.Observation.RealCarrierFrequency)
                carrierFreq = rxScenarioConfig.Observation.RealCarrierFrequency;
            elseif isstruct(rxInfo) && isfield(rxInfo, 'RealCarrierFrequency') && ...
                    ~isempty(rxInfo.RealCarrierFrequency)
                carrierFreq = rxInfo.RealCarrierFrequency;
            else
                error('CSRD:Channel:MissingCarrierFrequency', ...
                    ['rxInfo.RealCarrierFrequency or ', ...
                     'channelLinkInfo.RxScenarioConfig.Observation.RealCarrierFrequency is required.']);
            end
            carrierFreq = requirePositiveFiniteScalar(carrierFreq, ...
                'rxInfo.RealCarrierFrequency');

            if isfield(obj.factoryConfig, 'LinkBudget') && ...
                    isfield(obj.factoryConfig.LinkBudget, 'CarrierFrequency') && ...
                    ~isempty(obj.factoryConfig.LinkBudget.CarrierFrequency)
                error('CSRD:Channel:DeprecatedCarrierFrequencyAuthority', ...
                    ['FactoryConfigs.Channel.LinkBudget.CarrierFrequency is forbidden. ', ...
                     'Use rxInfo.RealCarrierFrequency as the only runtime carrier authority.']);
            end
        end

        function snr_dB = computeLinkBudgetSNR(obj, pathLoss_dB, txInfo, inputSignalStruct, rxInfo)
            % Compute analytical link-budget SNR.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            %
            % Noise bandwidth is resolved from explicit link-budget,
            % receiver observation, and current segment bandwidth facts,
            % then clamped down to the planned occupied bandwidth of the
            % current Tx segment when the latter is narrower. Without
            % this clamp the noise floor is dominated by spectrum the
            % current Tx is not even using, and narrow-band signals get
            % a systematically pessimistic SNR label.

            if ~isstruct(txInfo) || ~isfield(txInfo, 'Power') || isempty(txInfo.Power)
                error('CSRD:Channel:MissingTransmitPower', ...
                    'txInfo.Power is required for link-budget SNR.');
            end
            txPower_dBm = requireFiniteScalar(txInfo.Power, 'txInfo.Power');
            configuredBW = [];

            if ~isfield(obj.factoryConfig, 'LinkBudget') || ...
                    ~isstruct(obj.factoryConfig.LinkBudget)
                error('CSRD:Channel:MissingLinkBudgetConfig', ...
                    'FactoryConfigs.Channel.LinkBudget is required for SNR labels.');
            end
            lb = obj.factoryConfig.LinkBudget;
            if ~isfield(lb, 'ThermalNoisePSD') || isempty(lb.ThermalNoisePSD)
                error('CSRD:Channel:MissingThermalNoisePSD', ...
                    'FactoryConfigs.Channel.LinkBudget.ThermalNoisePSD is required.');
            end
            if ~isfield(lb, 'NoiseFigure') || isempty(lb.NoiseFigure)
                error('CSRD:Channel:MissingNoiseFigure', ...
                    'FactoryConfigs.Channel.LinkBudget.NoiseFigure is required.');
            end
            noisePSD = requireFiniteScalar(lb.ThermalNoisePSD, ...
                'FactoryConfigs.Channel.LinkBudget.ThermalNoisePSD');
            noiseFig = requireFiniteScalar(lb.NoiseFigure, ...
                'FactoryConfigs.Channel.LinkBudget.NoiseFigure');
            if isfield(lb, 'NoiseBandwidth') && ~isempty(lb.NoiseBandwidth)
                configuredBW = requirePositiveFiniteScalar(lb.NoiseBandwidth, ...
                    'FactoryConfigs.Channel.LinkBudget.NoiseBandwidth');
            end

            rxBW = [];
            if nargin >= 5 && isstruct(rxInfo)
                if isfield(rxInfo, 'ObservableRange') && numel(rxInfo.ObservableRange) >= 2
                    rxRange = double(reshape(rxInfo.ObservableRange(1:2), 1, 2));
                    if any(~isfinite(rxRange)) || rxRange(2) <= rxRange(1)
                        error('CSRD:Channel:InvalidObservableRange', ...
                            'rxInfo.ObservableRange must be finite and increasing.');
                    end
                    rxBW = rxRange(2) - rxRange(1);
                elseif isfield(rxInfo, 'SampleRate') && ~isempty(rxInfo.SampleRate) && rxInfo.SampleRate > 0
                    rxBW = requirePositiveFiniteScalar(rxInfo.SampleRate, ...
                        'rxInfo.SampleRate');
                elseif isfield(rxInfo, 'BandWidth') && ~isempty(rxInfo.BandWidth) && rxInfo.BandWidth > 0
                    rxBW = requirePositiveFiniteScalar(rxInfo.BandWidth, ...
                        'rxInfo.BandWidth');
                end
            end

            txBW = [];
            if nargin >= 4 && isstruct(inputSignalStruct)
                if isfield(inputSignalStruct, 'Bandwidth') && ~isempty(inputSignalStruct.Bandwidth) && inputSignalStruct.Bandwidth > 0
                    txBW = requirePositiveFiniteScalar(inputSignalStruct.Bandwidth, ...
                        'inputSignalStruct.Bandwidth');
                elseif isfield(inputSignalStruct, 'Planned') && isstruct(inputSignalStruct.Planned) && ...
                        isfield(inputSignalStruct.Planned, 'Bandwidth') && inputSignalStruct.Planned.Bandwidth > 0
                    txBW = requirePositiveFiniteScalar(inputSignalStruct.Planned.Bandwidth, ...
                        'inputSignalStruct.Planned.Bandwidth');
                end
            end

            noiseBW = csrd.pipeline.linkbudget.resolveNoiseBandwidth( ...
                configuredBW, rxBW, txBW);

            noisePower_dBm = noisePSD + 10 * log10(noiseBW) + noiseFig;
            snr_dB = txPower_dBm - pathLoss_dB - noisePower_dBm;
        end

        function releaseCachedBlocks(obj)
            % releaseCachedBlocks - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
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

    methods (Static, Hidden)

        function modelName = resolveChannelModelNameFromConfig(requested, mode, factoryConfig)
            % resolveChannelModelNameFromConfig - Phase 2 (D5) channel
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            % model resolution policy as a Hidden static helper.
            %
            % This is the single source of truth for "given a requested
            % model name + a propagation mode + the factoryConfig
            % registry, which channel model should we instantiate?".
            % The instance method `resolveChannelModelName` is a thin
            % adapter; tests target this static helper directly so they
            % do not need to drive matlab.System.setupImpl.
            %
            % Resolution order:
            %   1. Caller asked for an empty/Statistical placeholder
            %      → resolve to the mode-default first.
            %   2. Requested model is registered → return it.
            %   3. Otherwise → throw CSRD:Blueprint:ChannelModelMismatch
            %      (Phase 2: NO arbitrary `modelNames{1}` silent
            %      fallback; the validator should have rejected this
            %      blueprint upstream).
            if ~isstruct(factoryConfig) || ~isfield(factoryConfig, 'ChannelModels') ...
                    || ~isstruct(factoryConfig.ChannelModels)
                error('CSRD:Blueprint:ChannelModelMismatch', ...
                    ['Channel model resolution failed: factoryConfig.ChannelModels ', ...
                     'is missing or not a struct (requested model=''%s''). The Phase 2 ', ...
                     'BlueprintFeasibilityValidator.checkChannelModelInRegistry should ', ...
                     'have rejected this blueprint upstream.'], char(string(requested)));
            end

            if isempty(requested) || (ischar(requested) && strcmpi(requested, 'Statistical')) ...
                    || (isstring(requested) && strcmpi(string(requested), "Statistical"))
                requested = csrd.factories.ChannelFactory.getDefaultModelForModeFromConfig( ...
                    mode, factoryConfig);
            end

            requestedChar = char(string(requested));
            if isfield(factoryConfig.ChannelModels, requestedChar)
                modelName = requestedChar;
                return;
            end

            % Phase 2 (audit D5 / §3.6) — `modelNames{1}` arbitrary
            % first-key silent fallback removed; fail fast instead.
            error('CSRD:Blueprint:ChannelModelMismatch', ...
                ['Channel model resolution failed: requested model=''%s'' / ', ...
                 'mode=''%s'' has no matching entry in ', ...
                 'factoryConfig.ChannelModels. This blueprint should have ', ...
                 'been rejected by BlueprintFeasibilityValidator.', ...
                 'checkChannelModelInRegistry; reaching ChannelFactory ', ...
                 'means the validator was bypassed.'], requestedChar, char(string(mode)));
        end

        function defaultModel = getDefaultModelForModeFromConfig(mode, factoryConfig)
            % getDefaultModelForModeFromConfig - Phase 2 (D5) default
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            % model lookup as a Hidden static helper. The registry must
            % declare a default for the requested mode or for Statistical.
            if ~isstruct(factoryConfig) || ~isfield(factoryConfig, 'DefaultModels') ...
                    || ~isstruct(factoryConfig.DefaultModels)
                error('CSRD:Blueprint:MissingChannelDefaultModel', ...
                    'FactoryConfigs.Channel.DefaultModels is required.');
            end

            defaults = factoryConfig.DefaultModels;
            modeChar = char(string(mode));
            if ~isempty(modeChar) && isfield(defaults, modeChar)
                defaultModel = defaults.(modeChar);
            elseif isfield(defaults, 'Statistical')
                defaultModel = defaults.Statistical;
            else
                error('CSRD:Blueprint:MissingChannelDefaultModel', ...
                    ['FactoryConfigs.Channel.DefaultModels must define ', ...
                     'the mode "%s" or a Statistical default.'], modeChar);
            end

            if isempty(defaultModel)
                error('CSRD:Blueprint:MissingChannelDefaultModel', ...
                    'Resolved channel default model for mode "%s" is empty.', modeChar);
            end
            defaultChar = char(string(defaultModel));
            if ~isfield(factoryConfig.ChannelModels, defaultChar)
                error('CSRD:Blueprint:ChannelModelMismatch', ...
                    ['FactoryConfigs.Channel.DefaultModels resolved to "%s", ', ...
                     'but that model is not registered in ChannelModels.'], defaultChar);
            end
        end

    end

end

function value = requireFiniteScalar(value, label)
    % requireFiniteScalar - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
        error('CSRD:RuntimeTruth:InvalidFiniteScalar', ...
            '%s must be a finite numeric scalar.', label);
    end
    value = double(value);
end

function value = requirePositiveFiniteScalar(value, label)
    % requirePositiveFiniteScalar - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    value = requireFiniteScalar(value, label);
    if value <= 0
        error('CSRD:RuntimeTruth:InvalidPositiveScalar', ...
            '%s must be positive.', label);
    end
end

function value = getStructField(s, fieldName, defaultValue)
    % getStructField - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end

function tf = localUsesMeterPosition(info)
    % localUsesMeterPosition - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    tf = isstruct(info) && isfield(info, 'PositionUnit') && ...
        ~isempty(info.PositionUnit) && strcmpi(char(string(info.PositionUnit)), 'meters');
end

function geoPosition = localResolveGeoPosition(info, position, roleName)
    % localResolveGeoPosition - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    if isstruct(info) && isfield(info, 'GeoPositionDeg') && ...
            ~isempty(info.GeoPositionDeg)
        geoPosition = double(info.GeoPositionDeg(:)).';
        if numel(geoPosition) ~= 3 || any(~isfinite(geoPosition))
            error('CSRD:Channel:InvalidGeoPosition', ...
                '%s GeoPositionDeg must be a finite [lat lon height] vector.', roleName);
        end
        return;
    end

    if localUsesMeterPosition(info)
        error('CSRD:Channel:MissingGeoPosition', ...
            '%s uses meter Position and requires GeoPositionDeg for geographic distance.', roleName);
    end

    if ~isnumeric(position) || numel(position) < 2 || ...
            any(~isfinite(position(1:min(3, numel(position)))))
        error('CSRD:Channel:InvalidLegacyPosition', ...
            '%s Position must be finite when GeoPositionDeg is absent.', roleName);
    end
    geoPosition = [position(2), position(1), getPositionHeight(position)];
end

function height = getPositionHeight(position)
    % getPositionHeight - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    if isnumeric(position) && numel(position) >= 3
        height = position(3);
    else
        height = 0;
    end
end

function distance_m = geographicDistance(txGeo, rxGeo)
    % geographicDistance - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
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

function linkInfos = localBuildFrameLinkInfos(txInfos, rxInfos, mapProfile, scenarioConfig)
    % localBuildFrameLinkInfos - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    nTx = numel(txInfos);
    nRx = numel(rxInfos);
    linkInfos = cell(1, nTx * nRx);
    cursor = 0;
    for txIdx = 1:nTx
        for rxIdx = 1:nRx
            cursor = cursor + 1;
            linkInfo = struct();
            linkInfo.TxScenarioConfig = localScenarioEntry( ...
                scenarioConfig, 'Transmitters', txIdx);
            linkInfo.RxScenarioConfig = localScenarioEntry( ...
                scenarioConfig, 'Receivers', rxIdx);
            linkInfo.MapProfile = mapProfile;
            linkInfo.ChannelModel = getStructField(mapProfile, 'ChannelModel', '');
            linkInfos{cursor} = linkInfo;
        end
    end
end

function entry = localScenarioEntry(scenarioConfig, fieldName, idx)
    % localScenarioEntry - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    entry = struct();
    if ~isstruct(scenarioConfig) || ~isfield(scenarioConfig, fieldName)
        return;
    end
    collection = scenarioConfig.(fieldName);
    if iscell(collection) && numel(collection) >= idx
        entry = collection{idx};
    elseif isstruct(collection) && numel(collection) >= idx
        entry = collection(idx);
    end
end
