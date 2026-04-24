classdef ReceiveFactory < matlab.System

    properties
        % Config: Struct containing the configuration for receiver types.
        % Passed directly by ChangShuo, loaded from the master config script.
        % Expected structure: Config.Simulation.handle, Config.Simulation.DCOffset, etc.
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
        end

    end

    methods (Access = protected)

        function validateInputsImpl(~, ~, ~, ~, ~)
        end

        function setupImpl(obj)

            if isempty(obj.Config) || ~isstruct(obj.Config)
                error('ReceiveFactory:ConfigError', 'Config property must be a valid struct.');
            end

            obj.factoryConfig = obj.Config;
            obj.logger = csrd.utils.logger.GlobalLogManager.getLogger();

            obj.logger.debug('ReceiveFactory setupImpl initializing.');

            receiverTypes = obj.getReceiverTypes();
            obj.logger.debug('ReceiveFactory setupImpl complete. Available receiver types: %s', strjoin(receiverTypes, ', '));
        end

        function receivedDataStruct = stepImpl(obj, inputSignalStruct, frameId, rxInfoThisRx, receiverScenarioConfig)
            % inputSignalStruct: from ChannelFactory (signal after passing through channel)
            % rxInfoThisRx: The specific RxInfo struct for this receiver
            % receiverScenarioConfig: RxPlan struct from ScenarioConfig.Receivers

            receiverType = resolveField(receiverScenarioConfig, 'Type', 'Hardware');
            rxIdStr = string(resolveField(receiverScenarioConfig, 'ID', 'EntityID'));

            obj.logger.debug('Frame %d, Rx %s: ReceiveFactory called for receiver type: %s', ...
                frameId, rxIdStr, receiverType);

            % Get the receiver type configuration
            if ~isfield(obj.factoryConfig, receiverType)
                obj.logger.error('Frame %d, Rx %s: Receiver type ''%s'' not found in config.', ...
                    frameId, rxIdStr, receiverType);
                receivedDataStruct = struct('Error', 'ReceiverTypeNotFound', 'OriginalSignal', inputSignalStruct);
                return;
            end

            typeConfig = obj.factoryConfig.(receiverType);

            if ~isfield(typeConfig, 'handle')
                obj.logger.error('Frame %d, Rx %s: No handle found for receiver type ''%s''.', ...
                    frameId, rxIdStr, receiverType);
                receivedDataStruct = struct('Error', 'ReceiverTypeHandleNotFound', 'OriginalSignal', inputSignalStruct);
                return;
            end

            blockHandleStr = typeConfig.handle;
            cacheKey = sprintf('Receiver_%s_Type_%s', rxIdStr, receiverType);

            if ~isKey(obj.cachedReceiverBlocks, cacheKey)
                obj.logger.debug('Frame %d, Rx %s: Creating new receiver block (handle: %s)', ...
                    frameId, rxIdStr, blockHandleStr);

                try
                    rxBlock = feval(blockHandleStr);
                    obj.configureReceiverBlock(rxBlock, typeConfig, rxInfoThisRx, receiverScenarioConfig);
                    obj.cachedReceiverBlocks(cacheKey) = rxBlock;

                    % Setup is deferred to the first step() call (auto-setup)
                    % RRFSimulator.setupImpl(obj,~) initializes RF impairment models

                    obj.logger.debug('Receiver block for Rx %s created and configured.', rxIdStr);
                catch ME
                    obj.logger.error('Frame %d, Rx %s: Failed to create receiver block. Error: %s', ...
                        frameId, rxIdStr, ME.message);
                    receivedDataStruct = struct('Error', 'ReceiverBlockInstantiationFailed', 'OriginalSignal', inputSignalStruct);
                    return;
                end
            end

            currentReceiverBlock = obj.cachedReceiverBlocks(cacheKey);

            try
                % Set block properties from signal struct / rxInfo before calling step
                if isfield(rxInfoThisRx, 'SampleRate')
                    currentReceiverBlock.MasterClockRate = rxInfoThisRx.SampleRate;
                end

                % Extract signal array - RRFSimulator accepts numeric arrays
                if isstruct(inputSignalStruct) && isfield(inputSignalStruct, 'Signal')
                    signalData = inputSignalStruct.Signal;
                else
                    signalData = inputSignalStruct;
                end

                processedSignal = step(currentReceiverBlock, signalData);

                receivedDataStruct = struct();
                receivedDataStruct.Signal = processedSignal;
                receivedDataStruct.SampleRate = currentReceiverBlock.MasterClockRate;

                if isstruct(inputSignalStruct) && isfield(inputSignalStruct, 'Components')
                    receivedDataStruct.Components = inputSignalStruct.Components;
                end

                receivedDataStruct.RxImpairments.DCOffset = currentReceiverBlock.DCOffset;
                receivedDataStruct.RxImpairments.IqImbalanceConfig = currentReceiverBlock.IqImbalanceConfig;
                receivedDataStruct.RxImpairments.ThermalNoiseConfig = currentReceiverBlock.ThermalNoiseConfig;

                obj.logger.debug('Frame %d, Rx %s: Reception step successful.', frameId, rxIdStr);
            catch ME_step
                obj.logger.error('Frame %d, Rx %s: Error during step. Error: %s', ...
                    frameId, rxIdStr, ME_step.message);
                receivedDataStruct = inputSignalStruct;
                if isstruct(receivedDataStruct)
                    receivedDataStruct.Error = 'ReceiverBlockStepFailed';
                else
                    receivedDataStruct = struct('Error', 'ReceiverBlockStepFailed', 'OriginalSignal', inputSignalStruct);
                end
            end

        end

        function configureReceiverBlock(obj, rxBlock, typeConfig, rxInfoThisRx, receiverScenarioConfig)
            % Configure the receiver block with parameters from typeConfig
            % Parameters are randomly selected from the defined ranges

            obj.logger.debug('Configuring receiver block with RF impairment parameters');

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

            % === DC Offset ===
            if isfield(typeConfig, 'DCOffset') && isprop(rxBlock, 'DCOffset')
                dcRange = typeConfig.DCOffset;
                rxBlock.DCOffset = obj.randomInRange(dcRange(1), dcRange(2));
                obj.logger.debug('Set DCOffset to %.2f dB', rxBlock.DCOffset);
            end

            % === IQ Imbalance ===
            if isfield(typeConfig, 'IQImbalance') && isprop(rxBlock, 'IqImbalanceConfig')
                iqConfig = struct();
                iqField = typeConfig.IQImbalance;

                if isfield(iqField, 'Amplitude')
                    iqConfig.A = obj.randomInRange(iqField.Amplitude(1), iqField.Amplitude(2));
                end
                if isfield(iqField, 'Phase')
                    iqConfig.P = obj.randomInRange(iqField.Phase(1), iqField.Phase(2));
                end

                rxBlock.IqImbalanceConfig = iqConfig;
                obj.logger.debug('Set IqImbalanceConfig: A=%.2f dB, P=%.2f deg', iqConfig.A, iqConfig.P);
            end

            % === Thermal Noise ===
            if isfield(typeConfig, 'ThermalNoise') && isprop(rxBlock, 'ThermalNoiseConfig')
                thermalConfig = struct();
                noiseField = typeConfig.ThermalNoise;

                if isfield(noiseField, 'NoiseFigure')
                    nfRange = noiseField.NoiseFigure;
                    thermalConfig.NoiseFigure = obj.randomInRange(nfRange(1), nfRange(2));
                    obj.logger.debug('Set ThermalNoise NoiseFigure: %.2f dB', thermalConfig.NoiseFigure);
                    
                    % Calculate NoiseTemperature from NoiseFigure
                    % NoiseTemperature = T0 * (NoiseFigure_linear - 1)
                    % where T0 = 290K (reference temperature)
                    nfLinear = 10^(thermalConfig.NoiseFigure / 10);
                    thermalConfig.NoiseTemperature = 290 * (nfLinear - 1);
                    obj.logger.debug('Calculated NoiseTemperature: %.2f K', thermalConfig.NoiseTemperature);
                end

                rxBlock.ThermalNoiseConfig = thermalConfig;
            end

            % === Nonlinearity ===
            if isfield(typeConfig, 'Nonlinearity') && isprop(rxBlock, 'MemoryLessNonlinearityConfig')
                nonlinConfig = obj.configureNonlinearity(typeConfig.Nonlinearity);
                rxBlock.MemoryLessNonlinearityConfig = nonlinConfig;
                obj.logger.debug('Set MemoryLessNonlinearityConfig with method: %s', nonlinConfig.Method);
            end

        end

        function nonlinConfig = configureNonlinearity(obj, nonlinField)
            % Configure nonlinearity by randomly selecting a method and its parameters

            nonlinConfig = struct();

            % Select a random method from available methods
            if isfield(nonlinField, 'Methods')
                methods = nonlinField.Methods;
                selectedMethod = methods{randi(length(methods))};
                nonlinConfig.Method = selectedMethod;

                % Get the corresponding model config based on selected method
                switch selectedMethod
                    case 'Cubic polynomial'
                        modelConfig = nonlinField.CubicPolynomial;
                    case 'Hyperbolic tangent'
                        modelConfig = nonlinField.HyperbolicTangent;
                    case 'Saleh model'
                        modelConfig = nonlinField.SalehModel;
                    case 'Ghorbani model'
                        modelConfig = nonlinField.GhorbaniModel;
                    case 'Modified Rapp model'
                        modelConfig = nonlinField.ModifiedRappModel;
                    otherwise
                        obj.logger.warning('Unknown nonlinearity method: %s', selectedMethod);
                        return;
                end

                % Configure parameters for the selected model
                paramFields = fieldnames(modelConfig);
                for i = 1:length(paramFields)
                    paramName = paramFields{i};
                    paramValue = modelConfig.(paramName);

                    if iscell(paramValue)
                        % Select randomly from cell array (e.g., TOISpecification)
                        nonlinConfig.(paramName) = paramValue{randi(length(paramValue))};
                    elseif isnumeric(paramValue) && length(paramValue) == 2
                        % Random value from range
                        nonlinConfig.(paramName) = obj.randomInRange(paramValue(1), paramValue(2));
                    else
                        % Use as-is
                        nonlinConfig.(paramName) = paramValue;
                    end
                end

                % Special handling for Saleh/Ghorbani models: combine Left/Right into Parameters
                if strcmp(selectedMethod, 'Saleh model')
                    if isfield(modelConfig, 'AMAMParametersLeft') && isfield(modelConfig, 'AMAMParametersRight')
                        alpha = obj.randomInRange(modelConfig.AMAMParametersLeft(1), modelConfig.AMAMParametersLeft(2));
                        beta = obj.randomInRange(modelConfig.AMAMParametersRight(1), modelConfig.AMAMParametersRight(2));
                        nonlinConfig.AMAMParameters = [alpha, beta];
                    end
                    if isfield(modelConfig, 'AMPMParametersLeft') && isfield(modelConfig, 'AMPMParametersRight')
                        alpha = obj.randomInRange(modelConfig.AMPMParametersLeft(1), modelConfig.AMPMParametersLeft(2));
                        beta = obj.randomInRange(modelConfig.AMPMParametersRight(1), modelConfig.AMPMParametersRight(2));
                        nonlinConfig.AMPMParameters = [alpha, beta];
                    end
                elseif strcmp(selectedMethod, 'Ghorbani model')
                    if isfield(modelConfig, 'AMAMParametersLeft1') && isfield(modelConfig, 'AMAMParametersLeft2') && ...
                       isfield(modelConfig, 'AMAMParametersRight1') && isfield(modelConfig, 'AMAMParametersRight2')
                        x1 = obj.randomInRange(modelConfig.AMAMParametersLeft1(1), modelConfig.AMAMParametersLeft1(2));
                        x2 = obj.randomInRange(modelConfig.AMAMParametersLeft2(1), modelConfig.AMAMParametersLeft2(2));
                        y1 = obj.randomInRange(modelConfig.AMAMParametersRight1(1), modelConfig.AMAMParametersRight1(2));
                        y2 = obj.randomInRange(modelConfig.AMAMParametersRight2(1), modelConfig.AMAMParametersRight2(2));
                        nonlinConfig.AMAMParameters = [x1, x2, y1, y2];
                    end
                    if isfield(modelConfig, 'AMPMParametersLeft1') && isfield(modelConfig, 'AMPMParametersLeft2') && ...
                       isfield(modelConfig, 'AMPMParametersRight1') && isfield(modelConfig, 'AMPMParametersRight2')
                        x1 = obj.randomInRange(modelConfig.AMPMParametersLeft1(1), modelConfig.AMPMParametersLeft1(2));
                        x2 = obj.randomInRange(modelConfig.AMPMParametersLeft2(1), modelConfig.AMPMParametersLeft2(2));
                        y1 = obj.randomInRange(modelConfig.AMPMParametersRight1(1), modelConfig.AMPMParametersRight1(2));
                        y2 = obj.randomInRange(modelConfig.AMPMParametersRight2(1), modelConfig.AMPMParametersRight2(2));
                        nonlinConfig.AMPMParameters = [x1, x2, y1, y2];
                    end
                end

                % Add default ReferenceImpedance if not in config
                if ~isfield(nonlinConfig, 'ReferenceImpedance')
                    nonlinConfig.ReferenceImpedance = 1; % Default 1 ohm
                end

                obj.logger.debug('Configured nonlinearity method ''%s''', selectedMethod);
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

            obj.cachedReceiverBlocks = containers.Map();
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
            excludeFields = {'LogDetails', 'Description', 'Types'};
            allFields = fieldnames(obj.factoryConfig);
            receiverTypes = setdiff(allFields, excludeFields);
        end

        function value = randomInRange(~, minVal, maxVal)
            % Generate random value in specified range
            if minVal == maxVal
                value = minVal;
            else
                value = minVal + (maxVal - minVal) * rand();
            end
        end

    end

end

function value = resolveField(s, flatName, nestedAlt)
    if isfield(s, flatName)
        value = s.(flatName);
    elseif strcmp(flatName, 'Type') && isfield(s, 'Hardware') && isstruct(s.Hardware) && isfield(s.Hardware, 'Type')
        value = s.Hardware.Type;
    elseif strcmp(flatName, 'ID') && isfield(s, 'EntityID')
        value = s.EntityID;
    elseif nargin >= 3 && isfield(s, nestedAlt) && ~isstruct(s.(nestedAlt))
        value = s.(nestedAlt);
    else
        value = '';
    end
end
