function setupImpl(obj)
    % setupImpl - Initialize physical environment and supporting systems
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    % Initializes the complete physical environment simulation including
    % geographical mapping, entity registry, mobility models, and
    % environmental factors for realistic scenario modeling.

    obj.logger = csrd.runtime.logger.GlobalLogManager.getLogger();
    obj.logger.debug('PhysicalEnvironmentSimulator setup starting...');

    % Initialize default configuration if not provided
    if isempty(obj.Config)
        obj.Config = getDefaultConfiguration(obj);
    end

    % Initialize timeResolution from the scenario frame contract.
    if ~isfield(obj.Config, 'TimeResolution') || isempty(obj.Config.TimeResolution)
        error('CSRD:PhysicalEnvironment:MissingTimeResolution', ...
            'PhysicalEnvironmentSimulator.Config.TimeResolution is required.');
    end
    obj.timeResolution = double(obj.Config.TimeResolution);
    if ~isnumeric(obj.timeResolution) || ~isscalar(obj.timeResolution) || ...
            ~isfinite(obj.timeResolution) || obj.timeResolution <= 0
        error('CSRD:PhysicalEnvironment:InvalidTimeResolution', ...
            'PhysicalEnvironmentSimulator.Config.TimeResolution must be a positive finite scalar seconds.');
    end
    obj.logger.debug('Time resolution set from frame contract: %.9g seconds', obj.timeResolution);

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
