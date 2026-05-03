classdef TransmitFactory < matlab.System
        % 中文说明：提供 CSRD 生产链路中的 TransmitFactory 实现。

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
            % TransmitFactory - Production declaration in CSRD.
            % 中文说明：TransmitFactory 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            setProperties(obj, nargin, varargin{:});
            obj.cachedTransmitterBlocks = containers.Map;
        end

    end

    methods (Access = protected)

        function validateInputsImpl(~, ~, ~, ~, ~)
            % validateInputsImpl - Production declaration in CSRD.
            % 中文说明：validateInputsImpl 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
        end

        function setupImpl(obj)
            % setupImpl - Production declaration in CSRD.
            % 中文说明：setupImpl 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.

            if isempty(obj.Config) || ~isstruct(obj.Config)
                error('TransmitFactory:ConfigError', 'Config property must be a valid struct.');
            end

            obj.factoryConfig = obj.Config;
            obj.logger = csrd.runtime.logger.GlobalLogManager.getLogger();

            obj.logger.debug('TransmitFactory setupImpl initializing.');

            transmitterTypes = obj.getTransmitterTypes();
            obj.logger.debug('TransmitFactory setupImpl complete. Available transmitter types: %s', strjoin(transmitterTypes, ', '));
        end

        function transmittedSignal = stepImpl(obj, inputSignalStruct, frameId, txInfoThisTx, transmitterScenarioConfig)
            % inputSignalStruct: The signal struct from modulation/processing
            % 中文说明：stepImpl 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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
                error('CSRD:TransmitFactory:TransmitterTypeNotFound', ...
                    'Transmitter type "%s" not found in TransmitFactory config.', ...
                    transmitterType);
            end

            typeConfig = obj.factoryConfig.(transmitterType);

            if ~isfield(typeConfig, 'handle')
                obj.logger.error('Frame %d, Tx %s: No handle found for transmitter type ''%s''.', ...
                    frameId, txIdStr, transmitterType);
                error('CSRD:TransmitFactory:TransmitterTypeHandleNotFound', ...
                    'No handle configured for transmitter type "%s".', ...
                    transmitterType);
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
                    rethrow(ME);
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
                        isfield(transmitterScenarioConfig.Spectrum, 'ReceiverSampleRate') && ...
                        ~isempty(transmitterScenarioConfig.Spectrum.ReceiverSampleRate) && ...
                        isnumeric(transmitterScenarioConfig.Spectrum.ReceiverSampleRate) && ...
                        isscalar(transmitterScenarioConfig.Spectrum.ReceiverSampleRate) && ...
                        isfinite(transmitterScenarioConfig.Spectrum.ReceiverSampleRate) && ...
                        transmitterScenarioConfig.Spectrum.ReceiverSampleRate > 0
                    currentTransmitterBlock.TargetSampleRate = ...
                        transmitterScenarioConfig.Spectrum.ReceiverSampleRate;
                else
                    error('CSRD:TransmitFactory:MissingReceiverSampleRate', ...
                        ['transmitterScenarioConfig.Spectrum.ReceiverSampleRate ', ...
                         'is required. TRF output sample rate must be driven by ', ...
                         'the receiver observation plan, not the input waveform.']);
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
                rethrow(ME_step);
            end

        end

        function configureTransmitterBlock(obj, txBlock, typeConfig, txInfoThisTx, transmitterScenarioConfig)
            % Configure the transmitter block with parameters from typeConfig
            % 中文说明：configureTransmitterBlock 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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
            %CONFIGURENONLINEARITY Build a `comm.MemorylessNonlinearity` config.
            % 中文说明：configureNonlinearity 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            %   v0.4 deep refactor: the config produced here populates
            %   ONLY the property set the System object accepts for the
            %   chosen Method, per the official MATLAB documentation
            %   "Dependencies" section. Mirrors ReceiveFactory's
            %   configureNonlinearity contract end-to-end.

            if ~isstruct(nonlinField) || ~isfield(nonlinField, 'Methods') ...
                    || isempty(nonlinField.Methods)
                error('CSRD:TransmitFactory:NoNonlinearityMethods', ...
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
                    error('CSRD:TransmitFactory:UnknownNonlinearityMethod', ...
                        ['Unknown comm.MemorylessNonlinearity Method "%s". ' ...
                         'Supported: Cubic polynomial, Hyperbolic tangent, ' ...
                         'Saleh model, Ghorbani model, Modified Rapp model, ' ...
                         'Lookup table.'], selectedMethod);
            end

            nonlinConfig.ReferenceImpedance = referenceImpedance;
            obj.logger.debug('Configured nonlinearity method "%s"', selectedMethod);
        end

        function cfg = buildCubicPolynomialConfig(obj, src)
            % buildCubicPolynomialConfig - Production declaration in CSRD.
            % 中文说明：buildCubicPolynomialConfig 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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
            % buildHyperbolicTangentConfig - Production declaration in CSRD.
            % 中文说明：buildHyperbolicTangentConfig 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            cfg = struct();
            cfg.Method = 'Hyperbolic tangent';
            cfg.LinearGain      = obj.randomInRange(src.LinearGain(1),     src.LinearGain(2));
            cfg.IIP3            = obj.randomInRange(src.IIP3(1),           src.IIP3(2));
            cfg.AMPMConversion  = obj.randomInRange(src.AMPMConversion(1), src.AMPMConversion(2));
            cfg.PowerLowerLimit = obj.resolvePowerLimit(src.PowerLowerLimit, -40);
            cfg.PowerUpperLimit = obj.resolvePowerLimit(src.PowerUpperLimit,  Inf);
        end

        function cfg = buildSalehModelConfig(obj, src)
            % buildSalehModelConfig - Production declaration in CSRD.
            % 中文说明：buildSalehModelConfig 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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
            % buildGhorbaniModelConfig - Production declaration in CSRD.
            % 中文说明：buildGhorbaniModelConfig 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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
            % buildModifiedRappModelConfig - Production declaration in CSRD.
            % 中文说明：buildModifiedRappModelConfig 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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
            % buildLookupTableConfig - Production declaration in CSRD.
            % 中文说明：buildLookupTableConfig 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            cfg = struct();
            cfg.Method = 'Lookup table';
            if ~isfield(src, 'Table') || isempty(src.Table) || size(src.Table, 2) ~= 3
                error('CSRD:TransmitFactory:InvalidLookupTable', ...
                    ['Lookup table must be an Nx3 matrix [Pin_dBm, ' ...
                     'Pout_dBm, dPhi_deg]; the supplied src.Table is ' ...
                     'missing or has the wrong shape.']);
            end
            cfg.Table = src.Table;
        end

        function value = resolvePowerLimit(obj, raw, defaultValue)
            % resolvePowerLimit - Production declaration in CSRD.
            % 中文说明：resolvePowerLimit 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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
            error('CSRD:TransmitFactory:InvalidPowerLimit', ...
                'PowerLimit must be empty, scalar, [min max], or "Inf".');
        end

        function releaseImpl(obj)
            % releaseImpl - Production declaration in CSRD.
            % 中文说明：releaseImpl 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            obj.logger.debug('TransmitFactory releaseImpl called.');
            blockKeys = keys(obj.cachedTransmitterBlocks);

            for i = 1:length(blockKeys)
                blockKey = blockKeys{i};
                transmitterBlock = obj.cachedTransmitterBlocks(blockKey);

                if ~isempty(transmitterBlock) && ismethod(transmitterBlock, 'release')
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
            % resetImpl - Production declaration in CSRD.
            % 中文说明：resetImpl 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            obj.logger.debug('TransmitFactory resetImpl called.');
            blockKeys = keys(obj.cachedTransmitterBlocks);

            for i = 1:length(blockKeys)
                blockKey = blockKeys{i};
                transmitterBlock = obj.cachedTransmitterBlocks(blockKey);

                if ~isempty(transmitterBlock) && ismethod(transmitterBlock, 'reset')
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
            % 中文说明：getTransmitterTypes 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            excludeFields = {'LogDetails', 'Description', 'Types'};
            allFields = fieldnames(obj.factoryConfig);
            transmitterTypes = setdiff(allFields, excludeFields);
        end

        function value = randomInRange(~, minVal, maxVal)
            % Generate random value in specified range
            % 中文说明：randomInRange 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            if minVal == maxVal
                value = minVal;
            else
                value = minVal + (maxVal - minVal) * rand();
            end
        end

    end

end

function value = resolveField(s, flatName, nestedAlt)
    % resolveField - Production declaration in CSRD.
    % 中文说明：resolveField 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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
