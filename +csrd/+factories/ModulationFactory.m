classdef ModulationFactory < matlab.System

    properties
        % Config: Struct containing the configuration for modulation types.
        % Passed directly by ChangShuo, loaded from the master config script.
        % Expected structure: Config.digital.PSK.handle, Config.digital.PSK.Order etc.
        Config struct
    end

    properties (Access = private)
        logger
        factoryConfig % Stores obj.Config directly
        modulatorCache
    end

    methods

        function obj = ModulationFactory(varargin)
            setProperties(obj, nargin, varargin{:});
            obj.modulatorCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            % Logger initialization now in setupImpl
        end

    end

    methods (Access = protected)

        function validateInputsImpl(~, ~, ~, ~, ~, ~, ~)
        end

        function setupImpl(obj)

            if isempty(obj.Config) || ~isstruct(obj.Config)
                error('ModulationFactory:ConfigError', 'Config property must be a valid struct.');
            end

            obj.factoryConfig = obj.Config; % The passed-in struct is the factory's config

            obj.logger = csrd.utils.logger.GlobalLogManager.getLogger();

            obj.logger.debug('ModulationFactory setupImpl initializing with directly passed config struct.');

            % Optional: Pre-validate structure of factoryConfig (e.g., existence of .digital, .analog)
            if ~isfield(obj.factoryConfig, 'digital') && ~isfield(obj.factoryConfig, 'analog')
                obj.logger.warning('ModulationFactory config does not seem to have top-level ''digital'' or ''analog'' fields.');
            end

            obj.logger.debug('ModulationFactory setupImpl complete.');
        end

        function outputSignalStruct = stepImpl(obj, inputData, frameId, txIdStr, segmentId, segmentModulationConfig, segmentPlacementConfig)
            % segmentModulationConfig: struct from scenario, e.g., Scenario.Transmitters.Segments.Modulation
            % segmentPlacementConfig: struct from scenario, e.g., Scenario.Transmitters.Segments.Placement

            if ~isfield(segmentModulationConfig, 'TypeID') || isempty(segmentModulationConfig.TypeID)
                error('ModulationFactory:MissingTypeID', ...
                    'segmentModulationConfig.TypeID is missing or empty for Tx %s, Seg %d.', ...
                    txIdStr, segmentId);
            end
            modulatorTypeID = segmentModulationConfig.TypeID;
            obj.logger.debug('Frame %d, Tx %s, Seg %d: ModulationFactory called for TypeID: %s.', ...
                frameId, txIdStr, segmentId, modulatorTypeID);

            modulatorBlockHandle = '';
            modulatorDefaultBlockConfig = struct(); % From factoryConfig for the specific TypeID

            % --- Locate modulator handle and default config in obj.factoryConfig ---
            % The factoryConfig can have categories like 'digital', 'analog'.
            % The modulatorTypeID from scenario should directly match a key under these categories.
            foundModulatorEntry = false;
            categories = {'digital', 'analog'}; % Add more if other top-level categories exist

            for catIdx = 1:length(categories)
                categoryName = categories{catIdx};

                if isfield(obj.factoryConfig, categoryName) && isfield(obj.factoryConfig.(categoryName), modulatorTypeID)
                    modulatorEntry = obj.factoryConfig.(categoryName).(modulatorTypeID);

                    if isstruct(modulatorEntry) && isfield(modulatorEntry, 'handle')
                        modulatorBlockHandle = modulatorEntry.handle;
                        % Copy all other fields from modulatorEntry to modulatorDefaultBlockConfig
                        cfgFields = fieldnames(modulatorEntry);

                        for k = 1:length(cfgFields)

                            if ~strcmpi(cfgFields{k}, 'handle')
                                modulatorDefaultBlockConfig.(cfgFields{k}) = modulatorEntry.(cfgFields{k});
                            end

                        end

                        foundModulatorEntry = true;
                        obj.logger.debug('Found modulator entry under category ''%s''. Handle: %s', categoryName, modulatorBlockHandle);
                        break; % Found it
                    end

                end

            end

            if ~foundModulatorEntry
                % Fallback: Check if TypeID exists at the top level of factoryConfig (e.g. for custom types not under digital/analog)
                if isfield(obj.factoryConfig, modulatorTypeID)
                    modulatorEntry = obj.factoryConfig.(modulatorTypeID);

                    if isstruct(modulatorEntry) && isfield(modulatorEntry, 'handle')
                        modulatorBlockHandle = modulatorEntry.handle;
                        cfgFields = fieldnames(modulatorEntry);

                        for k = 1:length(cfgFields)

                            if ~strcmpi(cfgFields{k}, 'handle')
                                modulatorDefaultBlockConfig.(cfgFields{k}) = modulatorEntry.(cfgFields{k});
                            end

                        end

                        foundModulatorEntry = true;
                        obj.logger.debug('Found modulator entry at top level. Handle: %s', modulatorBlockHandle);
                    end

                end

            end

            if ~foundModulatorEntry
                obj.logger.error('Frame %d, Tx %s, Seg %d: Modulator TypeID ''%s'' not found in ModulationFactory config. Searched under digital, analog, and top-level.', ...
                    frameId, txIdStr, segmentId, modulatorTypeID);
                outputSignalStruct = struct('Error', 'ModulatorTypeNotFoundInFactoryConfig', 'OriginalData', inputData);
                return;
            end

            % Ensure handle is fully qualified (heuristic)
            if ~contains(modulatorBlockHandle, '.') && ~isempty(modulatorBlockHandle) && exist(['csrd.blocks.physical.modulate.', modulatorBlockHandle], 'class')
                modulatorBlockHandle = ['csrd.blocks.physical.modulate.', modulatorBlockHandle];
                obj.logger.debug('Auto-prefixed modulator handle to: %s', modulatorBlockHandle);
            elseif ~contains(modulatorBlockHandle, '.') && ~isempty(modulatorBlockHandle) && exist(['csrd.blocks.physical.modulate.digital.', modulatorBlockHandle], 'class')
                modulatorBlockHandle = ['csrd.blocks.physical.modulate.digital.', modulatorBlockHandle];
                obj.logger.debug('Auto-prefixed modulator handle to: %s', modulatorBlockHandle);
            elseif ~contains(modulatorBlockHandle, '.') && ~isempty(modulatorBlockHandle) && exist(['csrd.blocks.physical.modulate.analog.', modulatorBlockHandle], 'class')
                modulatorBlockHandle = ['csrd.blocks.physical.modulate.analog.', modulatorBlockHandle];
                obj.logger.debug('Auto-prefixed modulator handle to: %s', modulatorBlockHandle);
            end

            % --- Instantiate or get from cache ---
            % Cache key can be complex if block configs vary significantly per segment beyond settable props.
            % For now, using TypeID, Tx, Seg for uniqueness.
            cacheKey = sprintf('Modulator_%s_Tx%s_Seg%d', strrep(modulatorTypeID, '.', '_'), txIdStr, segmentId);

            if obj.modulatorCache.isKey(cacheKey)
                currentModulator = obj.modulatorCache(cacheKey);
                obj.logger.debug('Frame %d, Tx %s, Seg %d: Using cached modulator block: %s', frameId, txIdStr, segmentId, class(currentModulator));
            else
                obj.logger.debug('Frame %d, Tx %s, Seg %d: Creating new modulator block: %s', frameId, txIdStr, segmentId, modulatorBlockHandle);

                try
                    % Instantiate. Block-specific default parameters from factoryConfig (like default Order for PSK)
                    % are usually set via name-value pairs if the block supports them in constructor,
                    % or by setting properties after instantiation.
                    % For now, assume direct property setting after basic feval is the main path.
                    currentModulator = feval(modulatorBlockHandle);

                    % Apply defaults from factory config (e.g. default Order for PSK)
                    cfgFields = fieldnames(modulatorDefaultBlockConfig);

                    for k = 1:length(cfgFields)
                        propName = cfgFields{k};

                        if isprop(currentModulator, propName)
                            currentModulator.(propName) = modulatorDefaultBlockConfig.(propName);
                            obj.logger.debug('Set modulator prop ''%s'' from factory default config', propName);
                        elseif isprop(currentModulator, 'ModulatorConfig') && isstruct(currentModulator.ModulatorConfig) && isfield(currentModulator.ModulatorConfig, propName)
                            currentModulator.ModulatorConfig.(propName) = modulatorDefaultBlockConfig.(propName);
                            obj.logger.debug('Set modulator ModulatorConfig sub-prop ''%s'' from factory default config', propName);
                        elseif strcmp(propName, 'Config') && isprop(currentModulator, 'ModulatorConfig') && isstruct(modulatorDefaultBlockConfig.Config)
                            currentModulator.ModulatorConfig = mergeStructs( ...
                                currentModulator.ModulatorConfig, ...
                                adaptModulatorConfig(modulatorDefaultBlockConfig.Config, modulatorTypeID));
                            obj.logger.debug('Merged factory default Config into ModulatorConfig for %s.', class(currentModulator));
                        end

                    end

                    if isprop(currentModulator, 'ModulatorConfig')
                        currentModulator.ModulatorConfig = mergeStructs( ...
                            currentModulator.ModulatorConfig, ...
                            adaptScenarioModulatorConfig(segmentModulationConfig, modulatorTypeID));
                    end

                    obj.logger.debug('Initial properties from factory config applied to %s.', class(currentModulator));

                catch ME_feval
                    obj.logger.error('Frame %d, Tx %s, Seg %d: Failed to feval modulator handle '' %s''. Error: %s', ...
                        frameId, txIdStr, segmentId, modulatorBlockHandle, ME_feval.message);
                    obj.logger.error('Check if class %s exists and is on the path.', modulatorBlockHandle);
                    outputSignalStruct = struct('Error', 'ModulatorBlockFevalFailed', 'Handle', modulatorBlockHandle, 'OriginalData', inputData);
                    return;
                end

                obj.logger.debug('Modulator block %s instantiated.', class(currentModulator));
                obj.modulatorCache(cacheKey) = currentModulator; % Cache before setup
            end

            % --- Configure modulator properties based on segmentModulationConfig and segmentPlacementConfig ---
            obj.logger.debug('Configuring modulator block %s for segment...', class(currentModulator));

            % Determine SymbolRate (used to compute SampleRate below)
            symbolRate = [];
            if isfield(segmentModulationConfig, 'SymbolRate')
                symbolRate = segmentModulationConfig.SymbolRate;
            elseif isfield(segmentPlacementConfig, 'TargetBandwidth')
                rolloff = 0.35;
                if isfield(segmentModulationConfig, 'RolloffFactor')
                    rolloff = segmentModulationConfig.RolloffFactor;
                end
                symbolRate = segmentPlacementConfig.TargetBandwidth / (1 + rolloff);
                obj.logger.debug('Auto-calculated SymbolRate from TargetBandwidth: %.2f Hz', symbolRate);
            end

            % Set SamplePerSymbol (scenario uses 'SamplesPerSymbol', modulator uses 'SamplePerSymbol')
            if isfield(segmentModulationConfig, 'SamplesPerSymbol') && isprop(currentModulator, 'SamplePerSymbol')
                currentModulator.SamplePerSymbol = segmentModulationConfig.SamplesPerSymbol;
            elseif isfield(segmentModulationConfig, 'SamplePerSymbol') && isprop(currentModulator, 'SamplePerSymbol')
                currentModulator.SamplePerSymbol = segmentModulationConfig.SamplePerSymbol;
            end

            % Compute and set SampleRate = SymbolRate × SamplePerSymbol
            if ~isempty(symbolRate) && isprop(currentModulator, 'SampleRate')
                currentModulator.SampleRate = symbolRate * currentModulator.SamplePerSymbol;
                obj.logger.debug('Set SampleRate = %.2f Hz (SymbolRate=%.2f × SPS=%d)', ...
                    currentModulator.SampleRate, symbolRate, currentModulator.SamplePerSymbol);
            end

            % Set ModulationOrder with robust fallback
            % Priority: 1) segmentModulationConfig.Order, 2) modulatorDefaultBlockConfig.Order
            modulatorOrder = [];
            if isfield(segmentModulationConfig, 'Order')
                modulatorOrder = segmentModulationConfig.Order;
                obj.logger.debug('ModulationOrder from segmentModulationConfig: %d', modulatorOrder);
            elseif isfield(modulatorDefaultBlockConfig, 'Order')
                modOrders = modulatorDefaultBlockConfig.Order;
                if isscalar(modOrders)
                    modulatorOrder = modOrders;
                else
                    modulatorOrder = modOrders(randi(length(modOrders)));
                end
                obj.logger.debug('ModulationOrder from factory config defaults: %d', modulatorOrder);
            end
            
            % Ensure minimum order for digital modulations (PSK, QAM, FSK need >= 2)
            digitalTypes = {'PSK', 'OQPSK', 'QAM', 'APSK', 'DVBSAPSK', 'ASK', 'FSK', 'CPFSK', 'GFSK', 'GMSK', 'MSK', 'OOK', 'Mill88QAM'};
            if ismember(modulatorTypeID, digitalTypes) && (isempty(modulatorOrder) || modulatorOrder < 2)
                modulatorOrder = 2;  % Default minimum for digital modulations
                obj.logger.warning('ModulationOrder was < 2 for digital type %s, forcing to 2', modulatorTypeID);
            end
            
            % Apply ModulatorOrder if we have a valid value
            % Note: Property is 'ModulatorOrder' (not 'ModulationOrder') in BaseModulator
            if ~isempty(modulatorOrder)
                try
                    currentModulator.ModulatorOrder = modulatorOrder;
                    obj.logger.debug('Set ModulatorOrder to %d for %s', modulatorOrder, class(currentModulator));
                catch ME_setOrder
                    obj.logger.warning('Failed to set ModulatorOrder on %s: %s', class(currentModulator), ME_setOrder.message);
                end
            else
                obj.logger.warning('No ModulatorOrder value available for %s', modulatorTypeID);
            end

            % NumTransmitAntennas might come from TxSite config, passed in segmentModulationConfig if needed by modulator
            if isfield(segmentModulationConfig, 'NumTransmitAntennas') && isprop(currentModulator, 'NumTransmitAntennas')
                currentModulator.NumTransmitAntennas = segmentModulationConfig.NumTransmitAntennas;
            elseif ~isfield(segmentModulationConfig, 'NumTransmitAntennas') && isprop(currentModulator, 'NumTransmitAntennas')
                currentModulator.NumTransmitAntennas = 1; % Default if not specified in scenario segment
            end

            % TargetBandwidth from placement config (critical for some modulators)
            if isfield(segmentPlacementConfig, 'TargetBandwidth') && isprop(currentModulator, 'TargetBandwidth')
                currentModulator.TargetBandwidth = segmentPlacementConfig.TargetBandwidth;
                obj.logger.debug('Set TargetBandwidth: %g Hz from placement config.', currentModulator.TargetBandwidth);
            end

            if isfield(segmentPlacementConfig, 'TargetBandwidth')
                obj.logger.debug('Frame %d, Tx %s, Seg %d: ModFactory received TargetBandwidth: %g Hz from scenario for block %s.', ...
                    frameId, txIdStr, segmentId, segmentPlacementConfig.TargetBandwidth, class(currentModulator));
            end

            % Generic application of other parameters from segmentModulationConfig
            % This allows scenario to pass any other valid property for the chosen modulator block.
            scenarioFields = fieldnames(segmentModulationConfig);

            for i = 1:length(scenarioFields)
                fName = scenarioFields{i};
                % Avoid re-setting already handled specific props or the TypeID itself
                if ~ismember(fName, {'TypeID', 'SymbolRate', 'SamplePerSymbol', 'SamplesPerSymbol', 'Order', 'NumTransmitAntennas', 'RolloffFactor', 'BitsPerSymbol', 'Type'})

                    if isprop(currentModulator, fName)
                        currentModulator.(fName) = segmentModulationConfig.(fName);
                        obj.logger.debug('Set modulator prop ''%s'' from segmentModulationConfig.', fName);
                    elseif isprop(currentModulator, 'ModulatorConfig') && isstruct(currentModulator.ModulatorConfig) && isfield(currentModulator.ModulatorConfig, fName)
                        currentModulator.ModulatorConfig.(fName) = segmentModulationConfig.(fName);
                        obj.logger.debug('Set modulator ModulatorConfig sub-prop ''%s'' from segmentModulationConfig.', fName);
                    end

                end

            end

            % Setup is deferred to auto-setup when step() is called with struct input
            % BaseModulator.validateInputsImpl requires struct, so manual setup
            % with raw numeric data would fail validation

            try
                inputToBlock.data = inputData;

                outputSignalStruct = step(currentModulator, inputToBlock);
                obj.logger.debug('Frame %d, Tx %s, Seg %d: Modulation by %s successful.', ...
                    frameId, txIdStr, segmentId, class(currentModulator));

                % --- Post-process: normalize Bandwidth to scalar Hz value ---
                if ~isfield(outputSignalStruct, 'Bandwidth') || isempty(outputSignalStruct.Bandwidth)
                    obj.logger.warning('Modulator %s did not output Bandwidth. Attempting fallback.', class(currentModulator));
                    if isfield(segmentPlacementConfig, 'TargetBandwidth')
                        outputSignalStruct.Bandwidth = segmentPlacementConfig.TargetBandwidth;
                    elseif isprop(currentModulator, 'SymbolRate')
                        outputSignalStruct.Bandwidth = currentModulator.SymbolRate;
                    else
                        outputSignalStruct.Bandwidth = 0;
                    end
                elseif isvector(outputSignalStruct.Bandwidth) && length(outputSignalStruct.Bandwidth) == 2
                    outputSignalStruct.Bandwidth = outputSignalStruct.Bandwidth(2) - outputSignalStruct.Bandwidth(1);
                elseif ~isscalar(outputSignalStruct.Bandwidth)
                    obj.logger.warning('Modulator %s output Bandwidth in unexpected format. Using first element.', class(currentModulator));
                    outputSignalStruct.Bandwidth = outputSignalStruct.Bandwidth(1);
                end

                % --- Post-process: ensure SampleRate is present ---
                if ~isfield(outputSignalStruct, 'SampleRate') || isempty(outputSignalStruct.SampleRate)
                    obj.logger.warning('Modulator %s did not output SampleRate. Attempting fallback.', class(currentModulator));
                    if isprop(currentModulator, 'SampleRate')
                        outputSignalStruct.SampleRate = currentModulator.SampleRate;
                    elseif isprop(currentModulator, 'SymbolRate') && isprop(currentModulator, 'SamplePerSymbol')
                        outputSignalStruct.SampleRate = currentModulator.SymbolRate * currentModulator.SamplePerSymbol;
                    elseif outputSignalStruct.Bandwidth > 0
                        outputSignalStruct.SampleRate = 2 * outputSignalStruct.Bandwidth;
                    else
                        outputSignalStruct.SampleRate = 0;
                    end
                end

                outputSignalStruct.ModulationTypeID = modulatorTypeID;

                obj.logger.debug('Frame %d, Tx %s, Seg %d: ModFactory OUT - ActualBW: %g Hz, ActualFs: %g Hz for %s', ...
                    frameId, txIdStr, segmentId, outputSignalStruct.Bandwidth, outputSignalStruct.SampleRate, class(currentModulator));

            catch ME_mod_step
                obj.logger.error('Frame %d, Tx %s, Seg %d: Error during step() of modulator %s. Error: %s', ...
                    frameId, txIdStr, segmentId, class(currentModulator), ME_mod_step.message);
                obj.logger.error('Modulator State at Error: %s', jsonencode(currentModulator));
                obj.logger.error('Stack: %s', getReport(ME_mod_step, 'extended', 'hyperlinks', 'off'));
                outputSignalStruct = struct('Error', 'ModulatorBlockStepFailed', 'ModulatorClass', class(currentModulator), 'OriginalData', inputData);
            end

        end

        function releaseImpl(obj)
            obj.logger.debug('ModulationFactory releaseImpl called.');
            blockKeys = keys(obj.modulatorCache);

            for i = 1:length(blockKeys)
                block = obj.modulatorCache(blockKeys{i});

                if isa(block, 'matlab.System') && isLocked(block)
                    release(block);
                end

            end

            remove(obj.modulatorCache, keys(obj.modulatorCache));
            obj.logger.debug('All cached modulator blocks released.');
        end

        function resetImpl(obj)
            obj.logger.debug('ModulationFactory resetImpl called.');
            blockKeys = keys(obj.modulatorCache);

            for i = 1:length(blockKeys)
                block = obj.modulatorCache(blockKeys{i});

                if isa(block, 'matlab.System')
                    reset(block);
                end

            end

            obj.logger.debug('All cached modulator blocks reset.');
        end

    end

