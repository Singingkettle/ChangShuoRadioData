function entities = initializeScenarioConfigurations(obj, entities)
    % initializeScenarioConfigurations - Initialize fixed scenario-level configurations
    %
    % This method sets up all the communication parameters that remain fixed
    % throughout the entire scenario (temporal properties):
    %   - Frequency allocations for each transmitter
    %   - Bandwidth assignments
    %   - Modulation scheme selections
    %   - Transmission pattern definitions
    %
    % DESIGN PRINCIPLE:
    %   Uses obj.Config (set during construction from scenario_factory.m).
    %   Does NOT require passing config as parameter since it's static.
    %   Type selection uses lists defined in obj.Config.
    %   Implementation details are deferred to respective factories.
    %
    % Input Arguments:
    %   entities - Entity references from PhysicalEnvironmentSimulator

    % Separate transmitters and receivers
    [transmitters, receivers] = separateEntitiesByType(obj, entities);

    obj.logger.debug('Scenario initialization: Processing %d transmitters and %d receivers', ...
        length(transmitters), length(receivers));

    % Generate fixed receiver configurations using UNIFIED config
    obj.scenarioRxConfigs = generateScenarioReceiverConfigurations(obj, receivers);

    % Generate fixed transmitter configurations for the scenario
    [obj.scenarioTxConfigs, obj.scenarioGlobalLayout] = generateScenarioTransmitterConfigurations( ...
        obj, transmitters, obj.scenarioRxConfigs);

    % Update Entity Snapshots with communication state
    entities = updateEntityCommunicationState(obj, entities, obj.scenarioTxConfigs, obj.scenarioRxConfigs);
    obj.scenarioEntities = entities;

    obj.logger.debug('Scenario initialization completed: %d TX configs, %d RX configs', ...
        length(obj.scenarioTxConfigs), length(obj.scenarioRxConfigs));
end
