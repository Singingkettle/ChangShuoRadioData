function rxConfigs = generateScenarioReceiverConfigurations(obj, receivers)
    % generateScenarioReceiverConfigurations - Generate unified receiver configurations
    %
    % DESIGN PRINCIPLE:
    %   All spectrum monitoring receivers share the SAME unified configuration.
    %   This simplifies spectrum sensing algorithm design by removing device heterogeneity.
    %   The unified config is stored in obj.unifiedReceiverConfig (set during setupImpl).
    %
    % Input Arguments:
    %   receivers - Array of receiver entities from PhysicalEnvironmentSimulator
    %
    % Output Arguments:
    %   rxConfigs - Cell array of receiver configurations (all share same params)

    rxConfigs = {};

    % Use the unified receiver configuration (set during setup)
    unifiedConfig = obj.unifiedReceiverConfig;

    for i = 1:length(receivers)
        receiver = receivers(i);

        rxPlan = struct();
        rxPlan.EntityID = receiver.ID;

        % Physical group
        rxPlan.Physical.Position = receiver.Position;

        % Hardware group (unified for all receivers)
        rxPlan.Hardware.Type = unifiedConfig.Type;
        rxPlan.Hardware.NumAntennas = unifiedConfig.NumAntennas;

        % Observation group (unified for all receivers)
        rxPlan.Observation.SampleRate = unifiedConfig.SampleRate;
        rxPlan.Observation.CenterFrequency = unifiedConfig.CenterFrequency;
        rxPlan.Observation.RealCarrierFrequency = unifiedConfig.RealCarrierFrequency;
        rxPlan.Observation.ObservableRange = unifiedConfig.ObservableRange;

        % NOTE: Implementation details (NoiseFigure, Sensitivity, AntennaGain)
        % are NOT set here. They will be looked up by ReceiveFactory during processing.

        rxConfigs{end+1} = rxPlan;

        obj.logger.debug('Scenario: Configured receiver %s with UNIFIED config (SampleRate=%.1f MHz)', ...
            receiver.ID, rxPlan.Observation.SampleRate / 1e6);
    end

    obj.logger.debug('Scenario: All %d receivers configured with unified sample rate %.1f MHz', ...
        length(receivers), unifiedConfig.SampleRate / 1e6);
end
