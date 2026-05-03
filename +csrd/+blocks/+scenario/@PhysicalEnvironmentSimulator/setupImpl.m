function setupImpl(obj)
    % setupImpl - Initialize physical environment and supporting systems
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 setupImpl 实现。
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

    % Initialize timeResolution from configuration
    if isfield(obj.Config, 'TimeResolution')
        obj.timeResolution = obj.Config.TimeResolution;
        obj.logger.debug('Time resolution set from config: %.3f seconds', obj.timeResolution);
    else
        error('CSRD:PhysicalEnvironment:MissingTimeResolution', ...
            'PhysicalEnvironmentSimulator.Config.TimeResolution is required.');
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
