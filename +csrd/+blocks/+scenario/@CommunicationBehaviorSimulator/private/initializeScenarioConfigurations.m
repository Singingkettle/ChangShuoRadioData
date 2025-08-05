function initializeScenarioConfigurations(obj, frameId, entities, factoryConfigs)
    % initializeScenarioConfigurations - Initialize fixed scenario-level configurations
    %
    % This method sets up all the communication parameters that remain fixed
    % throughout the entire scenario, including frequency allocations, modulation
    % schemes, power levels, and basic transmission parameters.

    % Separate transmitters and receivers
    [transmitters, receivers] = separateEntitiesByType(obj, entities);

    obj.logger.debug('Scenario initialization: Processing %d transmitters and %d receivers', ...
        length(transmitters), length(receivers));

    % Generate fixed receiver configurations for the scenario
    obj.scenarioRxConfigs = generateScenarioReceiverConfigurations(obj, transmitters, receivers, factoryConfigs);

    % Generate fixed transmitter configurations for the scenario
    [obj.scenarioTxConfigs, obj.scenarioGlobalLayout] = generateScenarioTransmitterConfigurations( ...
        obj, transmitters, obj.scenarioRxConfigs, factoryConfigs);

    obj.logger.debug('Scenario initialization completed: %d TX configs, %d RX configs', ...
        length(obj.scenarioTxConfigs), length(obj.scenarioRxConfigs));
end
