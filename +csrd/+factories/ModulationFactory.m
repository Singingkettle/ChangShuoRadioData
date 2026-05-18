classdef ModulationFactory < matlab.System
        % 中文说明：提供 CSRD 生产链路中的 ModulationFactory 实现。

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
            % ModulationFactory - Production declaration in CSRD.
            % 中文说明：ModulationFactory 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            setProperties(obj, nargin, varargin{:});
            obj.modulatorCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
            % Logger initialization now in setupImpl
        end

    end

    methods (Access = protected)

        function validateInputsImpl(~, ~, ~, ~, ~, ~, ~)
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
                error('ModulationFactory:ConfigError', 'Config property must be a valid struct.');
            end

            obj.factoryConfig = obj.Config; % The passed-in struct is the factory's config

            obj.logger = csrd.runtime.logger.GlobalLogManager.getLogger();

            obj.logger.debug('ModulationFactory setupImpl initializing with directly passed config struct.');

            % Optional: Pre-validate structure of factoryConfig (e.g., existence of .digital, .analog)
            if ~isfield(obj.factoryConfig, 'digital') && ~isfield(obj.factoryConfig, 'analog')
                error('CSRD:ModulationFactory:MissingRegistry', ...
                    'ModulationFactory config must contain top-level digital or analog registries.');
            end

            obj.logger.debug('ModulationFactory setupImpl complete.');
        end

        function outputSignalStruct = stepImpl(obj, inputData, frameId, txIdStr, segmentId, segmentModulationConfig, segmentPlacementConfig)
            % segmentModulationConfig: struct from scenario, e.g., Scenario.Transmitters.Segments.Modulation
            % 中文说明：stepImpl 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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
                error('CSRD:ModulationFactory:ModulatorTypeNotFound', ...
                    'Modulator TypeID "%s" not found in ModulationFactory config.', ...
                    modulatorTypeID);
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
                            adaptSegmentModulatorConfig(segmentModulationConfig, modulatorTypeID));
                    end

                    obj.logger.debug('Initial properties from factory config applied to %s.', class(currentModulator));

                catch ME_feval
                    obj.logger.error('Frame %d, Tx %s, Seg %d: Failed to feval modulator handle '' %s''. Error: %s', ...
                        frameId, txIdStr, segmentId, modulatorBlockHandle, ME_feval.message);
                    obj.logger.error('Check if class %s exists and is on the path.', modulatorBlockHandle);
                    rethrow(ME_feval);
                end

                obj.logger.debug('Modulator block %s instantiated.', class(currentModulator));
                obj.modulatorCache(cacheKey) = currentModulator; % Cache before setup
            end

            % --- Configure modulator properties based on segmentModulationConfig and segmentPlacementConfig ---
            obj.logger.debug('Configuring modulator block %s for segment...', class(currentModulator));

            % Determine SymbolRate (used to compute SampleRate below)
            if isfield(segmentModulationConfig, 'SymbolRate') && ...
                    ~isempty(segmentModulationConfig.SymbolRate) && ...
                    isnumeric(segmentModulationConfig.SymbolRate) && ...
                    isscalar(segmentModulationConfig.SymbolRate) && ...
                    isfinite(segmentModulationConfig.SymbolRate) && ...
                    segmentModulationConfig.SymbolRate > 0
                symbolRate = segmentModulationConfig.SymbolRate;
            else
                error('CSRD:Modulation:MissingSymbolRate', ...
                    ['segmentModulationConfig.SymbolRate must be a positive ', ...
                     'scalar. Execution sample rate cannot be inferred from ', ...
                     'TargetBandwidth inside ModulationFactory.']);
            end

            % Set SamplePerSymbol (scenario uses 'SamplesPerSymbol', modulator uses 'SamplePerSymbol')
            if isfield(segmentModulationConfig, 'SamplesPerSymbol') && isprop(currentModulator, 'SamplePerSymbol')
                currentModulator.SamplePerSymbol = segmentModulationConfig.SamplesPerSymbol;
            elseif isfield(segmentModulationConfig, 'SamplePerSymbol') && isprop(currentModulator, 'SamplePerSymbol')
                currentModulator.SamplePerSymbol = segmentModulationConfig.SamplePerSymbol;
            elseif isprop(currentModulator, 'SamplePerSymbol')
                error('CSRD:Modulation:MissingSamplesPerSymbol', ...
                    'segmentModulationConfig.SamplesPerSymbol is required for %s.', ...
                    class(currentModulator));
            end

            % Compute and set SampleRate = SymbolRate × SamplePerSymbol
            if ~isempty(symbolRate) && isprop(currentModulator, 'SampleRate')
                currentModulator.SampleRate = symbolRate * currentModulator.SamplePerSymbol;
                obj.logger.debug('Set SampleRate = %.2f Hz (SymbolRate=%.2f × SPS=%d)', ...
                    currentModulator.SampleRate, symbolRate, currentModulator.SamplePerSymbol);
            end

            % Set ModulationOrder from the scenario plan. Factory defaults
            % describe legal ranges, not execution facts.
            modulatorOrder = [];
            if isfield(segmentModulationConfig, 'Order')
                modulatorOrder = segmentModulationConfig.Order;
                obj.logger.debug('ModulationOrder from segmentModulationConfig: %d', modulatorOrder);
            end
            
            digitalTypes = {'PSK', 'OQPSK', 'QAM', 'APSK', 'DVBSAPSK', 'ASK', 'FSK', 'CPFSK', 'GFSK', 'GMSK', 'MSK', 'OOK', 'Mill88QAM'};
            if ismember(modulatorTypeID, digitalTypes) && (isempty(modulatorOrder) || modulatorOrder < 2)
                error('CSRD:Modulation:InvalidModulationOrder', ...
                    'Digital modulator %s requires segmentModulationConfig.Order >= 2.', ...
                    modulatorTypeID);
            end
            
            % Apply ModulatorOrder if we have a valid value
            % Note: Property is 'ModulatorOrder' (not 'ModulationOrder') in BaseModulator
            if ~isempty(modulatorOrder)
                if isprop(currentModulator, 'ModulatorOrder')
                    try
                        currentModulator.ModulatorOrder = modulatorOrder;
                        obj.logger.debug('Set ModulatorOrder to %d for %s', modulatorOrder, class(currentModulator));
                    catch ME_setOrder
                        error('CSRD:Modulation:ModulatorOrderAssignmentFailed', ...
                            'Failed to set ModulatorOrder on %s: %s', ...
                            class(currentModulator), ME_setOrder.message);
                    end
                elseif ismember(modulatorTypeID, digitalTypes)
                    error('CSRD:Modulation:MissingModulatorOrderProperty', ...
                        'Digital modulator %s does not expose ModulatorOrder.', ...
                        class(currentModulator));
                end
            end

            % NumTransmitAntennas might come from TxSite config, passed in segmentModulationConfig if needed by modulator
            if isfield(segmentModulationConfig, 'NumTransmitAntennas') && isprop(currentModulator, 'NumTransmitAntennas')
                currentModulator.NumTransmitAntennas = segmentModulationConfig.NumTransmitAntennas;
            elseif ~isfield(segmentModulationConfig, 'NumTransmitAntennas') && isprop(currentModulator, 'NumTransmitAntennas')
                error('CSRD:Modulation:MissingNumTransmitAntennas', ...
                    ['Segment modulation config must provide NumTransmitAntennas ', ...
                     'for %s. The execution layer must not default antenna ', ...
                     'count to 1.'], class(currentModulator));
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

            if isprop(currentModulator, 'ModulatorConfig')
                currentModulator.ModulatorConfig = mergeStructs( ...
                    currentModulator.ModulatorConfig, ...
                    adaptSegmentModulatorConfig(segmentModulationConfig, modulatorTypeID));
            end

            % Generic application of other parameters from segmentModulationConfig
            % This allows scenario to pass any other valid property for the chosen modulator block.
            scenarioFields = fieldnames(segmentModulationConfig);

            for i = 1:length(scenarioFields)
                fName = scenarioFields{i};
                % Avoid re-setting already handled specific props or the TypeID itself
                if ~ismember(fName, {'TypeID', 'SymbolRate', 'SamplePerSymbol', 'SamplesPerSymbol', 'Order', 'NumTransmitAntennas', 'RolloffFactor', 'BitsPerSymbol', 'Type', 'ModulatorConfig'})

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
                    error('CSRD:Modulation:MissingBandwidth', ...
                        ['Modulator %s did not output Bandwidth. ', ...
                         'Design TargetBandwidth must not be copied into ', ...
                         'Execution bandwidth.'], class(currentModulator));
                elseif isvector(outputSignalStruct.Bandwidth) && length(outputSignalStruct.Bandwidth) == 2
                    outputSignalStruct.Bandwidth = outputSignalStruct.Bandwidth(2) - outputSignalStruct.Bandwidth(1);
                elseif ~isscalar(outputSignalStruct.Bandwidth)
                    error('CSRD:Modulation:InvalidBandwidth', ...
                        'Modulator %s output Bandwidth in an unsupported shape.', ...
                        class(currentModulator));
                end
                if ~isfinite(outputSignalStruct.Bandwidth) || outputSignalStruct.Bandwidth <= 0
                    error('CSRD:Modulation:InvalidBandwidth', ...
                        'Modulator %s output non-positive/non-finite Bandwidth.', ...
                        class(currentModulator));
                end

                % --- Post-process: ensure SampleRate is present ---
                if ~isfield(outputSignalStruct, 'SampleRate') || isempty(outputSignalStruct.SampleRate) || ...
                        ~isnumeric(outputSignalStruct.SampleRate) || ...
                        ~isscalar(outputSignalStruct.SampleRate) || ...
                        ~isfinite(outputSignalStruct.SampleRate) || ...
                        outputSignalStruct.SampleRate <= 0
                    error('CSRD:Modulation:MissingSampleRate', ...
                        ['Modulator %s must output a positive scalar SampleRate. ', ...
                         'Execution SampleRate must not be derived after the fact.'], ...
                        class(currentModulator));
                end

                if isprop(currentModulator, 'NumTransmitAntennas')
                    if ~isfield(outputSignalStruct, 'NumTransmitAntennas') || ...
                            isempty(outputSignalStruct.NumTransmitAntennas) || ...
                            ~isnumeric(outputSignalStruct.NumTransmitAntennas) || ...
                            ~isscalar(outputSignalStruct.NumTransmitAntennas)
                        error('CSRD:Modulation:MissingNumTransmitAntennas', ...
                            'Modulator %s must output NumTransmitAntennas.', ...
                            class(currentModulator));
                    end
                    requestedAntennas = double(segmentModulationConfig.NumTransmitAntennas);
                    if double(outputSignalStruct.NumTransmitAntennas) ~= requestedAntennas
                        error('CSRD:Modulation:NumTransmitAntennasMismatch', ...
                            ['Modulator %s output NumTransmitAntennas=%g but ', ...
                             'planner requested %g.'], class(currentModulator), ...
                            double(outputSignalStruct.NumTransmitAntennas), ...
                            requestedAntennas);
                    end
                    outputSignalStruct.Signal = normalizeSignalAntennaShape( ...
                        outputSignalStruct.Signal, requestedAntennas, ...
                        class(currentModulator));
                    outputSignalStruct.SamplePerFrame = size(outputSignalStruct.Signal, 1);
                    outputSignalStruct.TimeDuration = ...
                        outputSignalStruct.SamplePerFrame / outputSignalStruct.SampleRate;
                end

                outputSignalStruct.ModulationTypeID = modulatorTypeID;

                obj.logger.debug('Frame %d, Tx %s, Seg %d: ModFactory OUT - ActualBW: %g Hz, ActualFs: %g Hz for %s', ...
                    frameId, txIdStr, segmentId, outputSignalStruct.Bandwidth, outputSignalStruct.SampleRate, class(currentModulator));

            catch ME_mod_step
                obj.logger.error('Frame %d, Tx %s, Seg %d: Error during step() of modulator %s. Error: %s', ...
                    frameId, txIdStr, segmentId, class(currentModulator), ME_mod_step.message);
                obj.logger.error('Modulator State at Error: %s', ...
                    jsonencode(summarizeModulatorForLog(currentModulator)));
                obj.logger.error('Stack: %s', getReport(ME_mod_step, 'extended', 'hyperlinks', 'off'));
                rethrow(ME_mod_step);
            end

        end

        function releaseImpl(obj)
            % releaseImpl - Production declaration in CSRD.
            % 中文说明：releaseImpl 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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
            % resetImpl - Production declaration in CSRD.
            % 中文说明：resetImpl 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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

