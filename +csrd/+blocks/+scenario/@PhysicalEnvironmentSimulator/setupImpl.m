function setupImpl(obj)
    % setupImpl - Initialize physical environment and supporting systems
    %
    % Initializes the complete physical environment simulation including
    % geographical mapping, entity registry, mobility models, and
    % environmental factors for realistic scenario modeling.

    obj.logger = csrd.utils.logger.GlobalLogManager.getLogger();
    obj.logger.debug('PhysicalEnvironmentSimulator setup starting...');

    % Initialize default configuration if not provided
    if isempty(obj.Config)
        obj.Config = getDefaultConfiguration(obj);
    end

    % Initialize timeResolution from configuration
    if isfield(obj.Config, 'TimeResolution')
        obj.timeResolution = obj.Config.TimeResolution;
        obj.logger.debug('Time resolution set from config: %.3f seconds', obj.timeResolution);
    else
        obj.timeResolution = 0.1; % Default fallback
        obj.logger.debug('Using default time resolution: %.3f seconds', obj.timeResolution);
    end

    % Initialize core components
    obj.entityRegistry = containers.Map('KeyType', 'char', 'ValueType', 'any');
    obj.mobilityModels = containers.Map('KeyType', 'char', 'ValueType', 'any');
    obj.frameHistory = containers.Map('KeyType', 'int32', 'ValueType', 'any');
    obj.stateHistory = {}; % Initialize state history

    % Initialize geographical mapping based on configuration
    initializeMapFromConfig(obj);

    % Initialize environmental factors
    initializeEnvironment(obj);

    % Initialize mobility models
    initializeMobilityModels(obj);

    obj.logger.debug('PhysicalEnvironmentSimulator setup completed');
end
