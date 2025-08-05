classdef ReceiveFactory < matlab.System

    properties
        % Config: Struct containing the configuration for receiver types and models.
        % Passed directly by ChangShuo, loaded from the master config script.
        % Expected structure: Config.Simulation.handle, Config.Simulation.ReceiverModels
        Config struct
    end

    properties (Access = private)
        logger
        factoryConfig % Stores obj.Config directly
        cachedReceiverBlocks % Cache for instantiated receiver blocks
    end

    methods

        function obj = ReceiveFactory(varargin)
            setProperties(obj, nargin, varargin{:});
            obj.cachedReceiverBlocks = containers.Map;
            % Logger initialization now in setupImpl
        end

    end

    methods (Access = protected)

        function setupImpl(obj)

            if isempty(obj.Config) || ~isstruct(obj.Config)
                error('ReceiveFactory:ConfigError', 'Config property must be a valid struct.');
            end

            obj.factoryConfig = obj.Config;

            obj.logger = csrd.utils.logger.GlobalLogManager.getLogger();

            obj.logger.debug('ReceiveFactory setupImpl initializing with directly passed config struct.');

            % The config should now contain receiver type configurations (e.g., Simulation)
            % We'll validate the structure when specific receiver types are used
            receiverTypes = obj.getReceiverTypes();

            obj.logger.debug('ReceiveFactory setupImpl complete. Available receiver types: %s', strjoin(receiverTypes, ', '));
        end

        function receivedDataStruct = stepImpl(obj, inputSignalStruct, frameId, rxInfoThisRx, receiverScenarioConfig)
            % inputSignalStruct: from ChannelFactory (signal after passing through channel for one Rx)
            % rxInfoThisRx: The specific RxInfo struct for this receiver from ChangShuo (e.g. SiteConfig, ID)
            % receiverScenarioConfig: The specific receiver config from ScenarioConfig.Receivers(rxIdx)

            % Get receiver type from scenario config (e.g., "Simulation")
            receiverType = receiverScenarioConfig.Type; % Should be set by CommunicationBehaviorSimulator

            % Get specific receiver model type (this should be selected by ReceiveFactory)
            % For now, we'll select randomly from available receiver models
            receiverModelTypeID = obj.selectReceiverModel(receiverType);

            rxIdStr = string(receiverScenarioConfig.ID);

            obj.logger.debug('Frame %d, Rx %s: ReceiveFactory called for receiver type: %s, model: %s', ...
                frameId, rxIdStr, receiverType, receiverModelTypeID);

            % Get the receiver type configuration
            if ~isfield(obj.factoryConfig, receiverType)
                obj.logger.error('Frame %d, Rx %s: Receiver type ''%s'' not found in ReceiveFactory config.', ...
                    frameId, rxIdStr, receiverType);
                receivedDataStruct = struct('Error', 'ReceiverTypeNotFoundInFactoryConfig', 'OriginalSignal', inputSignalStruct);
                return;
            end

            receiverTypeConfig = obj.factoryConfig.(receiverType);

            % Check that we have the simulator handle
            if ~isfield(receiverTypeConfig, 'handle')
                obj.logger.error('Frame %d, Rx %s: No handle found for receiver type ''%s''.', ...
                    frameId, rxIdStr, receiverType);
                receivedDataStruct = struct('Error', 'ReceiverTypeHandleNotFound', 'OriginalSignal', inputSignalStruct);
                return;
            end

            % Get the receiver model configuration
            if ~isfield(receiverTypeConfig, 'ReceiverModels') || ...
                    ~isfield(receiverTypeConfig.ReceiverModels, receiverModelTypeID)
                obj.logger.error('Frame %d, Rx %s: ReceiverModel ''%s'' not found for receiver type ''%s''.', ...
                    frameId, rxIdStr, receiverModelTypeID, receiverType);
                receivedDataStruct = struct('Error', 'ReceiverModelNotFoundInFactoryConfig', 'OriginalSignal', inputSignalStruct);
                return;
            end

            receiverModelConfig = receiverTypeConfig.ReceiverModels.(receiverModelTypeID);
            blockHandleStr = receiverTypeConfig.handle;

            % --- Get or create the receiver block ---
            % Cache key should be unique per receiver instance and model
            cacheKey = sprintf('Receiver_%s_Type_%s_Model_%s', rxIdStr, receiverType, receiverModelTypeID);

            if ~isKey(obj.cachedReceiverBlocks, cacheKey)
                obj.logger.debug('Frame %d, Rx %s: Creating new receiver block for type: %s, model: %s (handle: %s)', ...
                    frameId, rxIdStr, receiverType, receiverModelTypeID, blockHandleStr);

                try
                    % Create the receiver block (e.g., RRFSimulator)
                    rxBlock = feval(blockHandleStr);

                    % Configure the block with selected receiver model parameters
                    obj.configureReceiverBlock(rxBlock, receiverModelConfig, rxInfoThisRx, receiverScenarioConfig);

                    obj.cachedReceiverBlocks(cacheKey) = rxBlock;

                    if isa(rxBlock, 'matlab.System')
                        % Setup the system object
                        try
                            setup(rxBlock, inputSignalStruct);
                            obj.logger.debug('Called setup(block, inputSignalStruct) on %s', class(rxBlock));
                        catch ME_setup
                            obj.logger.warning('Could not setup %s with inputSignalStruct. Error: %s. Trying setup without args.', class(rxBlock), ME_setup.message);
                            try setup(rxBlock); catch; end % Attempt basic setup
                        end

                    end

                    obj.logger.debug('Receiver block for type ''%s'', model ''%s'' (Rx %s) created and set up.', ...
                        receiverType, receiverModelTypeID, rxIdStr);
                catch ME
                    obj.logger.error('Frame %d, Rx %s: Failed to create/setup receiver block ''%s''. Error: %s', ...
                        frameId, rxIdStr, blockHandleStr, ME.message);
                    receivedDataStruct = struct('Error', 'ReceiverBlockInstantiationFailed', 'OriginalSignal', inputSignalStruct);
                    return;
                end

            end

            currentReceiverBlock = obj.cachedReceiverBlocks(cacheKey);

            % --- Call the receiver block's step method ---
            obj.logger.debug('Frame %d, Rx %s: Invoking step method of receiver block type: %s, model: %s', ...
                frameId, rxIdStr, receiverType, receiverModelTypeID);

            try
                % Input: signal struct from channel. Output: data struct (e.g. demodulated bits/symbols).
                receivedDataStruct = step(currentReceiverBlock, inputSignalStruct);
                obj.logger.debug('Frame %d, Rx %s: Reception step by %s successful.', frameId, rxIdStr, class(currentReceiverBlock));
            catch ME_step
                obj.logger.error('Frame %d, Rx %s: Error during step method of receiver block %s. Error: %s', ...
                    frameId, rxIdStr, class(currentReceiverBlock), ME_step.message);
                obj.logger.error('Stack: %s', getReport(ME_step, 'extended', 'hyperlinks', 'off'));
                receivedDataStruct = struct('Error', 'ReceiverBlockStepFailed', 'OriginalSignal', inputSignalStruct);
            end

        end

        function configureReceiverBlock(obj, rxBlock, receiverModelConfig, rxInfoThisRx, receiverScenarioConfig)
            % Configure the receiver block with receiver model parameters
            %
            % This method takes the selected receiver model configuration and applies
            % it to the receiver block (e.g., RRFSimulator) by setting appropriate
            % properties based on the parameter ranges in the configuration.

            obj.logger.debug('Configuring receiver block with receiver model parameters');

            % Configure basic receiver parameters from rxInfoThisRx
            propNames = fieldnames(rxInfoThisRx);

            for k = 1:length(propNames)
                propName = propNames{k};

                if isprop(rxBlock, propName)
                    rxBlock.(propName) = rxInfoThisRx.(propName);
                    obj.logger.debug('Set property ''%s'' from rxInfoThisRx.', propName);
                end

            end

            % Configure site-specific parameters
            if isfield(receiverScenarioConfig, 'Site') && isprop(rxBlock, 'SiteConfig')
                rxBlock.SiteConfig = receiverScenarioConfig.Site;
            end

            % Configure RF impairments based on the selected model
            configFields = fieldnames(receiverModelConfig);

            for i = 1:length(configFields)
                fieldName = configFields{i};
                fieldValue = receiverModelConfig.(fieldName);

                switch fieldName
                    case 'DCOffsetRange'

                        if isprop(rxBlock, 'DCOffset')
                            rxBlock.DCOffset = obj.randomInRange(fieldValue(1), fieldValue(2));
                            obj.logger.debug('Set DCOffset to %.2f dB', rxBlock.DCOffset);
                        end

                    case 'IqImbalanceConfig'

                        if isprop(rxBlock, 'IqImbalanceConfig')
                            iqConfig = struct();

                            if isfield(fieldValue, 'A')
                                iqConfig.A = obj.randomInRange(fieldValue.A(1), fieldValue.A(2));
                            end

                            if isfield(fieldValue, 'P')
                                iqConfig.P = obj.randomInRange(fieldValue.P(1), fieldValue.P(2));
                            end

                            rxBlock.IqImbalanceConfig = iqConfig;
                            obj.logger.debug('Set IqImbalanceConfig: A=%.2f dB, P=%.2f deg', iqConfig.A, iqConfig.P);
                        end

                    case 'ThermalNoiseConfig'

                        if isprop(rxBlock, 'ThermalNoiseConfig')
                            thermalConfig = struct();

                            if isfield(fieldValue, 'NoiseTemperature') && length(fieldValue.NoiseTemperature) == 2
                                thermalConfig.NoiseTemperature = obj.randomInRange(fieldValue.NoiseTemperature(1), fieldValue.NoiseTemperature(2));
                            else
                                thermalConfig.NoiseTemperature = fieldValue.NoiseTemperature;
                            end

                            rxBlock.ThermalNoiseConfig = thermalConfig;
                            obj.logger.debug('Set ThermalNoiseConfig with noise temperature: %.1f K', thermalConfig.NoiseTemperature);
                        end

                    case 'MemoryLessNonlinearityConfig'

                        if isprop(rxBlock, 'MemoryLessNonlinearityConfig')
                            nonlinConfig = struct();
                            configSubfields = fieldnames(fieldValue);

                            for j = 1:length(configSubfields)
                                subfield = configSubfields{j};
                                subvalue = fieldValue.(subfield);

                                if strcmp(subfield, 'LinearGain') && length(subvalue) == 2
                                    nonlinConfig.(subfield) = obj.randomInRange(subvalue(1), subvalue(2));
                                elseif strcmp(subfield, 'IIP3') && length(subvalue) == 2
                                    nonlinConfig.(subfield) = obj.randomInRange(subvalue(1), subvalue(2));
                                elseif strcmp(subfield, 'AMPMConversion') && length(subvalue) == 2
                                    nonlinConfig.(subfield) = obj.randomInRange(subvalue(1), subvalue(2));
                                else
                                    nonlinConfig.(subfield) = subvalue;
                                end

                            end

                            rxBlock.MemoryLessNonlinearityConfig = nonlinConfig;
                            obj.logger.debug('Set MemoryLessNonlinearityConfig with randomized parameters');
                        end

                end

            end

        end

        function releaseImpl(obj)
            obj.logger.debug('ReceiveFactory releaseImpl called.');
            blockKeys = keys(obj.cachedReceiverBlocks);

            for i = 1:length(blockKeys)
                blockKey = blockKeys{i};
                receiverBlock = obj.cachedReceiverBlocks(blockKey);

                if ~isempty(receiverBlock) && hasMethod(receiverBlock, 'release')

                    try
                        release(receiverBlock);
                        obj.logger.debug('Receiver block ''%s'' released.', blockKey);
                    catch ME
                        obj.logger.warning('Failed to release receiver block ''%s'': %s', blockKey, ME.message);
                    end

                end

            end

            obj.cachedReceiverBlocks = containers.Map(); % Clear the cache
            obj.logger.debug('All cached receiver blocks released.');
        end

        function resetImpl(obj)
            obj.logger.debug('ReceiveFactory resetImpl called.');
            blockKeys = keys(obj.cachedReceiverBlocks);

            for i = 1:length(blockKeys)
                blockKey = blockKeys{i};
                receiverBlock = obj.cachedReceiverBlocks(blockKey);

                if ~isempty(receiverBlock) && hasMethod(receiverBlock, 'reset')

                    try
                        reset(receiverBlock);
                        obj.logger.debug('Receiver block ''%s'' reset.', blockKey);
                    catch ME
                        obj.logger.warning('Failed to reset receiver block ''%s'': %s', blockKey, ME.message);
                    end

                end

            end

            obj.logger.debug('All cached receiver blocks reset.');
        end

        function receiverTypes = getReceiverTypes(obj)
            % Get available receiver types from configuration
            excludeFields = {'Parameters', 'LogDetails', 'Description', 'handle', 'Types'};
            allFields = fieldnames(obj.factoryConfig);
            receiverTypes = setdiff(allFields, excludeFields);
        end

        function receiverModel = selectReceiverModel(obj, receiverType)
            % Select a receiver model for the given receiver type
            % This implements the parameter selection logic that was moved from CommunicationBehaviorSimulator

            if ~isfield(obj.factoryConfig, receiverType) || ~isfield(obj.factoryConfig.(receiverType), 'ReceiverModels')
                obj.logger.warning('Receiver type ''%s'' not found, defaulting to IdealDemod receiver model', receiverType);
                receiverModel = 'IdealDemod';
                return;
            end

            receiverModels = obj.factoryConfig.(receiverType).ReceiverModels;
            availableModels = fieldnames(receiverModels);

            if isempty(availableModels)
                obj.logger.warning('No receiver models found for receiver type ''%s'', defaulting to IdealDemod', receiverType);
                receiverModel = 'IdealDemod';
            else
                % For now, select randomly. This could be made more sophisticated
                % based on scenario requirements, signal quality, etc.
                receiverModel = availableModels{randi(length(availableModels))};
                obj.logger.debug('Selected receiver model ''%s'' for receiver type ''%s''', receiverModel, receiverType);
            end

        end

        function value = randomInRange(obj, minVal, maxVal)
            % Generate random value in specified range
            if minVal == maxVal
                value = minVal;
            else
                value = minVal + (maxVal - minVal) * rand();
            end

        end

    end

end