function signal = normalizeSignalAntennaShape(signal, expectedAntennas, modulatorClass)
    % normalizeSignalAntennaShape - Enforce [samples x txAntennas].
    % 中文说明：调制器输出必须按“采样点 x 发射天线”组织，禁止把天线维误当时间维。
    if nargin < 3 || isempty(modulatorClass)
        modulatorClass = '<unknown>';
    end
    if isempty(signal) || ~isnumeric(signal)
        error('CSRD:Modulation:InvalidSignal', ...
            'Modulator %s output Signal must be a non-empty numeric array.', ...
            modulatorClass);
    end
    if ndims(signal) ~= 2
        error('CSRD:Modulation:InvalidSignalShape', ...
            ['Modulator %s output Signal must be a 2-D matrix in ', ...
             '[samples x txAntennas] shape. Got ndims=%d.'], ...
            modulatorClass, ndims(signal));
    end
    expectedAntennas = double(expectedAntennas);
    if ~isscalar(expectedAntennas) || ~isfinite(expectedAntennas) || ...
            expectedAntennas < 1 || expectedAntennas ~= round(expectedAntennas)
        error('CSRD:Modulation:InvalidNumTransmitAntennas', ...
            'Modulator %s expected antenna count must be a positive integer.', ...
            modulatorClass);
    end
    expectedAntennas = round(expectedAntennas);

    if size(signal, 2) == expectedAntennas
        return;
    end

    if expectedAntennas == 1 && isrow(signal)
        signal = signal(:);
        return;
    end

    if expectedAntennas > 1 && size(signal, 1) == expectedAntennas
        candidate = signal.';
        if size(candidate, 2) == expectedAntennas
            signal = candidate;
            return;
        end
    end

    signalSize = size(signal);
    error('CSRD:Modulation:SignalAntennaColumnMismatch', ...
        ['Modulator %s output Signal size [%d %d], but ', ...
         'NumTransmitAntennas=%d requires exactly %d columns. ', ...
         'Use [samples x txAntennas] throughout modulation/TRF/channel.'], ...
        modulatorClass, signalSize(1), signalSize(2), ...
        expectedAntennas, expectedAntennas);
