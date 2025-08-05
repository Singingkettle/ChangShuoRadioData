classdef TransmitFactory < matlab.System

    properties
        % Config: Struct containing the configuration for transmitter types and models.
        % Passed directly by ChangShuo, loaded from the master config script.
        % Expected structure: Config.Simulation.handle, Config.Simulation.ImpairmentModels
        Config struct
    end

    properties (Access = private)
        logger
        factoryConfig % Stores obj.Config directly
        cachedTransmitterBlocks % Cache for instantiated transmitter blocks
    end

    methods

        function obj = TransmitFactory(varargin)
            setProperties(obj, nargin, varargin{:});
            obj.cachedTransmitterBlocks = containers.Map;
            % Logger initialization now in setupImpl
        end

    end

    methods (Access = protected)

        function setupImpl(obj)

            if isempty(obj.Config) || ~isstruct(obj.Config)
                error('TransmitFactory:ConfigError', 'Config property must be a valid struct.');
            end

            obj.factoryConfig = obj.Config; % The passed-in struct is the factory's config

            obj.logger = csrd.utils.logger.GlobalLogManager.getLogger();

            obj.logger.debug('TransmitFactory setupImpl initializing with directly passed config struct.');

            % The config should now contain transmitter type configurations (e.g., Simulation)
            % We'll validate the structure when specific transmitter types are used
            transmitterTypes = obj.getTransmitterTypes();

            obj.logger.debug('TransmitFactory setupImpl complete. Available transmitter types: %s', strjoin(transmitterTypes, ', '));
        end

        function transmittedSignal = stepImpl(obj, inputSignalStruct, frameId, txInfoThisTx, transmitterScenarioConfig)
            % inputSignalStruct: The signal struct from EventFactory (already placed in freq/time)
            % txInfoThisTx: The specific TxInfo struct for this transmitter from ChangShuo
            % transmitterScenarioConfig: The specific transmitter config from ScenarioConfig.Transmitters(txIdx)

            % Get transmitter type from scenario config (e.g., "Simulation")
            transmitterType = transmitterScenarioConfig.Type; % Should be set by CommunicationBehaviorSimulator

            % Get specific impairment model type (this should be selected by TransmitFactory)
            % For now, we'll select randomly from available impairment models
            impairmentModelTypeID = obj.selectImpairmentModel(transmitterType);

            txIdStr = string(transmitterScenarioConfig.ID);

            obj.logger.debug('Frame %d, Tx %s: TransmitFactory called for transmitter type: %s, impairment model: %s', ...
                frameId, txIdStr, transmitterType, impairmentModelTypeID);

            % Get the transmitter type configuration
            if ~isfield(obj.factoryConfig, transmitterType)
                obj.logger.error('Frame %d, Tx %s: Transmitter type ''%s'' not found in TransmitFactory config.', ...
                    frameId, txIdStr, transmitterType);
                transmittedSignal = inputSignalStruct;
                transmittedSignal.Error = 'TransmitterTypeNotFoundInFactoryConfig';
                return;
            end

            transmitterTypeConfig = obj.factoryConfig.(transmitterType);

            % Check that we have the simulator handle
            if ~isfield(transmitterTypeConfig, 'handle')
                obj.logger.error('Frame %d, Tx %s: No handle found for transmitter type ''%s''.', ...
                    frameId, txIdStr, transmitterType);
                transmittedSignal = inputSignalStruct;
                transmittedSignal.Error = 'TransmitterTypeHandleNotFound';
                return;
            end

            % Get the impairment model configuration
            if ~isfield(transmitterTypeConfig, 'ImpairmentModels') || ...
                    ~isfield(transmitterTypeConfig.ImpairmentModels, impairmentModelTypeID)
                obj.logger.error('Frame %d, Tx %s: ImpairmentModel ''%s'' not found for transmitter type ''%s''.', ...
                    frameId, txIdStr, impairmentModelTypeID, transmitterType);
                transmittedSignal = inputSignalStruct;
                transmittedSignal.Error = 'ImpairmentModelNotFoundInFactoryConfig';
                return;
            end

            impairmentModelConfig = transmitterTypeConfig.ImpairmentModels.(impairmentModelTypeID);
            blockHandleStr = transmitterTypeConfig.handle;

            % --- Get or create the transmitter block ---
            % Cache key should be unique per transmitter instance and impairment model
            cacheKey = sprintf('Transmitter_%s_Type_%s_Model_%s', txIdStr, transmitterType, impairmentModelTypeID);

            if ~isKey(obj.cachedTransmitterBlocks, cacheKey)
                obj.logger.debug('Frame %d, Tx %s: Creating new transmitter block for type: %s, model: %s (handle: %s)', ...
                    frameId, txIdStr, transmitterType, impairmentModelTypeID, blockHandleStr);

                try
                    % Create the transmitter block (e.g., TRFSimulator)
                    txBlock = feval(blockHandleStr);

                    % Configure the block with selected impairment model parameters
                    obj.configureTransmitterBlock(txBlock, impairmentModelConfig, txInfoThisTx, transmitterScenarioConfig);

                    obj.cachedTransmitterBlocks(cacheKey) = txBlock;

                    if isa(txBlock, 'matlab.System')
                        % Setup the system object
                        try
                            setup(txBlock, inputSignalStruct);
                            obj.logger.debug('Called setup(block, inputSignalStruct) on %s', class(txBlock));
                        catch ME_setup
                            obj.logger.warning('Could not setup %s with inputSignalStruct. Error: %s. Trying setup without args.', class(txBlock), ME_setup.message);
                            try setup(txBlock); catch; end % Attempt basic setup
                        end

                    end

                    obj.logger.debug('Transmitter block for type ''%s'', model ''%s'' (Tx %s) created and set up.', ...
                        transmitterType, impairmentModelTypeID, txIdStr);
                catch ME
                    obj.logger.error('Frame %d, Tx %s: Failed to create/setup transmitter block ''%s''. Error: %s', ...
                        frameId, txIdStr, blockHandleStr, ME.message);
                    transmittedSignal = inputSignalStruct;
                    transmittedSignal.Error = 'TransmitterBlockInstantiationFailed';
                    return;
                end

            end

            currentTransmitterBlock = obj.cachedTransmitterBlocks(cacheKey);

            % --- Call the transmitter block's step method ---
            obj.logger.debug('Frame %d, Tx %s: Invoking step method of transmitter block type: %s, model: %s', ...
                frameId, txIdStr, transmitterType, impairmentModelTypeID);

            try
                % The input to the transmitter block is the signal struct from event/modulation stage.
                % The output should also be a signal struct, potentially with modified data due to impairments.
                transmittedSignal = step(currentTransmitterBlock, inputSignalStruct);
                obj.logger.debug('Frame %d, Tx %s: Transmission step by %s successful.', frameId, txIdStr, class(currentTransmitterBlock));
            catch ME_step
                obj.logger.error('Frame %d, Tx %s: Error during step method of transmitter block %s. Error: %s', ...
                    frameId, txIdStr, class(currentTransmitterBlock), ME_step.message);
                obj.logger.error('Stack: %s', getReport(ME_step, 'extended', 'hyperlinks', 'off'));
                transmittedSignal = inputSignalStruct;
                transmittedSignal.Error = 'TransmitterBlockStepFailed';
            end

        end

        function configureTransmitterBlock(obj, txBlock, impairmentModelConfig, txInfoThisTx, transmitterScenarioConfig)
            % Configure the transmitter block with impairment model parameters
            %
            % This method takes the selected impairment model configuration and applies
            % it to the transmitter block (e.g., TRFSimulator) by setting appropriate
            % properties based on the parameter ranges in the configuration.

            obj.logger.debug('Configuring transmitter block with impairment model parameters');

            % Configure basic transmitter parameters from txInfoThisTx
            propNames = fieldnames(txInfoThisTx);

            for k = 1:length(propNames)
                propName = propNames{k};

                if isprop(txBlock, propName)
                    txBlock.(propName) = txInfoThisTx.(propName);
                    obj.logger.debug('Set property ''%s'' from txInfoThisTx.', propName);
                end

            end

            % Configure site-specific parameters
            if isfield(transmitterScenarioConfig, 'Site') && isprop(txBlock, 'SiteConfig')
                txBlock.SiteConfig = transmitterScenarioConfig.Site;
            end

            % Configure RF impairments based on the selected model
            configFields = fieldnames(impairmentModelConfig);

            for i = 1:length(configFields)
                fieldName = configFields{i};
                fieldValue = impairmentModelConfig.(fieldName);

                switch fieldName
                    case 'DCOffsetRange'

                        if isprop(txBlock, 'DCOffset')
                            txBlock.DCOffset = obj.randomInRange(fieldValue(1), fieldValue(2));
                            obj.logger.debug('Set DCOffset to %.2f dB', txBlock.DCOffset);
                        end

                    case 'IqImbalanceConfig'

                        if isprop(txBlock, 'IqImbalanceConfig')
                            iqConfig = struct();

                            if isfield(fieldValue, 'A')
                                iqConfig.A = obj.randomInRange(fieldValue.A(1), fieldValue.A(2));
                            end

                            if isfield(fieldValue, 'P')
                                iqConfig.P = obj.randomInRange(fieldValue.P(1), fieldValue.P(2));
                            end

                            txBlock.IqImbalanceConfig = iqConfig;
                            obj.logger.debug('Set IqImbalanceConfig: A=%.2f dB, P=%.2f deg', iqConfig.A, iqConfig.P);
                        end

                    case 'PhaseNoiseConfig'

                        if isprop(txBlock, 'PhaseNoiseConfig')
                            phaseConfig = struct();
                            configSubfields = fieldnames(fieldValue);

                            for j = 1:length(configSubfields)
                                subfield = configSubfields{j};
                                subvalue = fieldValue.(subfield);

                                if strcmp(subfield, 'Level') && length(subvalue) == 2
                                    phaseConfig.(subfield) = obj.randomInRange(subvalue(1), subvalue(2));
                                elseif strcmp(subfield, 'FrequencyOffset') && length(subvalue) == 2
                                    phaseConfig.(subfield) = obj.randomInRange(subvalue(1), subvalue(2));
                                else
                                    phaseConfig.(subfield) = subvalue;
                                end

                            end

                            txBlock.PhaseNoiseConfig = phaseConfig;
                            obj.logger.debug('Set PhaseNoiseConfig with randomized parameters');
                        end

                    case 'MemoryLessNonlinearityConfig'

                        if isprop(txBlock, 'MemoryLessNonlinearityConfig')
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

                            txBlock.MemoryLessNonlinearityConfig = nonlinConfig;
                            obj.logger.debug('Set MemoryLessNonlinearityConfig with randomized parameters');
                        end

                end

            end

        end

        function releaseImpl(obj)
            obj.logger.debug('TransmitFactory releaseImpl called.');

            blockKeys = keys(obj.cachedTransmitterBlocks);

            for i = 1:length(blockKeys)
                blockKey = blockKeys{i};
                transmitterBlock = obj.cachedTransmitterBlocks(blockKey);

                if ~isempty(transmitterBlock) && hasMethod(transmitterBlock, 'release')

                    try
                        release(transmitterBlock);
                        obj.logger.debug('Transmitter block ''%s'' released.', blockKey);
                    catch ME
                        obj.logger.warning('Failed to release transmitter block ''%s'': %s', blockKey, ME.message);
                    end

                end

            end

            obj.cachedTransmitterBlocks = containers.Map(); % Clear the cache

            obj.logger.debug('All cached transmitter blocks released.');
        end

        function resetImpl(obj)
            obj.logger.debug('TransmitFactory resetImpl called.');

            blockKeys = keys(obj.cachedTransmitterBlocks);

            for i = 1:length(blockKeys)
                blockKey = blockKeys{i};
                transmitterBlock = obj.cachedTransmitterBlocks(blockKey);

                if ~isempty(transmitterBlock) && hasMethod(transmitterBlock, 'reset')

                    try
                        reset(transmitterBlock);
                        obj.logger.debug('Transmitter block ''%s'' reset.', blockKey);
                    catch ME
                        obj.logger.warning('Failed to reset transmitter block ''%s'': %s', blockKey, ME.message);
                    end

                end

            end

            obj.logger.debug('All cached transmitter blocks reset.');
        end

        function transmitterTypes = getTransmitterTypes(obj)
            % Get available transmitter types from configuration
            excludeFields = {'Parameters', 'Behavior', 'LogDetails', 'Description', 'handle'};
            allFields = fieldnames(obj.factoryConfig);
            transmitterTypes = setdiff(allFields, excludeFields);
        end

        function impairmentModel = selectImpairmentModel(obj, transmitterType)
            % Select an impairment model for the given transmitter type
            % This implements the parameter selection logic that was moved from CommunicationBehaviorSimulator

            if ~isfield(obj.factoryConfig, transmitterType) || ~isfield(obj.factoryConfig.(transmitterType), 'ImpairmentModels')
                obj.logger.warning('Transmitter type ''%s'' not found, defaulting to Ideal impairment model', transmitterType);
                impairmentModel = 'Ideal';
                return;
            end

            impairmentModels = obj.factoryConfig.(transmitterType).ImpairmentModels;
            availableModels = fieldnames(impairmentModels);

            if isempty(availableModels)
                obj.logger.warning('No impairment models found for transmitter type ''%s'', defaulting to Ideal', transmitterType);
                impairmentModel = 'Ideal';
            else
                % For now, select randomly. This could be made more sophisticated
                % based on scenario requirements, link quality, etc.
                impairmentModel = availableModels{randi(length(availableModels))};
                obj.logger.debug('Selected impairment model ''%s'' for transmitter type ''%s''', impairmentModel, transmitterType);
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
