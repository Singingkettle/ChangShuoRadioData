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

                % Phase 1 / C1: emit the FULL set of RF impairments
                % actually realised by RRFSimulator. Previously we only
                % surfaced 3 of the 5 impairment knobs, dropping
                % MemoryLessNonlinearityConfig and SampleRateOffset on
                % the floor and breaking annotation reproducibility for
                % AI/ML training. Type is included as a defensive
                % traceability tag so consumers can correlate the
                % impairment dump with the receiver-type recipe used.
                receivedDataStruct.RxImpairments = struct();
                receivedDataStruct.RxImpairments.Type = receiverType;
                receivedDataStruct.RxImpairments.DCOffset = currentReceiverBlock.DCOffset;
                receivedDataStruct.RxImpairments.IqImbalanceConfig = currentReceiverBlock.IqImbalanceConfig;
                receivedDataStruct.RxImpairments.ThermalNoiseConfig = currentReceiverBlock.ThermalNoiseConfig;
                if isprop(currentReceiverBlock, 'MemoryLessNonlinearityConfig')
                    receivedDataStruct.RxImpairments.MemoryLessNonlinearityConfig = ...
                        currentReceiverBlock.MemoryLessNonlinearityConfig;
                else
                    receivedDataStruct.RxImpairments.MemoryLessNonlinearityConfig = struct();
                end
                if isprop(currentReceiverBlock, 'SampleRateOffset')
                    receivedDataStruct.RxImpairments.SampleRateOffset = ...
                        currentReceiverBlock.SampleRateOffset;
                else
                    receivedDataStruct.RxImpairments.SampleRateOffset = 0;
                end

                obj.logger.debug('Frame %d, Rx %s: Reception step successful.', frameId, rxIdStr);
            catch ME_step
                % Phase 3 (audit §3.4 / §17.5 P3-6): the legacy fallback
                % stamped `receivedDataStruct.Error = 'ReceiverBlockStepFailed'`
                % onto the input signal and let the pipeline keep walking,
                % which produced annotations with phantom RxImpairments and
                % buried the real failure. Phase 3 lets the exception
                % propagate so generateSingleFrame / SimulationRunner can
                % decide between scenario-skip
                % (csrd.utils.scenario.isScenarioSkipException) and a hard
                % crash.
                if csrd.utils.scenario.isScenarioSkipException(ME_step)
                    rethrow(ME_step);
                end
                obj.logger.error('Frame %d, Rx %s: Error during step. Error: %s', ...
                    frameId, rxIdStr, ME_step.message);
                rethrow(ME_step);
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
            %CONFIGURENONLINEARITY Build a `comm.MemorylessNonlinearity` config.
            %
            %   v0.4 deep refactor: the config produced here populates
            %   ONLY the property set the System object accepts for the
            %   chosen Method, per the official MATLAB documentation
            %   "Dependencies" section. No off-Method fields are emitted.
            %
            %   The selected Method is drawn uniformly from
            %   nonlinField.Methods. ReferenceImpedance is sourced from
            %   nonlinField.ReferenceImpedance (defaulting to 50 Ω
            %   industry standard) and applied to every Method.

            if ~isstruct(nonlinField) || ~isfield(nonlinField, 'Methods') ...
                    || isempty(nonlinField.Methods)
                error('CSRD:ReceiveFactory:NoNonlinearityMethods', ...
                    ['Nonlinearity config must list at least one Method ' ...
                     'in nonlinField.Methods.']);
            end

            methodsList = nonlinField.Methods;
            selectedMethod = methodsList{randi(numel(methodsList))};

            referenceImpedance = 50;
            if isfield(nonlinField, 'ReferenceImpedance') && ...
                    ~isempty(nonlinField.ReferenceImpedance)
                referenceImpedance = nonlinField.ReferenceImpedance;
            end

            switch selectedMethod
                case 'Cubic polynomial'
                    nonlinConfig = obj.buildCubicPolynomialConfig( ...
                        nonlinField.CubicPolynomial);
                case 'Hyperbolic tangent'
                    nonlinConfig = obj.buildHyperbolicTangentConfig( ...
                        nonlinField.HyperbolicTangent);
                case 'Saleh model'
                    nonlinConfig = obj.buildSalehModelConfig( ...
                        nonlinField.SalehModel);
                case 'Ghorbani model'
                    nonlinConfig = obj.buildGhorbaniModelConfig( ...
                        nonlinField.GhorbaniModel);
                case 'Modified Rapp model'
                    nonlinConfig = obj.buildModifiedRappModelConfig( ...
                        nonlinField.ModifiedRappModel);
                case 'Lookup table'
                    nonlinConfig = obj.buildLookupTableConfig( ...
                        nonlinField.LookupTable);
                otherwise
                    error('CSRD:ReceiveFactory:UnknownNonlinearityMethod', ...
                        ['Unknown comm.MemorylessNonlinearity Method "%s". ' ...
                         'Supported: Cubic polynomial, Hyperbolic tangent, ' ...
                         'Saleh model, Ghorbani model, Modified Rapp model, ' ...
                         'Lookup table.'], selectedMethod);
            end

            nonlinConfig.ReferenceImpedance = referenceImpedance;
            obj.logger.debug('Configured nonlinearity method "%s"', selectedMethod);
        end

        function cfg = buildCubicPolynomialConfig(obj, src)
            cfg = struct();
            cfg.Method = 'Cubic polynomial';
            cfg.LinearGain = obj.randomInRange(src.LinearGain(1), src.LinearGain(2));
            toiList = src.TOISpecifications;
            cfg.TOISpecification = toiList{randi(numel(toiList))};
            switch cfg.TOISpecification
                case 'IIP3',  cfg.IIP3  = obj.randomInRange(src.IIP3(1),  src.IIP3(2));
                case 'OIP3',  cfg.OIP3  = obj.randomInRange(src.OIP3(1),  src.OIP3(2));
                case 'IP1dB', cfg.IP1dB = obj.randomInRange(src.IP1dB(1), src.IP1dB(2));
                case 'OP1dB', cfg.OP1dB = obj.randomInRange(src.OP1dB(1), src.OP1dB(2));
                case 'IPsat', cfg.IPsat = obj.randomInRange(src.IPsat(1), src.IPsat(2));
                case 'OPsat', cfg.OPsat = obj.randomInRange(src.OPsat(1), src.OPsat(2));
            end
            cfg.AMPMConversion  = obj.randomInRange( ...
                src.AMPMConversion(1), src.AMPMConversion(2));
            cfg.PowerLowerLimit = obj.resolvePowerLimit(src.PowerLowerLimit, -40);
            cfg.PowerUpperLimit = obj.resolvePowerLimit(src.PowerUpperLimit,  Inf);
        end

        function cfg = buildHyperbolicTangentConfig(obj, src)
            cfg = struct();
            cfg.Method = 'Hyperbolic tangent';
            cfg.LinearGain      = obj.randomInRange(src.LinearGain(1),     src.LinearGain(2));
            cfg.IIP3            = obj.randomInRange(src.IIP3(1),           src.IIP3(2));
            cfg.AMPMConversion  = obj.randomInRange(src.AMPMConversion(1), src.AMPMConversion(2));
            cfg.PowerLowerLimit = obj.resolvePowerLimit(src.PowerLowerLimit, -40);
            cfg.PowerUpperLimit = obj.resolvePowerLimit(src.PowerUpperLimit,  Inf);
        end

        function cfg = buildSalehModelConfig(obj, src)
            cfg = struct();
            cfg.Method = 'Saleh model';
            cfg.InputScaling   = obj.randomInRange(src.InputScaling(1),   src.InputScaling(2));
            cfg.OutputScaling  = obj.randomInRange(src.OutputScaling(1),  src.OutputScaling(2));
            alphaA = obj.randomInRange(src.AMAMParametersAlpha(1), src.AMAMParametersAlpha(2));
            betaA  = obj.randomInRange(src.AMAMParametersBeta(1),  src.AMAMParametersBeta(2));
            cfg.AMAMParameters = [alphaA, betaA];
            alphaP = obj.randomInRange(src.AMPMParametersAlpha(1), src.AMPMParametersAlpha(2));
            betaP  = obj.randomInRange(src.AMPMParametersBeta(1),  src.AMPMParametersBeta(2));
            cfg.AMPMParameters = [alphaP, betaP];
        end

        function cfg = buildGhorbaniModelConfig(obj, src)
            cfg = struct();
            cfg.Method = 'Ghorbani model';
            cfg.InputScaling   = obj.randomInRange(src.InputScaling(1),  src.InputScaling(2));
            cfg.OutputScaling  = obj.randomInRange(src.OutputScaling(1), src.OutputScaling(2));
            x1 = obj.randomInRange(src.AMAMParametersX1(1), src.AMAMParametersX1(2));
            x2 = obj.randomInRange(src.AMAMParametersX2(1), src.AMAMParametersX2(2));
            x3 = obj.randomInRange(src.AMAMParametersX3(1), src.AMAMParametersX3(2));
            x4 = obj.randomInRange(src.AMAMParametersX4(1), src.AMAMParametersX4(2));
            cfg.AMAMParameters = [x1, x2, x3, x4];
            y1 = obj.randomInRange(src.AMPMParametersY1(1), src.AMPMParametersY1(2));
            y2 = obj.randomInRange(src.AMPMParametersY2(1), src.AMPMParametersY2(2));
            y3 = obj.randomInRange(src.AMPMParametersY3(1), src.AMPMParametersY3(2));
            y4 = obj.randomInRange(src.AMPMParametersY4(1), src.AMPMParametersY4(2));
            cfg.AMPMParameters = [y1, y2, y3, y4];
        end

        function cfg = buildModifiedRappModelConfig(obj, src)
            cfg = struct();
            cfg.Method = 'Modified Rapp model';
            cfg.LinearGain            = obj.randomInRange(src.LinearGain(1),            src.LinearGain(2));
            cfg.Smoothness            = obj.randomInRange(src.Smoothness(1),            src.Smoothness(2));
            cfg.PhaseGainRadian       = obj.randomInRange(src.PhaseGainRadian(1),       src.PhaseGainRadian(2));
            cfg.PhaseSaturation       = obj.randomInRange(src.PhaseSaturation(1),       src.PhaseSaturation(2));
            cfg.PhaseSmoothness       = obj.randomInRange(src.PhaseSmoothness(1),       src.PhaseSmoothness(2));
            cfg.OutputSaturationLevel = obj.randomInRange(src.OutputSaturationLevel(1), src.OutputSaturationLevel(2));
        end

        function cfg = buildLookupTableConfig(~, src)
            cfg = struct();
            cfg.Method = 'Lookup table';
            if ~isfield(src, 'Table') || isempty(src.Table) || size(src.Table, 2) ~= 3
                error('CSRD:ReceiveFactory:InvalidLookupTable', ...
                    ['Lookup table must be an Nx3 matrix [Pin_dBm, ' ...
                     'Pout_dBm, dPhi_deg]; the supplied src.Table is ' ...
                     'missing or has the wrong shape.']);
            end
            cfg.Table = src.Table;
        end

        function value = resolvePowerLimit(obj, raw, defaultValue)
            if isempty(raw)
                value = defaultValue;
                return;
            end
            if ischar(raw) || isstring(raw)
                value = Inf;
                return;
            end
            if isnumeric(raw) && isscalar(raw)
                value = raw;
                return;
            end
            if isnumeric(raw) && numel(raw) == 2
                value = obj.randomInRange(raw(1), raw(2));
                return;
            end
            error('CSRD:ReceiveFactory:InvalidPowerLimit', ...
                'PowerLimit must be empty, scalar, [min max], or "Inf".');
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
