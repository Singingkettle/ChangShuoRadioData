function setupImpl(obj)
    % setupImpl - Initialize communication behavior modeling systems
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    % TWO-PHASE ARCHITECTURE:
    %   Phase 1 (here in setupImpl):
    %     - Initialize unified receiver configuration (sample rate, observable range)
    %     - This determines the frequency spectrum that will be observed
    %
    %   Phase 2 (deferred to first stepImpl call):
    %     - Once entities are available, allocate frequencies for each transmitter
    %     - Plan bandwidths ensuring non-overlap within observable range
    %
    % DESIGN PRINCIPLE:
    %   All spectrum monitoring receivers share the SAME unified configuration.
    %   This simplifies spectrum sensing algorithm design by removing device heterogeneity.

    obj.logger = csrd.runtime.logger.GlobalLogManager.getLogger();
    obj.logger.debug('CommunicationBehaviorSimulator setup starting...');

    % Initialize default configuration if not provided
    if isempty(obj.Config) || ~isstruct(obj.Config) || ...
            isempty(fieldnames(obj.Config))
        obj.Config = getDefaultConfiguration(obj);
    end

    % Phase 1: Initialize UNIFIED receiver configuration
    obj.unifiedReceiverConfig = initializeUnifiedReceiverConfig(obj);
    obj.logger.debug('Unified receiver config: SampleRate=%.1f MHz, ObservableRange=[%.1f, %.1f] MHz', ...
        obj.unifiedReceiverConfig.SampleRate / 1e6, ...
        obj.unifiedReceiverConfig.ObservableRange(1) / 1e6, ...
        obj.unifiedReceiverConfig.ObservableRange(2) / 1e6);

    % Initialize core components
    obj.allocationHistory = containers.Map('KeyType', 'int32', 'ValueType', 'any');

    % Initialize transmission scheduling for frame-level control
    initializeTransmissionScheduler(obj);

    % Reset scenario initialization flag (frequency planning deferred to first step)
    obj.scenarioInitialized = false;
    obj.scenarioEntities = [];

    obj.logger.debug('CommunicationBehaviorSimulator setup completed');
end

function unifiedConfig = initializeUnifiedReceiverConfig(obj)
    % initializeUnifiedReceiverConfig - Create unified receiver configuration
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    % Reads configuration from obj.Config.Receiver and creates a single
    % unified configuration that all receivers will share.

    unifiedConfig = struct();

    % Default values
    unifiedConfig.Type = 'Simulation';
    unifiedConfig.SampleRate = 50e6;  % 50 MHz default
    unifiedConfig.CenterFrequency = 0;  % baseband
    unifiedConfig.RealCarrierFrequency = 2.4e9;  % 2.4 GHz default
    unifiedConfig.NumAntennas = 1;

    % Override with config values if available
    if isfield(obj.Config, 'Receiver')
        rxConfig = obj.Config.Receiver;

        if isfield(rxConfig, 'Type')
            unifiedConfig.Type = rxConfig.Type;
        end

        if isfield(rxConfig, 'SampleRate')
            unifiedConfig.SampleRate = requirePositiveScalar( ...
                rxConfig.SampleRate, 'Receiver.SampleRate');
        end

        if isfield(rxConfig, 'CenterFrequency')
            unifiedConfig.CenterFrequency = rxConfig.CenterFrequency;
        end

        if isfield(rxConfig, 'RealCarrierFrequency')
            unifiedConfig.RealCarrierFrequency = rxConfig.RealCarrierFrequency;
        end

        if isfield(rxConfig, 'NumAntennas')
            unifiedConfig.NumAntennas = requirePositiveIntegerScalar( ...
                rxConfig.NumAntennas, 'Receiver.NumAntennas');
        end

        if isfield(rxConfig, 'Sdr') && isstruct(rxConfig.Sdr) && ...
                isfield(rxConfig.Sdr, 'Model') && ~isempty(rxConfig.Sdr.Model)
            unifiedConfig = applySdrProfile(unifiedConfig, rxConfig.Sdr.Model);
        end
    end

    % Calculate observable range from sample rate (baseband: -fs/2 to +fs/2)
    unifiedConfig.ObservableRange = [-unifiedConfig.SampleRate/2, unifiedConfig.SampleRate/2];
end

function unifiedConfig = applySdrProfile(unifiedConfig, modelId)
    % applySdrProfile - Constrain the unified receiver to an SDR capability.
    % Inputs: unified receiver config, SDR model id.
    % Outputs: unified config capped to the model's IBW and channel count,
    %   with the capability profile attached for link-budget and annotation.
    profile = csrd.catalog.receiver.SdrReceiverCatalog.load(modelId);
    if unifiedConfig.SampleRate > profile.MaxInstantaneousBandwidthHz
        unifiedConfig.SampleRate = profile.MaxInstantaneousBandwidthHz;
    end
    if unifiedConfig.NumAntennas > profile.NumChannels
        unifiedConfig.NumAntennas = profile.NumChannels;
    end
    unifiedConfig.Sdr = struct( ...
        'Model', profile.Model, ...
        'Manufacturer', profile.Manufacturer, ...
        'TuningRangeHz', profile.TuningRangeHz, ...
        'MaxInstantaneousBandwidthHz', profile.MaxInstantaneousBandwidthHz, ...
        'AdcBits', profile.AdcBits, ...
        'NoiseFigureDb', profile.NoiseFigureDb, ...
        'NumChannels', profile.NumChannels);
end

function value = requirePositiveScalar(value, fieldName)
    % requirePositiveScalar - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    if isstruct(value)
        error('CSRD:Scenario:InvalidReceiverConfig', ...
            ['%s must be a positive scalar. Min/Max receiver ranges were ', ...
             'removed because they add hidden RNG draws before the ', ...
             'regulatory planner selects the monitoring band.'], fieldName);
    end
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
        error('CSRD:Scenario:InvalidReceiverConfig', ...
            '%s must be a positive finite scalar.', fieldName);
    end
end

function value = requirePositiveIntegerScalar(value, fieldName)
    % requirePositiveIntegerScalar - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    value = requirePositiveScalar(value, fieldName);
    if abs(value - round(value)) > 0
        error('CSRD:Scenario:InvalidReceiverConfig', ...
            '%s must be a positive integer scalar.', fieldName);
    end
    value = round(value);
end
