classdef ChannelFactory < matlab.System

    properties
        % Config: Struct containing the configuration for channel models.
        % Passed directly by ChangShuo, loaded from the master config script.
        % Expected structure: Config.ChannelModels.ModelName.handle, Config.ChannelModels.ModelName.Config
        Config struct

        % TxInfos & RxInfos are passed to stepImpl as needed for specific channel models like RayTracing
        % that require transmitter/receiver locations.
    end

    properties (Access = private)
        logger
        factoryConfig % Stores obj.Config directly
        % For statistical channels, a single cached block might be used if parameters are reconfigurable per Tx/Rx pair.
        % For RayTracing, likely one main block is cached.
        % We might cache [TxIdx, RxIdx] specific channel links if statistical models are not easily reconfigured.
        % For now, simple cache for selected model type.
        cachedChannelBlock % Can store one main block or a map if more complex caching needed.
        selectedChannelModelName % Name of the model selected at setup (e.g.,"AWGN", "Rayleigh")
        selectedChannelBlockHandle % Handle of the selected model
        selectedChannelDefaultConfig % Default config struct for the selected model
        isRayTracingSelected = false;
    end

    methods

        function obj = ChannelFactory(varargin)
            setProperties(obj, nargin, varargin{:});
            % Logger initialization now in setupImpl
            % Cache initialization depends on strategy, could be a simple property or a map.
        end

    end

    methods (Access = protected)

        function setupImpl(obj)

            if isempty(obj.Config) || ~isstruct(obj.Config) || ~isfield(obj.Config, 'ChannelModels')
                error('ChannelFactory:ConfigError', 'Config property must be a valid struct with a ChannelModels field.');
            end

            obj.factoryConfig = obj.Config;

            obj.logger = csrd.utils.logger.GlobalLogManager.getLogger();

            obj.logger.debug('ChannelFactory setupImpl initializing with directly passed config struct.');

            modelNames = fieldnames(obj.factoryConfig.ChannelModels);

            if isempty(modelNames)
                error('ChannelFactory:ConfigError', 'No channel models defined under Config.ChannelModels.');
            end

            % Channel Model Selection: For now, pick the first defined model.
            % This could be made more sophisticated (e.g., driven by scenario or weighted random from factoryConfig).
            obj.selectedChannelModelName = modelNames{1};
            obj.logger.debug('Selected channel model for this factory instance: %s', obj.selectedChannelModelName);

            selectedModelEntry = obj.factoryConfig.ChannelModels.(obj.selectedChannelModelName);

            if ~isfield(selectedModelEntry, 'handle') || isempty(selectedModelEntry.handle)
                error('ChannelFactory:ConfigError', 'Channel model ''%s'' is missing a handle.', obj.selectedChannelModelName);
            end

            obj.selectedChannelBlockHandle = selectedModelEntry.handle;
            obj.selectedChannelDefaultConfig = struct();

            if isfield(selectedModelEntry, 'Config') && isstruct(selectedModelEntry.Config)
                obj.selectedChannelDefaultConfig = selectedModelEntry.Config;
            end

            obj.isRayTracingSelected = contains(obj.selectedChannelBlockHandle, 'RayTracing', 'IgnoreCase', true);
            obj.logger.debug('RayTracing selected: %d', obj.isRayTracingSelected);

            % Instantiate the selected channel model
            try
                obj.logger.debug('Instantiating channel block: %s for selected model %s', obj.selectedChannelBlockHandle, obj.selectedChannelModelName);
                constructorArgs = {};
                cfgFields = fieldnames(obj.selectedChannelDefaultConfig);

                for k = 1:length(cfgFields)
                    constructorArgs{end + 1} = cfgFields{k};
                    constructorArgs{end + 1} = obj.selectedChannelDefaultConfig.(cfgFields{k});
                end

                obj.cachedChannelBlock = feval(obj.selectedChannelBlockHandle, constructorArgs{:});

                if isa(obj.cachedChannelBlock, 'matlab.System')
                    % RayTracing setup might require Tx/Rx info not available to factory setup.
                    % The block itself should handle deferred setup or require this info at instantiation if critical.
                    obj.logger.debug('Calling setup() on the channel block %s.', class(obj.cachedChannelBlock));

                    try
                        setup(obj.cachedChannelBlock);
                    catch ME_setup
                        obj.logger.error('Initial setup of channel block %s failed: %s. Block might need specific inputs for setup.', class(obj.cachedChannelBlock), ME_setup.message);
                        % Depending on block design, this might not be fatal if setup is called again in step with inputs.
                    end

                end

                obj.logger.debug('Channel block %s instantiated.', class(obj.cachedChannelBlock));
            catch ME_instantiate
                obj.logger.error('Failed to instantiate channel block ''%s''. Error: %s', obj.selectedChannelBlockHandle, ME_instantiate.message);
                rethrow(ME_instantiate);
            end

            obj.logger.debug('ChannelFactory setupImpl complete.');
        end

        function receivedSignalStruct = stepImpl(obj, inputSignalStruct, frameId, txSpecificInfo, rxSpecificInfo, channelLinkSpecificInfo)
            % inputSignalStruct: from TransmitFactory (one per transmitter)
            % txSpecificInfo: struct with info about the current transmitter (e.g., SiteConfig, ID)
            % rxSpecificInfo: struct with info about the current receiver (e.g., SiteConfig, ID)
            % channelLinkSpecificInfo: struct with parameters for this specific Tx-Rx link (e.g., SNR for AWGN)

            txIdStr = string(txSpecificInfo.ID);
            rxIdStr = string(rxSpecificInfo.ID);

            obj.logger.debug('Frame %d, Tx %s to Rx %s: ChannelFactory step for model %s.', ...
                frameId, txIdStr, rxIdStr, obj.selectedChannelModelName);

            if isempty(obj.cachedChannelBlock)
                obj.logger.error('Frame %d, Tx %s to Rx %s: Channel block was not instantiated during setup. Cannot process signal.', frameId, txIdStr, rxIdStr);
                receivedSignalStruct = inputSignalStruct; % Pass through with error
                if isfield(inputSignalStruct, 'Waveform'), receivedSignalStruct.Waveform = inputSignalStruct.Waveform; else, receivedSignalStruct.Waveform = []; end
                receivedSignalStruct.Error = 'ChannelBlockNotInstantiated';
                return;
            end

            currentChannelBlock = obj.cachedChannelBlock;

            % --- Configure the cached channel block with link-specific parameters ---
            if ~obj.isRayTracingSelected
                obj.logger.debug('Configuring statistical channel model %s for link Tx %s to Rx %s', class(currentChannelBlock), txIdStr, rxIdStr);
                % Apply link-specific parameters from channelLinkSpecificInfo
                fieldsToSet = fieldnames(channelLinkSpecificInfo);

                for k = 1:length(fieldsToSet)
                    propName = fieldsToSet{k};

                    if isprop(currentChannelBlock, propName)

                        try
                            currentChannelBlock.(propName) = channelLinkSpecificInfo.(propName);
                            obj.logger.debug('Set channel prop '' %s'' from channelLinkSpecificInfo.', propName);
                        catch ME_setprop_link
                            obj.logger.warning('Could not set channel prop '' %s'' from link info. Error: %s', propName, ME_setprop_link.message);
                        end

                    end

                end

                % Ensure NumTransmitAntennas and NumReceiveAntennas are set from Tx/Rx specific info
                if isprop(currentChannelBlock, 'NumTransmitAntennas') && isfield(txSpecificInfo, 'Site') && isfield(txSpecificInfo.Site, 'NumAntennas')
                    currentChannelBlock.NumTransmitAntennas = txSpecificInfo.Site.NumAntennas;
                end

                if isprop(currentChannelBlock, 'NumReceiveAntennas') && isfield(rxSpecificInfo, 'Site') && isfield(rxSpecificInfo.Site, 'NumAntennas')
                    currentChannelBlock.NumReceiveAntennas = rxSpecificInfo.Site.NumAntennas;
                end

                % Set a unique seed for stochastic channels if the property exists
                if isprop(currentChannelBlock, 'Seed')
                    % Create a somewhat unique seed based on frame, tx, rx IDs
                    currentChannelBlock.Seed = mod(frameId * 10000 + str2double(txIdStr) * 100 + str2double(rxIdStr), 2 ^ 32 - 1);
                    obj.logger.debug('Set channel Seed: %d', currentChannelBlock.Seed);
                end

            else % For RayTracing
                obj.logger.debug('Using pre-configured RayTracing block. Ensure it handles Tx %s to Rx %s internally or via step inputs.', txIdStr, rxIdStr);
                % RayTracing blocks usually take Tx/Rx Site information during their main setup,
                % or their step method is designed to accept specific Tx/Rx identifiers/locations to select the path.
                % If txSpecificInfo/rxSpecificInfo need to be passed to Raytracer's step, that's handled below.
            end

            % --- Call the channel block's step method ---
            obj.logger.debug('Frame %d, Tx %s to Rx %s: Invoking step method of channel block %s', ...
                frameId, string(txSpecificInfo.ID), string(rxSpecificInfo.ID), class(obj.cachedChannelBlock));

            try

                if obj.isRayTracingSelected
                    % RayTracing.m step might need (obj, inputWaveform, txSite, rxSite)
                    % This needs to match the actual RayTracing block's step signature.
                    % Assuming inputSignalStruct contains .Waveform, and Site info from tx/rxSpecificInfo.
                    if ~isfield(inputSignalStruct, 'Waveform')
                        error('ChannelFactory:InputError', 'RayTracing inputSignalStruct missing Waveform field.');
                    end

                    if ~isfield(txSpecificInfo, 'Site') || ~isfield(rxSpecificInfo, 'Site')
                        error('ChannelFactory:InputError', 'RayTracing step needs Tx/Rx Site info from txSpecificInfo/rxSpecificInfo.');
                    end

                    outputWaveform = step(currentChannelBlock, inputSignalStruct.Waveform, txSpecificInfo.Site, rxSpecificInfo.Site);
                    receivedSignalStruct = inputSignalStruct; % Copy metadata
                    receivedSignalStruct.Waveform = outputWaveform; % Replace waveform
                else
                    % Statistical channels (e.g., AWGN, MIMO from comms toolbox) often take just the waveform.
                    if ~isfield(inputSignalStruct, 'Waveform')
                        error('ChannelFactory:InputError', 'Statistical channel inputSignalStruct missing Waveform field.');
                    end

                    outputWaveform = step(currentChannelBlock, inputSignalStruct.Waveform);
                    receivedSignalStruct = inputSignalStruct; % Start by copying all fields
                    receivedSignalStruct.Waveform = outputWaveform; % Update the waveform

                    % Some blocks (like comm.AWGNChannel) might output a struct if input is a struct.
                    % If outputWaveform is a struct itself, merge it carefully.
                    if isstruct(outputWaveform) && isfield(outputWaveform, 'Waveform')
                        receivedSignalStruct.Waveform = outputWaveform.Waveform;
                        % copy other fields from outputWaveform if any
                        additionalFields = fieldnames(outputWaveform);

                        for f = 1:length(additionalFields)

                            if ~strcmpi(additionalFields{f}, 'Waveform')
                                receivedSignalStruct.(additionalFields{f}) = outputWaveform.(additionalFields{f});
                            end

                        end

                    elseif isstruct(outputWaveform) % if it's a struct but not with .Waveform, this is unexpected
                        obj.logger.warning('Statistical channel output was a struct without .Waveform. Overwriting with this struct.');
                        receivedSignalStruct = outputWaveform; % This might lose original metadata

                        if ~isfield(receivedSignalStruct, 'Waveform') % Ensure Waveform field exists

                            if isfield(receivedSignalStruct, 'Signal') % Common alternative name
                                receivedSignalStruct.Waveform = receivedSignalStruct.Signal;
                                receivedSignalStruct = rmfield(receivedSignalStruct, 'Signal');
                            else
                                obj.logger.error('Channel output struct does not contain .Waveform or .Signal field.');
                                % Fallback or error based on desired behavior
                            end

                        end

                    end

                end

                obj.logger.debug('Frame %d, Tx %s to Rx %s: Channel processing by %s successful.', ...
                    frameId, txIdStr, rxIdStr, class(currentChannelBlock));
            catch ME_step
                obj.logger.error('Frame %d, Tx %s to Rx %s: Error during step of channel block %s. Error: %s', ...
                    frameId, txIdStr, rxIdStr, class(currentChannelBlock), ME_step.message);
                obj.logger.error('Stack: %s', getReport(ME_step, 'extended', 'hyperlinks', 'off'));
                receivedSignalStruct = inputSignalStruct;
                if isfield(inputSignalStruct, 'Waveform'), receivedSignalStruct.Waveform = inputSignalStruct.Waveform; else, receivedSignalStruct.Waveform = []; end
                receivedSignalStruct.Error = 'ChannelBlockStepFailed';
            end

        end

        function releaseImpl(obj)
            obj.logger.debug('ChannelFactory releaseImpl called.');

            if ~isempty(obj.cachedChannelBlock) && isa(obj.cachedChannelBlock, 'matlab.System') && islocked(obj.cachedChannelBlock)
                release(obj.cachedChannelBlock);
            end

            obj.cachedChannelBlock = [];
            obj.logger.debug('Cached channel block released.');
        end

        function resetImpl(obj)
            obj.logger.debug('ChannelFactory resetImpl called.');

            if ~isempty(obj.cachedChannelBlock) && isa(obj.cachedChannelBlock, 'matlab.System')
                reset(obj.cachedChannelBlock);
            end

            obj.logger.debug('Cached channel block reset.');
        end

    end

end