end

function adaptedConfig = adaptModulatorConfig(rawConfig, modulatorTypeID)
    adaptedConfig = struct();
    if ~isstruct(rawConfig)
        return;
    end

    adaptedConfig = rawConfig;

    if isfield(rawConfig, 'RolloffFactor') && ~isfield(adaptedConfig, 'beta')
        adaptedConfig.beta = rawConfig.RolloffFactor;
    end

    if isfield(rawConfig, 'FilterSpanInSymbols') && ~isfield(adaptedConfig, 'span')
        adaptedConfig.span = rawConfig.FilterSpanInSymbols;
    end

    adaptedConfig = ensurePulseShapeDefaults(adaptedConfig, modulatorTypeID);
end

function adaptedConfig = adaptScenarioModulatorConfig(segmentModulationConfig, modulatorTypeID)
    adaptedConfig = struct();
    if ~isstruct(segmentModulationConfig)
        return;
    end

    if isfield(segmentModulationConfig, 'RolloffFactor')
        adaptedConfig.beta = segmentModulationConfig.RolloffFactor;
    end

    if isfield(segmentModulationConfig, 'FilterSpanInSymbols')
        adaptedConfig.span = segmentModulationConfig.FilterSpanInSymbols;
    end

    adaptedConfig = ensurePulseShapeDefaults(adaptedConfig, modulatorTypeID);
