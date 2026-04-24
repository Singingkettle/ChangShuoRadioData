function setupImpl(obj)
    % setupImpl - Initialize communication behavior modeling systems
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

    obj.logger = csrd.utils.logger.GlobalLogManager.getLogger();
    obj.logger.debug('CommunicationBehaviorSimulator setup starting...');

    % Initialize default configuration if not provided
    if isempty(obj.Config) || ~isstruct(obj.Config)
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
            % Handle both single value and Min/Max struct for backward compatibility
            if isstruct(rxConfig.SampleRate)
                % Old format: randomly select within range (but we prefer single value now)
                unifiedConfig.SampleRate = rxConfig.SampleRate.Min + ...
                    rand() * (rxConfig.SampleRate.Max - rxConfig.SampleRate.Min);
            else
                unifiedConfig.SampleRate = rxConfig.SampleRate;
            end
        end

        if isfield(rxConfig, 'CenterFrequency')
            unifiedConfig.CenterFrequency = rxConfig.CenterFrequency;
        end

        if isfield(rxConfig, 'RealCarrierFrequency')
            unifiedConfig.RealCarrierFrequency = rxConfig.RealCarrierFrequency;
        end

        if isfield(rxConfig, 'NumAntennas')
            % Handle both single value and Min/Max struct for backward compatibility
            if isstruct(rxConfig.NumAntennas)
                unifiedConfig.NumAntennas = randi([rxConfig.NumAntennas.Min, rxConfig.NumAntennas.Max]);
            else
                unifiedConfig.NumAntennas = rxConfig.NumAntennas;
            end
        end
    end

    % Calculate observable range from sample rate (baseband: -fs/2 to +fs/2)
    unifiedConfig.ObservableRange = [-unifiedConfig.SampleRate/2, unifiedConfig.SampleRate/2];
end
