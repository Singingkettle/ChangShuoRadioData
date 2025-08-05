function setupImpl(obj)
    % setupImpl - Initialize factories and validate configurations (ONE-TIME SETUP)
    %
    % This method performs complete simulation environment initialization including:
    % - Configuration validation for scenario and factory settings
    % - ONE-TIME factory instantiation based on configuration parameters
    % - Comprehensive logging system integration
    % - Error handling and validation for all components
    %
    % The method validates essential configurations, instantiates all required
    % factories ONCE, and prepares the engine for simulation execution.
    % After setup, stepImpl will call the step() methods of these instantiated factories.

    obj.logger.debug('ChangShuo Engine Core: setupImpl started.');

    % Validate essential configurations
    if isempty(obj.FactoryConfigs) || ~isstruct(obj.FactoryConfigs)
        error('ChangShuo:ConfigurationError', 'FactoryConfigs property must be a valid struct.');
    end

    % Validate scenario configuration is available in FactoryConfigs
    if ~isfield(obj.FactoryConfigs, 'Scenario') || ~isstruct(obj.FactoryConfigs.Scenario)
        error('ChangShuo:ConfigurationError', 'Scenario configuration must be available in FactoryConfigs.Scenario.');
    end

    obj.logger.debug('FactoryConfigs struct validated, scenario configuration available.');

    validateFactoryConfigs(obj); % Validates obj.Message, obj.Modulate etc. are structs with .handle and .Config (which is also a struct)

    % Instantiate factories (ONE-TIME initialization for entire simulation)
    factoryNames = {'Scenario', 'Message', 'Modulate', 'Transmit', 'Channel', 'Receive'};
    privateFactoryPropNames = {'pScenarioFactory', 'pMessageFactory', 'pModulationFactory', 'pTransmitFactory', 'pChannelFactory', 'pReceiveFactory'};

    for i = 1:length(factoryNames)
        factoryKey = factoryNames{i}; % e.g.,'Message'
        privatePropKey = privateFactoryPropNames{i}; % e.g.,'pMessageFactory'

        % obj.(factoryKey) is the struct like {handle: '...', Config: <struct>}
        factoryConfigStructFromRunner = obj.(factoryKey);

        obj.logger.debug('Setting up %s factory...', factoryKey);

        if isempty(factoryConfigStructFromRunner) || ~isfield(factoryConfigStructFromRunner, 'handle') || isempty(factoryConfigStructFromRunner.handle)
            obj.logger.warning('%s factory configuration is missing or handle is empty. Skipping instantiation.', factoryKey);
            obj.(privatePropKey) = [];
            continue;
        end

        factoryHandleStr = factoryConfigStructFromRunner.handle;
        % factoryOwnConfig is now the actual struct, not a path
        factoryOwnConfigStruct = [];

        if isfield(factoryConfigStructFromRunner, 'Config') && isstruct(factoryConfigStructFromRunner.Config)
            factoryOwnConfigStruct = factoryConfigStructFromRunner.Config;
            obj.logger.debug('%s factory has a .Config struct.', factoryKey);
        else
            obj.logger.debug('%s factory does not have an explicit .Config struct. Some factories might not require it or use defaults.', factoryKey);
        end

        obj.logger.debug('FACTORY_INSTANTIATION_POINT for [%s]: Handle=''%s''', factoryKey, factoryHandleStr);

        try
            obj.logger.debug('Instantiating %s factory using handle: %s', factoryKey, factoryHandleStr);

            constructorArgs = {};
            % If the factory has a Config property AND a config struct was provided for it
            if ~isempty(factoryOwnConfigStruct)
                % Pass the struct directly as 'Config' argument
                constructorArgs = [constructorArgs, {'Config', factoryOwnConfigStruct}];
                obj.logger.debug('Passing .Config struct to %s factory constructor.', factoryKey);
            end

            % Format constructor arguments for debugging
            try
                argDetails = '';

                for argIdx = 1:2:length(constructorArgs)

                    if argIdx < length(constructorArgs)
                        argName = constructorArgs{argIdx};
                        argValue = constructorArgs{argIdx + 1};

                        if isstruct(argValue)
                            argDetails = [argDetails, sprintf('%s=<struct>, ', argName)];
                        elseif ischar(argValue) || isstring(argValue)
                            argDetails = [argDetails, sprintf('%s=%s, ', argName, string(argValue))];
                        else
                            argDetails = [argDetails, sprintf('%s=<%s>, ', argName, class(argValue))];
                        end

                    end

                end

                obj.logger.debug('FACTORY_INSTANTIATION_POINT for [%s]: Constructor args: %s', factoryKey, argDetails);
            catch debugError
                % Silently continue if debug logging fails
                obj.logger.debug('FACTORY_INSTANTIATION_POINT for [%s]: Debug arg formatting failed', factoryKey);
            end

            obj.logger.debug('FACTORY_INSTANTIATION_POINT for [%s]: Final constructorArgs before feval: %d args provided', factoryKey, length(constructorArgs));

            if isempty(constructorArgs)
                obj.(privatePropKey) = feval(factoryHandleStr);
                obj.logger.debug('%s factory instantiated without explicit constructor args.', factoryKey);
            else
                obj.(privatePropKey) = feval(factoryHandleStr, constructorArgs{:});
                obj.logger.debug('%s factory instantiated with constructor args.', factoryKey);
            end

            obj.logger.debug('%s factory created successfully: %s', factoryKey, class(obj.(privatePropKey)));
        catch ME
            obj.logger.error('Failed to instantiate or configure %s factory (%s). Error: %s', factoryKey, factoryHandleStr, ME.message);
            obj.logger.error('Stack trace: %s', getReport(ME, 'extended', 'hyperlinks', 'off'));
            rethrow(ME);
        end

    end

    obj.logger.debug('ChangShuo Engine Core: setupImpl completed.');
end