end

function cfg = ensurePulseShapeDefaults(cfg, modulatorTypeID)
    pulseShapedTypes = {'PSK', 'QAM', 'Mill88QAM', 'ASK', 'OOK', 'PAM'};
    if ~ismember(char(string(modulatorTypeID)), pulseShapedTypes)
        return;
    end

    if ~isfield(cfg, 'span') || isempty(cfg.span)
        cfg.span = 10;
    end

    if any(strcmp(char(string(modulatorTypeID)), {'PSK', 'QAM', 'Mill88QAM'})) && ...
            (~isfield(cfg, 'SymbolOrder') || isempty(cfg.SymbolOrder))
        cfg.SymbolOrder = "gray";
    end

    if strcmp(char(string(modulatorTypeID)), 'PSK')
        if ~isfield(cfg, 'Differential') || isempty(cfg.Differential)
            cfg.Differential = false;
        end
        if ~isfield(cfg, 'PhaseOffset') || isempty(cfg.PhaseOffset)
            cfg.PhaseOffset = 0;
        end
    end
end

function merged = mergeStructs(baseStruct, overrideStruct)
    if ~isstruct(baseStruct) || isempty(fieldnames(baseStruct))
        if isstruct(overrideStruct)
            merged = overrideStruct;
        else
            merged = struct();
        end
        return;
    end

    merged = baseStruct;
    if ~isstruct(overrideStruct)
        return;
    end

    overrideFields = fieldnames(overrideStruct);
    for idx = 1:numel(overrideFields)
        fieldName = overrideFields{idx};
        merged.(fieldName) = overrideStruct.(fieldName);
    end
end
