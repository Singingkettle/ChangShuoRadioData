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
        rxPlan.Physical.PositionUnit = getEntityPositionUnit(receiver);
        if isfield(receiver, 'GeoPositionDeg')
            rxPlan.Physical.GeoPositionDeg = receiver.GeoPositionDeg;
        end
        rxPlan.Physical.Velocity = requireEntityVelocity(receiver, ...
            'Receiver');

        % Hardware group (unified for all receivers)
        rxPlan.Hardware.Type = unifiedConfig.Type;
        rxPlan.Hardware.NumAntennas = unifiedConfig.NumAntennas;

        % Observation group (unified for all receivers)
        rxPlan.Observation.SampleRate = unifiedConfig.SampleRate;
        rxPlan.Observation.CenterFrequency = unifiedConfig.CenterFrequency;
        rxPlan.Observation.RealCarrierFrequency = unifiedConfig.RealCarrierFrequency;
        rxPlan.Observation.ObservableRange = unifiedConfig.ObservableRange;
        if isfield(unifiedConfig, 'Sdr') && isstruct(unifiedConfig.Sdr)
            rxPlan.Observation.Sdr = unifiedConfig.Sdr;
        end
        if ~isempty(obj.scenarioRegulatoryPlan) && ...
                isfield(obj.scenarioRegulatoryPlan, 'Receiver')
            rxPlan.Observation.Regulatory = struct( ...
                'RegionId', obj.scenarioRegulatoryPlan.RegionId, ...
                'Authority', obj.scenarioRegulatoryPlan.Authority, ...
                'MonitoringBandId', obj.scenarioRegulatoryPlan.Receiver.MonitoringBandId, ...
                'MonitoringRangeHz', obj.scenarioRegulatoryPlan.Receiver.MonitoringRangeHz);
        end

        % NOTE: Implementation details (NoiseFigure, Sensitivity, AntennaGain)
        % are NOT set here. They will be looked up by ReceiveFactory during processing.

        rxConfigs{end+1} = rxPlan;

        obj.logger.debug('Scenario: Configured receiver %s with UNIFIED config (SampleRate=%.1f MHz)', ...
            receiver.ID, rxPlan.Observation.SampleRate / 1e6);
    end

    obj.logger.debug('Scenario: All %d receivers configured with unified sample rate %.1f MHz', ...
        length(receivers), unifiedConfig.SampleRate / 1e6);
end

function unit = getEntityPositionUnit(entity)
    % getEntityPositionUnit - Return explicit physical coordinate unit.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isfield(entity, 'PositionUnit') && ~isempty(entity.PositionUnit)
    unit = char(string(entity.PositionUnit));
else
    unit = 'meters';
end
end

function velocity = requireEntityVelocity(entity, entityType)
    % requireEntityVelocity - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    if ~isfield(entity, 'Velocity') || isempty(entity.Velocity) || ...
            ~isnumeric(entity.Velocity) || numel(entity.Velocity) ~= 3 || ...
            any(~isfinite(entity.Velocity(:)))
        error('CSRD:Scenario:MissingEntityVelocity', ...
            ['%s %s is missing a finite 3-element Velocity vector. ', ...
             'PhysicalEnvironmentSimulator must publish velocity so ', ...
             'Doppler design/execution truth is not silently zeroed.'], ...
            entityType, char(string(entity.ID)));
    end
    velocity = double(entity.Velocity(:)).';
end
