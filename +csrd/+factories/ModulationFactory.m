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

            modulatorTypeID = segmentModulationConfig.TypeID; % e.g.,"PSK", "QAM", "FM"
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
                        end

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

            % Specific properties (prioritize scenario's segmentModulationConfig)
            if isfield(segmentModulationConfig, 'SymbolRate') && isprop(currentModulator, 'SymbolRate')
                currentModulator.SymbolRate = segmentModulationConfig.SymbolRate;
            end

            if isfield(segmentModulationConfig, 'SamplePerSymbol') && isprop(currentModulator, 'SamplePerSymbol')
                currentModulator.SamplePerSymbol = segmentModulationConfig.SamplePerSymbol;
            end

            if isfield(segmentModulationConfig, 'Order') && isprop(currentModulator, 'ModulationOrder')
                currentModulator.ModulationOrder = segmentModulationConfig.Order;
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
                if ~ismember(fName, {'TypeID', 'SymbolRate', 'SamplePerSymbol', 'Order', 'NumTransmitAntennas'})

                    if isprop(currentModulator, fName)
                        currentModulator.(fName) = segmentModulationConfig.(fName);
                        obj.logger.debug('Set modulator prop ''%s'' from segmentModulationConfig.', fName);
                    elseif isprop(currentModulator, 'ModulatorConfig') && isstruct(currentModulator.ModulatorConfig) && isfield(currentModulator.ModulatorConfig, fName)
                        currentModulator.ModulatorConfig.(fName) = segmentModulationConfig.(fName);
                        obj.logger.debug('Set modulator ModulatorConfig sub-prop ''%s'' from segmentModulationConfig.', fName);
                    end

                end

            end

            % --- Final setup and step ---
            if isa(currentModulator, 'matlab.System') && ~isLocked(currentModulator) % Check if setup was already called

                try
                    setup(currentModulator, inputData); % Some modulators might need input spec for setup
                    obj.logger.debug('Called setup() on modulator %s.', class(currentModulator));
                catch ME_setup
                    obj.logger.warning('Could not call setup(block, inputData) on modulator %s. Error: %s. Trying setup(block) if applicable.', class(currentModulator), ME_setup.message);

                    try
                        setup(currentModulator);
                        obj.logger.debug('Called setup() on modulator %s (no args).', class(currentModulator));
                    catch ME_setup_noargs
                        obj.logger.warning('Could not call setup() on modulator %s (no args). Error: %s. Block may not require explicit setup or uses auto-setup.', class(currentModulator), ME_setup_noargs.message);
                    end

                end

            end

            try
                % Prepare input for modulator block (assuming it expects a struct with a .data field)
                inputToBlock.data = inputData;
                % Pass other necessary info if the block expects it directly in the input struct
                % e.g., inputToBlock.SampleRate = calculated_input_sample_rate_if_needed_by_block;

                outputSignalStruct = step(currentModulator, inputToBlock);
                obj.logger.debug('Frame %d, Tx %s, Seg %d: Modulation by %s successful.', ...
                    frameId, txIdStr, segmentId, class(currentModulator));

                % --- Post-process and verify outputs (Bandwidth, SampleRate) ---
                if ~isfield(outputSignalStruct, 'Bandwidth') || isempty(outputSignalStruct.Bandwidth)
                    obj.logger.warning('Modulator %s did not output Bandwidth. Attempting fallback.', class(currentModulator));

                    if isfield(segmentPlacementConfig, 'TargetBandwidth')
                        outputSignalStruct.Bandwidth = segmentPlacementConfig.TargetBandwidth;
                    elseif isprop(currentModulator, 'SymbolRate'), outputSignalStruct.Bandwidth = currentModulator.SymbolRate;
                    else , outputSignalStruct.Bandwidth = 0; end
                    elseif isvector(outputSignalStruct.Bandwidth) && length(outputSignalStruct.Bandwidth) == 2 % [min_offset, max_offset]
                        outputSignalStruct.Bandwidth = outputSignalStruct.Bandwidth(2) - outputSignalStruct.Bandwidth(1);
                    elseif ~isscalar(outputSignalStruct.Bandwidth)
                        obj.logger.warning('Modulator %s output Bandwidth in unexpected format. Using first element.', class(currentModulator));
                        outputSignalStruct.Bandwidth = outputSignalStruct.Bandwidth(1);
                    end

                    if ~isfield(outputSignalStruct, 'SampleRate') || isempty(outputSignalStruct.SampleRate)
                        obj.logger.warning('Modulator %s did not output SampleRate. Attempting fallback.', class(currentModulator));

                        if isprop(currentModulator, 'SampleRate'), outputSignalStruct.SampleRate = currentModulator.SampleRate;
                        elseif isprop(currentModulator, 'SymbolRate') && isprop(currentModulator, 'SamplePerSymbol')
                            outputSignalStruct.SampleRate = currentModulator.SymbolRate * currentModulator.SamplePerSymbol;
                        elseif outputSignalStruct.Bandwidth > 0, outputSignalStruct.SampleRate = 2 * outputSignalStruct.Bandwidth; % Nyquist guess
                        else , outputSignalStruct.SampleRate = 0; end
                        end

                        outputSignalStruct.ModulationTypeID = modulatorTypeID; % Tag with TypeID for clarity downstream

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

                        if isa(block, 'matlab.System') && islocked(block)
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
