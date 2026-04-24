classdef TransmitFactory < matlab.System

    properties
        % Config: Struct containing the configuration for transmitter types.
        % Passed directly by ChangShuo, loaded from the master config script.
        % Expected structure: Config.Simulation.handle, Config.Simulation.DCOffset, etc.
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
        end

    end

    methods (Access = protected)

        function validateInputsImpl(~, ~, ~, ~, ~)
        end

        function setupImpl(obj)

            if isempty(obj.Config) || ~isstruct(obj.Config)
                error('TransmitFactory:ConfigError', 'Config property must be a valid struct.');
            end

            obj.factoryConfig = obj.Config;
            obj.logger = csrd.utils.logger.GlobalLogManager.getLogger();

            obj.logger.debug('TransmitFactory setupImpl initializing.');

            transmitterTypes = obj.getTransmitterTypes();
            obj.logger.debug('TransmitFactory setupImpl complete. Available transmitter types: %s', strjoin(transmitterTypes, ', '));
        end

        function transmittedSignal = stepImpl(obj, inputSignalStruct, frameId, txInfoThisTx, transmitterScenarioConfig)
            % inputSignalStruct: The signal struct from modulation/processing
            % txInfoThisTx: The specific TxInfo struct for this transmitter
            % transmitterScenarioConfig: TxPlan struct from ScenarioConfig.Transmitters

            transmitterType = resolveField(transmitterScenarioConfig, 'Type', 'Hardware');
            txIdStr = string(resolveField(transmitterScenarioConfig, 'ID', 'EntityID'));

            obj.logger.debug('Frame %d, Tx %s: TransmitFactory called for transmitter type: %s', ...
                frameId, txIdStr, transmitterType);

            % Get the transmitter type configuration
            if ~isfield(obj.factoryConfig, transmitterType)
                obj.logger.error('Frame %d, Tx %s: Transmitter type ''%s'' not found in config.', ...
                    frameId, txIdStr, transmitterType);
                transmittedSignal = inputSignalStruct;
                transmittedSignal.Error = 'TransmitterTypeNotFound';
                return;
            end

            typeConfig = obj.factoryConfig.(transmitterType);

            if ~isfield(typeConfig, 'handle')
                obj.logger.error('Frame %d, Tx %s: No handle found for transmitter type ''%s''.', ...
                    frameId, txIdStr, transmitterType);
                transmittedSignal = inputSignalStruct;
                transmittedSignal.Error = 'TransmitterTypeHandleNotFound';
                return;
            end

            blockHandleStr = typeConfig.handle;
            cacheKey = sprintf('Transmitter_%s_Type_%s', txIdStr, transmitterType);

            if ~isKey(obj.cachedTransmitterBlocks, cacheKey)
                obj.logger.debug('Frame %d, Tx %s: Creating new transmitter block (handle: %s)', ...
                    frameId, txIdStr, blockHandleStr);

                try
                    txBlock = feval(blockHandleStr);
                    obj.configureTransmitterBlock(txBlock, typeConfig, txInfoThisTx, transmitterScenarioConfig);
                    obj.cachedTransmitterBlocks(cacheKey) = txBlock;

                    % Setup is deferred to the first step() call (auto-setup)
                    % TRFSimulator.setupImpl(obj,~) initializes RF impairment models

                    obj.logger.debug('Transmitter block for Tx %s created and configured.', txIdStr);
                catch ME
                    obj.logger.error('Frame %d, Tx %s: Failed to create transmitter block. Error: %s', ...
                        frameId, txIdStr, ME.message);
                    transmittedSignal = inputSignalStruct;
                    transmittedSignal.Error = 'TransmitterBlockInstantiationFailed';
                    return;
                end
            end

            currentTransmitterBlock = obj.cachedTransmitterBlocks(cacheKey);

            try
                % Set block properties from signal struct before calling step
                if isfield(inputSignalStruct, 'FrequencyOffset')
                    currentTransmitterBlock.CarrierFrequency = inputSignalStruct.FrequencyOffset;
                end
                if isfield(inputSignalStruct, 'SampleRate')
                    currentTransmitterBlock.SampleRate = inputSignalStruct.SampleRate;
                end
                if isfield(inputSignalStruct, 'Bandwidth')
                    currentTransmitterBlock.BandWidth = inputSignalStruct.Bandwidth;
                end

                % Set TargetSampleRate from receiver's sample rate
                if isfield(transmitterScenarioConfig, 'Spectrum') && ...
                        isfield(transmitterScenarioConfig.Spectrum, 'ReceiverSampleRate')
                    currentTransmitterBlock.TargetSampleRate = transmitterScenarioConfig.Spectrum.ReceiverSampleRate;
                elseif isfield(inputSignalStruct, 'SampleRate')
                    currentTransmitterBlock.TargetSampleRate = inputSignalStruct.SampleRate;
                end

                signalData = inputSignalStruct.Signal;
                processedSignal = step(currentTransmitterBlock, signalData);

                transmittedSignal = inputSignalStruct;
                transmittedSignal.Signal = processedSignal;
                transmittedSignal.FrequencyOffset = currentTransmitterBlock.CarrierFrequency;
                transmittedSignal.SampleRate = currentTransmitterBlock.TargetSampleRate;
                transmittedSignal.Bandwidth = currentTransmitterBlock.BandWidth;
                transmittedSignal.TxPower = currentTransmitterBlock.TxPowerDb;
                transmittedSignal.SamplePerFrame = size(processedSignal, 1);
                transmittedSignal.TimeDuration = transmittedSignal.SamplePerFrame / transmittedSignal.SampleRate;

                transmittedSignal.RFImpairments.DCOffset = currentTransmitterBlock.DCOffset;
                transmittedSignal.RFImpairments.IQImbalanceConfig = currentTransmitterBlock.IqImbalanceConfig;
                transmittedSignal.RFImpairments.PhaseNoiseConfig = currentTransmitterBlock.PhaseNoiseConfig;
                transmittedSignal.RFImpairments.NonlinearityConfig = currentTransmitterBlock.MemoryLessNonlinearityConfig;

                obj.logger.debug('Frame %d, Tx %s: Transmission step successful.', frameId, txIdStr);
            catch ME_step
                obj.logger.error('Frame %d, Tx %s: Error during step. Error: %s', ...
                    frameId, txIdStr, ME_step.message);
                transmittedSignal = inputSignalStruct;
                transmittedSignal.Error = 'TransmitterBlockStepFailed';
            end

        end

        function configureTransmitterBlock(obj, txBlock, typeConfig, txInfoThisTx, transmitterScenarioConfig)
            % Configure the transmitter block with parameters from typeConfig
            % Parameters are randomly selected from the defined ranges

            obj.logger.debug('Configuring transmitter block with RF impairment parameters');

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

            % === DC Offset ===
            if isfield(typeConfig, 'DCOffset') && isprop(txBlock, 'DCOffset')
                dcRange = typeConfig.DCOffset;
                txBlock.DCOffset = obj.randomInRange(dcRange(1), dcRange(2));
                obj.logger.debug('Set DCOffset to %.2f dB', txBlock.DCOffset);
            end

            % === IQ Imbalance ===
            if isfield(typeConfig, 'IQImbalance') && isprop(txBlock, 'IqImbalanceConfig')
                iqConfig = struct();
                iqField = typeConfig.IQImbalance;

                if isfield(iqField, 'Amplitude')
                    iqConfig.A = obj.randomInRange(iqField.Amplitude(1), iqField.Amplitude(2));
                end
                if isfield(iqField, 'Phase')
                    iqConfig.P = obj.randomInRange(iqField.Phase(1), iqField.Phase(2));
                end

                txBlock.IqImbalanceConfig = iqConfig;
                obj.logger.debug('Set IqImbalanceConfig: A=%.2f dB, P=%.2f deg', iqConfig.A, iqConfig.P);
            end

            % === Phase Noise ===
            if isfield(typeConfig, 'PhaseNoise') && isprop(txBlock, 'PhaseNoiseConfig')
                phaseConfig = struct();
                phaseField = typeConfig.PhaseNoise;

                % Multi-point phase noise specification
                if isfield(phaseField, 'FrequencyOffsets')
                    freqOffsets = phaseField.FrequencyOffsets;
                elseif isfield(phaseField, 'FrequencyOffset') && numel(phaseField.FrequencyOffset) > 2
                    freqOffsets = phaseField.FrequencyOffset;
                else
                    freqOffsets = [1e3, 10e3, 100e3];
                end
                phaseConfig.FrequencyOffset = freqOffsets;

                if isfield(phaseField, 'Level')
                    levelRange = phaseField.Level;
                    baseLevel = obj.randomInRange(levelRange(1), levelRange(2));
                    nPoints = numel(freqOffsets);
                    phaseConfig.Level = baseLevel + linspace(0, -20, nPoints);
                else
                    phaseConfig.Level = -100 * ones(1, numel(freqOffsets));
                end

                txBlock.PhaseNoiseConfig = phaseConfig;
                obj.logger.debug('Set PhaseNoiseConfig: Level=[%s] dBc/Hz, FreqOffset=[%s] Hz', ...
                    num2str(phaseConfig.Level, '%.1f '), num2str(phaseConfig.FrequencyOffset, '%.0f '));
            end

            % === Nonlinearity ===
            if isfield(typeConfig, 'Nonlinearity') && isprop(txBlock, 'MemoryLessNonlinearityConfig')
                nonlinConfig = obj.configureNonlinearity(typeConfig.Nonlinearity);
                txBlock.MemoryLessNonlinearityConfig = nonlinConfig;
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

                    % Handle split AMAM/AMPM parameters for Saleh and Ghorbani models
                    % Convert AMAMParametersLeft/Right to AMAMParameters vector
                    if contains(paramName, 'AMAMParametersLeft') && ~contains(paramName, 'Left1') && ~contains(paramName, 'Left2')
                        leftVal = obj.randomInRange(paramValue(1), paramValue(2));
                        if isfield(modelConfig, 'AMAMParametersRight')
                            rightRange = modelConfig.AMAMParametersRight;
                            rightVal = obj.randomInRange(rightRange(1), rightRange(2));
                            nonlinConfig.AMAMParameters = [leftVal, rightVal];
                        end
                        continue;
                    elseif contains(paramName, 'AMAMParametersRight') && ~contains(paramName, 'Right1') && ~contains(paramName, 'Right2')
                        continue; % Already handled with Left
                    elseif contains(paramName, 'AMPMParametersLeft') && ~contains(paramName, 'Left1') && ~contains(paramName, 'Left2')
                        leftVal = obj.randomInRange(paramValue(1), paramValue(2));
                        if isfield(modelConfig, 'AMPMParametersRight')
                            rightRange = modelConfig.AMPMParametersRight;
                            rightVal = obj.randomInRange(rightRange(1), rightRange(2));
                            nonlinConfig.AMPMParameters = [leftVal, rightVal];
                        end
                        continue;
                    elseif contains(paramName, 'AMPMParametersRight') && ~contains(paramName, 'Right1') && ~contains(paramName, 'Right2')
                        continue; % Already handled with Left
                    % Handle Ghorbani's 4-element parameter arrays
                    elseif strcmp(paramName, 'AMAMParametersLeft1')
                        p1 = obj.randomInRange(paramValue(1), paramValue(2));
                        p2 = 0; p3 = 0; p4 = 0;
                        if isfield(modelConfig, 'AMAMParametersLeft2')
                            p2 = obj.randomInRange(modelConfig.AMAMParametersLeft2(1), modelConfig.AMAMParametersLeft2(2));
                        end
                        if isfield(modelConfig, 'AMAMParametersRight1')
                            p3 = obj.randomInRange(modelConfig.AMAMParametersRight1(1), modelConfig.AMAMParametersRight1(2));
                        end
                        if isfield(modelConfig, 'AMAMParametersRight2')
                            p4 = obj.randomInRange(modelConfig.AMAMParametersRight2(1), modelConfig.AMAMParametersRight2(2));
                        end
                        nonlinConfig.AMAMParameters = [p1, p2, p3, p4];
                        continue;
                    elseif contains(paramName, 'AMAMParametersLeft2') || contains(paramName, 'AMAMParametersRight1') || contains(paramName, 'AMAMParametersRight2')
                        continue; % Already handled
                    elseif strcmp(paramName, 'AMPMParametersLeft1')
                        p1 = obj.randomInRange(paramValue(1), paramValue(2));
                        p2 = 0; p3 = 0; p4 = 0;
                        if isfield(modelConfig, 'AMPMParametersLeft2')
                            p2 = obj.randomInRange(modelConfig.AMPMParametersLeft2(1), modelConfig.AMPMParametersLeft2(2));
                        end
                        if isfield(modelConfig, 'AMPMParametersRight1')
                            p3 = obj.randomInRange(modelConfig.AMPMParametersRight1(1), modelConfig.AMPMParametersRight1(2));
                        end
                        if isfield(modelConfig, 'AMPMParametersRight2')
                            p4 = obj.randomInRange(modelConfig.AMPMParametersRight2(1), modelConfig.AMPMParametersRight2(2));
                        end
                        nonlinConfig.AMPMParameters = [p1, p2, p3, p4];
                        continue;
                    elseif contains(paramName, 'AMPMParametersLeft2') || contains(paramName, 'AMPMParametersRight1') || contains(paramName, 'AMPMParametersRight2')
                        continue; % Already handled
                    end

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

                % Add default ReferenceImpedance if not in config
                if ~isfield(nonlinConfig, 'ReferenceImpedance')
                    nonlinConfig.ReferenceImpedance = 1; % Default 1 ohm
                end

                obj.logger.debug('Configured nonlinearity method ''%s''', selectedMethod);
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

            obj.cachedTransmitterBlocks = containers.Map();
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
            excludeFields = {'LogDetails', 'Description', 'Types'};
            allFields = fieldnames(obj.factoryConfig);
            transmitterTypes = setdiff(allFields, excludeFields);
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
