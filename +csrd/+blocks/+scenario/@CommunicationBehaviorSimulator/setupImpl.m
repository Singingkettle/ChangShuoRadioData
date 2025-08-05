function setupImpl(obj)
    % setupImpl - Initialize communication behavior modeling systems
    %
    % Initializes the communication behavior simulator. Note that scenario-level
    % configurations (frequency allocation, modulation schemes) are initialized
    % on the first call to stepImpl to ensure entities are available.

    obj.logger = csrd.utils.logger.GlobalLogManager.getLogger();
    obj.logger.debug('CommunicationBehaviorSimulator setup starting...');

    % Initialize default configuration if not provided
    if isempty(obj.Config)
        obj.Config = getDefaultConfiguration(obj);
    end

    % Initialize core components
    obj.allocationHistory = containers.Map('KeyType', 'int32', 'ValueType', 'any');

    % Initialize transmission scheduling for frame-level control
    initializeTransmissionScheduler(obj);

    % Reset scenario initialization flag
    obj.scenarioInitialized = false;

    obj.logger.debug('CommunicationBehaviorSimulator setup completed');
end
