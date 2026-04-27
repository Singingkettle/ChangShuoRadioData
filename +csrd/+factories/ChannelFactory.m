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
                if csrd.utils.scenario.isScenarioSkipException(ME_step)
                    rethrow(ME_step);
                end
                rethrow(ME_step);
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
            % Thin instance-level adapter; the actual resolution policy
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
            % a Hidden static helper so unit tests can drive it without
            % spinning up matlab.System.
            defaultModel = csrd.factories.ChannelFactory.getDefaultModelForModeFromConfig( ...
                mode, obj.factoryConfig);
        end

        function cacheKey = resolveChannelCacheKey(obj, modelName, txIdStr, rxIdStr) %#ok<INUSL>
            % All channel models, including ray tracing, MUST be cached per
            % Tx-Rx link. Sharing a single ray-tracing block across links
            % causes per-link state (rays, channel filters, antenna sites,
            % seed) to leak between transmitters/receivers and corrupts
            % every link except the most recently configured one.
            cacheKey = sprintf('%s|Tx=%s|Rx=%s', modelName, char(txIdStr), char(rxIdStr));
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
                txSpecificInfo, rxSpecificInfo, channelLinkSpecificInfo, linkDistance_m, computedSNR_dB)
            % NOTE: linkDistance_m is in METERS to match the documented
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
                    obj.logger.warning('Could not update channel Seed: %s', ME_seed.message);
                end
            end
        end

    end

    methods

        function seedValue = deriveChannelSeed(~, frameId, txIdStr, rxIdStr, channelLinkInfo)
            % deriveChannelSeed Compute a burst-aware deterministic seed
            % for statistical channel blocks.
            %
            % This method is intentionally PUBLIC so unit tests and
            % downstream consumers (e.g. annotation enrichers in later
            % phases) can verify and reproduce the channel seed without
            % running the full step() pipeline.
            %
            % Inputs:
            %   frameId          : current observation frame id (used only
            %                      as a Phase 1 fallback when BurstId is
            %                      not yet plumbed through).
            %   txIdStr, rxIdStr : transmitter / receiver identifier (char
            %                      or string).
            %   channelLinkInfo  : channelLinkSpecificInfo struct that
            %                      MAY carry a BurstId field once Phase 2
            %                      / Burst plumbing lands.
            %
            % Output:
            %   seedValue : non-negative double in [1, 2^31 - 1].
            %
            % Formula:
            %   key = "Tx=<txIdStr>|Rx=<rxIdStr>|Burst=<burstKey>"
            %   seed = shortInt32Hash(key) (clamped to >= 1)
            %
            % burstKey selection:
            %   - channelLinkInfo.BurstId when present and non-empty
            %   - otherwise "frame_<frameId>" as a Phase 1 transitional
            %     fallback. The fallback intentionally differs across
            %     frames because, in the absence of a real BurstId, we
            %     have no way to link a Tx burst across frames anyway.
            burstKey = '';
            if isstruct(channelLinkInfo) && isfield(channelLinkInfo, 'BurstId') && ...
                    ~isempty(channelLinkInfo.BurstId)
                burstKey = char(string(channelLinkInfo.BurstId));
            end
            if isempty(burstKey)
                burstKey = sprintf('frame_%d', frameId);
            end
            key = sprintf('Tx=%s|Rx=%s|Burst=%s', ...
                char(txIdStr), char(rxIdStr), burstKey);
            seedValue = csrd.utils.hash.shortInt32Hash(key);
            if seedValue <= 0
                seedValue = 1;
            end
        end

        function receivedSignalStruct = mergeChannelOutput(~, inputSignalStruct, channelBlockOutput)
            % mergeChannelOutput Whitelist-based merge of a channel block
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

        function snr_dB = computeLinkBudgetSNR(obj, pathLoss_dB, txInfo, inputSignalStruct, rxInfo)
            % Compute analytical link-budget SNR.
            %
            % Noise bandwidth defaults to the receiver observation
            % bandwidth (rxInfo.SampleRate or rxInfo.ObservableRange) and
            % is clamped down to the planned occupied bandwidth of the
            % current Tx segment when the latter is narrower. Without
            % this clamp the noise floor is dominated by spectrum the
            % current Tx is not even using, and narrow-band signals get
            % a systematically pessimistic SNR label.

            txPower_dBm = getStructField(txInfo, 'Power', 20);
            noisePSD = -174;
            configuredBW = [];
            noiseFig = 6;

            if isfield(obj.factoryConfig, 'LinkBudget')
                lb = obj.factoryConfig.LinkBudget;
                noisePSD = getStructField(lb, 'ThermalNoisePSD', noisePSD);
                if isfield(lb, 'NoiseBandwidth') && ~isempty(lb.NoiseBandwidth) && lb.NoiseBandwidth > 0
                    configuredBW = lb.NoiseBandwidth;
                end
                noiseFig = getStructField(lb, 'NoiseFigure', noiseFig);
            end

            rxBW = [];
            if nargin >= 5 && isstruct(rxInfo)
                if isfield(rxInfo, 'SampleRate') && ~isempty(rxInfo.SampleRate) && rxInfo.SampleRate > 0
                    rxBW = rxInfo.SampleRate;
                elseif isfield(rxInfo, 'ObservableRange') && numel(rxInfo.ObservableRange) >= 2
                    rxBW = abs(rxInfo.ObservableRange(2) - rxInfo.ObservableRange(1));
                elseif isfield(rxInfo, 'BandWidth') && ~isempty(rxInfo.BandWidth) && rxInfo.BandWidth > 0
                    rxBW = rxInfo.BandWidth;
                end
            end

            txBW = [];
            if nargin >= 4 && isstruct(inputSignalStruct)
                if isfield(inputSignalStruct, 'Bandwidth') && ~isempty(inputSignalStruct.Bandwidth) && inputSignalStruct.Bandwidth > 0
                    txBW = inputSignalStruct.Bandwidth;
                elseif isfield(inputSignalStruct, 'Planned') && isstruct(inputSignalStruct.Planned) && ...
                        isfield(inputSignalStruct.Planned, 'Bandwidth') && inputSignalStruct.Planned.Bandwidth > 0
                    txBW = inputSignalStruct.Planned.Bandwidth;
                end
            end

            noiseBW = csrd.utils.linkbudget.resolveNoiseBandwidth( ...
                configuredBW, rxBW, txBW, 50e6);

            noisePower_dBm = noisePSD + 10 * log10(noiseBW) + noiseFig;
            snr_dB = txPower_dBm - pathLoss_dB - noisePower_dBm;
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

    methods (Static, Hidden)

        function modelName = resolveChannelModelNameFromConfig(requested, mode, factoryConfig)
            % resolveChannelModelNameFromConfig - Phase 2 (D5) channel
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
            %   3. Mode-default is registered → return it.
            %   4. AWGN is registered → return it (declarative fallback).
            %   5. Otherwise → throw CSRD:Blueprint:ChannelModelMismatch
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

            fallback = csrd.factories.ChannelFactory.getDefaultModelForModeFromConfig( ...
                mode, factoryConfig);
            fallbackChar = char(string(fallback));
            if isfield(factoryConfig.ChannelModels, fallbackChar)
                modelName = fallbackChar;
                return;
            end

            if isfield(factoryConfig.ChannelModels, 'AWGN')
                modelName = 'AWGN';
                return;
            end

            % Phase 2 (audit D5 / §3.6) — `modelNames{1}` arbitrary
            % first-key silent fallback removed; fail fast instead.
            error('CSRD:Blueprint:ChannelModelMismatch', ...
                ['Channel model resolution failed: requested model=''%s'' / ', ...
                 'mode=''%s'' has no matching entry in ', ...
                 'factoryConfig.ChannelModels and the declarative AWGN ', ...
                 'fallback is also missing. This blueprint should have ', ...
                 'been rejected by BlueprintFeasibilityValidator.', ...
                 'checkChannelModelInRegistry; reaching ChannelFactory ', ...
                 'means the validator was bypassed.'], requestedChar, char(string(mode)));
        end

        function defaultModel = getDefaultModelForModeFromConfig(mode, factoryConfig)
            % getDefaultModelForModeFromConfig - Phase 2 (D5) default
            % model lookup as a Hidden static helper. Returns 'AWGN' if
            % the registry does not declare an explicit default for the
            % requested mode (and no Statistical fallback either).
            defaultModel = 'AWGN';
            if ~isstruct(factoryConfig) || ~isfield(factoryConfig, 'DefaultModels') ...
                    || ~isstruct(factoryConfig.DefaultModels)
                return;
            end

            defaults = factoryConfig.DefaultModels;
            modeChar = char(string(mode));
            if ~isempty(modeChar) && isfield(defaults, modeChar)
                defaultModel = defaults.(modeChar);
            elseif isfield(defaults, 'Statistical')
                defaultModel = defaults.Statistical;
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