end

function summary = summarizeModulatorForLog(modulator)
    % summarizeModulatorForLog - Production declaration in CSRD.
    % 中文说明：summarizeModulatorForLog 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    summary = struct('Class', class(modulator));
    props = {'ModulatorOrder', 'SampleRate', 'SamplePerSymbol', ...
        'NumTransmitAntennas', 'NumSymbols', 'NumDataSubcarriers', ...
        'ModulatorConfig'};
    for k = 1:numel(props)
        propName = props{k};
        if isprop(modulator, propName)
            try
                summary.(propName) = modulator.(propName);
            catch ME
                summary.(propName) = sprintf('<unavailable:%s>', ME.identifier);
            end
        end
    end
    summary = csrd.pipeline.annotation.sanitizeForJson(summary);
end

function adaptedConfig = adaptModulatorConfig(rawConfig, modulatorTypeID)
    % adaptModulatorConfig - Production declaration in CSRD.
    % 中文说明：adaptModulatorConfig 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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
    % adaptScenarioModulatorConfig - Production declaration in CSRD.
    % 中文说明：adaptScenarioModulatorConfig 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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

function adaptedConfig = adaptSegmentModulatorConfig(segmentModulationConfig, modulatorTypeID)
    % adaptSegmentModulatorConfig - Production declaration in CSRD.
    % 中文说明：adaptSegmentModulatorConfig 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    adaptedConfig = struct();
    if ~isstruct(segmentModulationConfig)
        return;
    end

    if isfield(segmentModulationConfig, 'ModulatorConfig') && ...
            isstruct(segmentModulationConfig.ModulatorConfig)
        adaptedConfig = mergeStructs(adaptedConfig, ...
            adaptModulatorConfig(segmentModulationConfig.ModulatorConfig, modulatorTypeID));
    end

    adaptedConfig = mergeStructs(adaptedConfig, ...
        adaptScenarioModulatorConfig(segmentModulationConfig, modulatorTypeID));
end

function cfg = ensurePulseShapeDefaults(cfg, modulatorTypeID)
    % ensurePulseShapeDefaults - Production declaration in CSRD.
    % 中文说明：ensurePulseShapeDefaults 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    pulseShapedTypes = {'PSK', 'OQPSK', 'QAM', 'Mill88QAM', ...
        'APSK', 'DVBSAPSK', 'ASK', 'OOK', 'PAM'};
    if ~ismember(char(string(modulatorTypeID)), pulseShapedTypes)
        return;
    end

    if ~isfield(cfg, 'beta') || isempty(cfg.beta)
        cfg.beta = 0.25;
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

    if strcmp(char(string(modulatorTypeID)), 'OQPSK')
        if ~isfield(cfg, 'SymbolMapping') || isempty(cfg.SymbolMapping)
            cfg.SymbolMapping = "Gray";
        end
        if ~isfield(cfg, 'PhaseOffset') || isempty(cfg.PhaseOffset)
            cfg.PhaseOffset = 0;
        end
    end
end

function merged = mergeStructs(baseStruct, overrideStruct)
    % mergeStructs - Production declaration in CSRD.
    % 中文说明：mergeStructs 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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
