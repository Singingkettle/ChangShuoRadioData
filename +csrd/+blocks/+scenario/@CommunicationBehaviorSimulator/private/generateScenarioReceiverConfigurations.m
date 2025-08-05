function rxConfigs = generateScenarioReceiverConfigurations(obj, transmitters, receivers, factoryConfigs)
    % generateScenarioReceiverConfigurations - Generate fixed receiver configurations for scenario
    %
    % Creates receiver configurations that define the observable frequency
    % ranges and detection capabilities for each receiver entity. These
    % configurations remain fixed throughout the entire scenario.

    rxConfigs = [];

    for i = 1:length(receivers)
        receiver = receivers(i);

        rxConfig = struct();
        rxConfig.EntityID = receiver.ID;
        rxConfig.Position = receiver.Position;

        % Configure receiver parameters from factory configurations
        rxFactoryConfig = factoryConfigs.Receive;

        % Select receiver type and parameters
        rxConfig.Type = selectReceiverType(obj, receiver, rxFactoryConfig);
        rxConfig.SampleRate = selectSampleRate(obj, receiver, rxFactoryConfig);
        rxConfig.ObservableRange = [0, rxConfig.SampleRate];
        rxConfig.Sensitivity = selectSensitivity(obj, receiver, rxFactoryConfig);
        rxConfig.NoiseFigure = selectNoiseFigure(obj, receiver, rxFactoryConfig);

        % Configure antenna parameters
        antennaRange = rxFactoryConfig.Parameters.Antennas;
        rxConfig.NumAntennas = randi([antennaRange.Min, antennaRange.Max]);
        rxConfig.AntennaGain = calculateAntennaGain(obj, rxConfig.NumAntennas);

        rxConfigs = [rxConfigs, rxConfig];

        obj.logger.debug('Scenario: Configured receiver %s with %.1f MHz sample rate', ...
            receiver.ID, rxConfig.SampleRate / 1e6);
    end

end
