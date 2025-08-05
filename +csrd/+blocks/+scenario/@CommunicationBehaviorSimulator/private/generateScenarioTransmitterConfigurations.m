function [txConfigs, globalLayout] = generateScenarioTransmitterConfigurations(obj, ...
        transmitters, rxConfigs, factoryConfigs)
    % generateScenarioTransmitterConfigurations - Generate fixed transmitter configurations for scenario
    %
    % Creates transmitter configurations including frequency allocations,
    % modulation schemes, and transmission parameters based on receiver
    % capabilities and factory configurations. These configurations remain
    % fixed throughout the entire scenario.

    txConfigs = [];

    % Initialize global layout
    globalLayout = struct();
    globalLayout.Strategy = obj.Config.FrequencyAllocation.Strategy;
    globalLayout.FrequencyAllocations = {};

    if isempty(rxConfigs)
        obj.logger.warning('Scenario: No receivers available for transmitter configuration');
        return;
    end

    % Use primary receiver for frequency allocation (first receiver)
    primaryReceiver = rxConfigs(1);
    observableRange = primaryReceiver.ObservableRange;

    obj.logger.debug('Scenario: Using receiver %s observable range [%.1f, %.1f] MHz for frequency planning', ...
        primaryReceiver.EntityID, observableRange(1) / 1e6, observableRange(2) / 1e6);

    for i = 1:length(transmitters)
        transmitter = transmitters(i);

        txConfig = struct();
        txConfig.EntityID = transmitter.ID;
        txConfig.Position = transmitter.Position;

        % Configure transmitter parameters from factory configurations
        txFactoryConfig = factoryConfigs.Transmit;
        messageFactoryConfig = factoryConfigs.Message;
        modulationFactoryConfig = factoryConfigs.Modulation;

        % Select transmitter type and basic parameters
        txConfig.Type = selectTransmitterType(obj, transmitter, txFactoryConfig);
        txConfig.Power = selectTransmitPower(obj, transmitter, txFactoryConfig);

        % Configure antenna parameters
        antennaRange = txFactoryConfig.Parameters.Antennas;
        txConfig.NumAntennas = randi([antennaRange.Min, antennaRange.Max]);
        txConfig.AntennaGain = calculateAntennaGain(obj, txConfig.NumAntennas);

        % Generate message configuration
        txConfig.Message = generateMessageConfiguration(obj, transmitter, messageFactoryConfig);

        % Generate modulation configuration
        txConfig.Modulation = generateModulationConfiguration(obj, transmitter, modulationFactoryConfig);

        % Calculate required bandwidth based on modulation
        txConfig.RequiredBandwidth = calculateRequiredBandwidth(obj, txConfig.Modulation);

        % Generate transmission behavior pattern (fixed for scenario)
        txConfig.TransmissionPattern = generateTransmissionPattern(obj, transmitter, txFactoryConfig);

        % Initialize FrequencyAllocation field to avoid structure mismatch later
        txConfig.FrequencyAllocation = struct();

        txConfigs = [txConfigs, txConfig];
    end

    % Perform frequency allocation for all transmitters
    [txConfigs, globalLayout] = performScenarioFrequencyAllocation(obj, txConfigs, ...
        observableRange, globalLayout);
end
