function [txConfigs, globalLayout] = generateScenarioTransmitterConfigurations(obj, ...
        transmitters, rxConfigs)
    % generateScenarioTransmitterConfigurations - Generate fixed transmitter configurations
    %
    % DESIGN PRINCIPLE:
    %   Uses obj.Config (set during construction from scenario_factory.m).
    %   Does NOT require passing config as parameter since it's static.
    %   Produces a "blueprint" with type names and scenario-level params.
    %   Implementation details are handled by respective factories during processing.
    %
    % Input Arguments:
    %   transmitters - Array of transmitter entities from PhysicalEnvironmentSimulator
    %   rxConfigs - Receiver configurations (for observable range reference)
    %
    % Output Arguments:
    %   txConfigs - Cell array of transmitter configurations
    %   globalLayout - Global frequency allocation layout

    txConfigs = {};  % Use cell array to avoid struct field mismatch

    % Initialize global layout
    globalLayout = struct();
    if isfield(obj.Config, 'FrequencyAllocation') && isfield(obj.Config.FrequencyAllocation, 'Strategy')
        globalLayout.Strategy = obj.Config.FrequencyAllocation.Strategy;
    else
        globalLayout.Strategy = 'ReceiverCentric';
    end
    globalLayout.FrequencyAllocations = {};

    if isempty(rxConfigs)
        obj.logger.warning('Scenario: No receivers available for transmitter configuration');
        return;
    end

    % Use unified receiver config for frequency allocation
    observableRange = obj.unifiedReceiverConfig.ObservableRange;

    obj.logger.debug('Scenario: Using unified observable range [%.1f, %.1f] MHz for frequency planning', ...
        observableRange(1) / 1e6, observableRange(2) / 1e6);

    % Get scenario-level parameters from obj.Config
    txParams = getTransmitterParams(obj.Config);
    modParams = getModulationParams(obj.Config);
    msgParams = getMessageParams(obj.Config);
    temporalParams = getTemporalParams(obj.Config);

    for i = 1:length(transmitters)
        transmitter = transmitters(i);

        txPlan = struct();
        txPlan.EntityID = transmitter.ID;

        % Physical group
        txPlan.Physical.Position = transmitter.Position;

        % Hardware group
        txPlan.Hardware.Type = selectTransmitterType(txParams.Types);
        txPlan.Hardware.Power = randomInRange(obj, txParams.Power.Min, txParams.Power.Max);
        txPlan.Hardware.NumAntennas = randi([txParams.NumAntennas.Min, txParams.NumAntennas.Max]);
        txPlan.Hardware.AntennaGain = calculateAntennaGain(obj, txPlan.Hardware.NumAntennas);

        % ===== CALCULATION FLOW (Order matters!) =====
        
        % 1. First: Allocate BANDWIDTH based on receiver sample rate
        maxBandwidth = obj.unifiedReceiverConfig.SampleRate * txParams.BandwidthRatio.Max;
        minBandwidth = obj.unifiedReceiverConfig.SampleRate * txParams.BandwidthRatio.Min;
        txPlan.Spectrum.PlannedBandwidth = randomInRange(obj, minBandwidth, maxBandwidth);
        txPlan.Spectrum.PlannedFreqOffset = 0;
        txPlan.Spectrum.LowerBound = 0;
        txPlan.Spectrum.UpperBound = 0;
        txPlan.Spectrum.ReceiverSampleRate = obj.unifiedReceiverConfig.SampleRate;

        % 2. Second: Generate TEMPORAL PATTERN (need transmission duration)
        temporalPattern = generateTemporalPattern(obj, temporalParams);
        txPlan.Temporal = temporalPattern;
        
        % Calculate total transmission duration from intervals
        totalTxDuration = calculateTotalTransmissionDuration(txPlan.Temporal);

        % 3. Third: Generate MODULATION config (symbol rate derived from bandwidth)
        txPlan.Modulation = generateModulationConfig(obj, ...
            txPlan.Spectrum.PlannedBandwidth, modParams);

        % 4. Fourth: Generate MESSAGE config (length derived from symbol rate and duration)
        txPlan.Message = generateMessageConfig(obj, ...
            txPlan.Modulation, totalTxDuration, msgParams);

        txConfigs{end+1} = txPlan;
    end

    % Perform frequency allocation for all transmitters
    [txConfigs, globalLayout] = performScenarioFrequencyAllocation(obj, txConfigs, ...
        observableRange, globalLayout);
end

function params = getTransmitterParams(config)
    % getTransmitterParams - Extract transmitter parameters from config
    
    params = struct();
    
    % Default values
    params.Types = {'Simulation'};
    params.Power.Min = 10;
    params.Power.Max = 30;
    params.NumAntennas.Min = 1;
    params.NumAntennas.Max = 4;
    params.BandwidthRatio.Min = 0.02;
    params.BandwidthRatio.Max = 0.25;
    
    % Override with config values
    if isfield(config, 'Transmitter')
        txConfig = config.Transmitter;
        
        if isfield(txConfig, 'Types')
            params.Types = txConfig.Types;
        elseif isfield(txConfig, 'Type')
            params.Types = {txConfig.Type};
        end
        if isfield(txConfig, 'Power')
            params.Power = txConfig.Power;
        end
        if isfield(txConfig, 'NumAntennas')
            params.NumAntennas = txConfig.NumAntennas;
        end
        if isfield(txConfig, 'BandwidthRatio')
            params.BandwidthRatio = txConfig.BandwidthRatio;
        end
    end
end

function params = getModulationParams(config)
    % getModulationParams - Extract modulation parameters from config
    %
    % DESIGN PRINCIPLE:
    %   - Types from config (for random selection)
    %   - SymbolRate is CALCULATED from bandwidth (not configured)
    %   - Default orders are in config, detailed orders in modulation_factory
    
    params = struct();
    
    % Defaults
    params.Types = {'PSK', 'QAM'};
    params.RolloffFactor = 0.25;
    params.SamplesPerSymbol.Min = 2;
    params.SamplesPerSymbol.Max = 8;
    params.DefaultOrders = struct();
    params.DefaultOrders.PSK = [2, 4, 8];
    params.DefaultOrders.QAM = [16, 64, 256];
    params.DefaultOrders.FSK = [2, 4, 8];
    params.DefaultOrders.FM = 1;
    params.DefaultOrders.AM = 1;
    
    % Get from config
    if isfield(config, 'Modulation')
        modConfig = config.Modulation;
        
        if isfield(modConfig, 'Types')
            params.Types = modConfig.Types;
        end
        if isfield(modConfig, 'RolloffFactor')
            params.RolloffFactor = modConfig.RolloffFactor;
        end
        if isfield(modConfig, 'SamplesPerSymbol')
            params.SamplesPerSymbol = modConfig.SamplesPerSymbol;
        end
        if isfield(modConfig, 'DefaultOrders')
            params.DefaultOrders = modConfig.DefaultOrders;
        end
    end
end

function params = getMessageParams(config)
    % getMessageParams - Extract message parameters from config
    %
    % DESIGN PRINCIPLE:
    %   - Types from config (for random selection)
    %   - Length is CALCULATED from symbol rate and duration (not configured)
    
    params = struct();
    
    % Defaults
    params.Types = {'RandomBit'};
    params.Length.Min = 64;
    params.Length.Max = 65536;
    
    % Get from config
    if isfield(config, 'Message')
        msgConfig = config.Message;
        
        if isfield(msgConfig, 'Types')
            params.Types = msgConfig.Types;
        end
        if isfield(msgConfig, 'Length')
            params.Length = msgConfig.Length;
        end
    end
end

function params = getTemporalParams(config)
    % getTemporalParams - Extract temporal behavior parameters from config
    
    params = struct();
    
    % Default values
    params.PatternTypes = {'Continuous', 'Burst', 'Scheduled', 'Random'};
    params.PatternDistribution = [0.4, 0.3, 0.2, 0.1];
    params.ObservationDuration = 1.0;
    params.NumFramesPerScenario = 10;
    
    % Burst pattern defaults
    params.Burst.OnDuration.Min = 0.01;
    params.Burst.OnDuration.Max = 0.1;
    params.Burst.OffDuration.Min = 0.01;
    params.Burst.OffDuration.Max = 0.2;
    params.Burst.DutyCycle.Min = 0.1;
    params.Burst.DutyCycle.Max = 0.8;
    params.Burst.InitialDelay.Min = 0;
    params.Burst.InitialDelay.Max = 0.5;
    
    % Scheduled pattern defaults
    params.Scheduled.SlotDuration.Min = 0.005;
    params.Scheduled.SlotDuration.Max = 0.02;
    params.Scheduled.SlotsPerFrame.Min = 4;
    params.Scheduled.SlotsPerFrame.Max = 16;
    
    % Random pattern defaults
    params.Random.StartTimeRatio.Min = 0;
    params.Random.StartTimeRatio.Max = 0.5;
    params.Random.DurationRatio.Min = 0.1;
    params.Random.DurationRatio.Max = 0.9;
    params.Random.NumBursts.Min = 1;
    params.Random.NumBursts.Max = 5;
    
    % Override with config values
    if isfield(config, 'Global')
        if isfield(config.Global, 'ObservationDuration')
            params.ObservationDuration = config.Global.ObservationDuration;
        end
        if isfield(config.Global, 'NumFramesPerScenario')
            params.NumFramesPerScenario = config.Global.NumFramesPerScenario;
        end
    end
    
    if isfield(config, 'TemporalBehavior')
        temporal = config.TemporalBehavior;
        
        if isfield(temporal, 'PatternTypes')
            params.PatternTypes = temporal.PatternTypes;
        end
        if isfield(temporal, 'PatternDistribution')
            params.PatternDistribution = temporal.PatternDistribution;
        end
        if isfield(temporal, 'Burst')
            params.Burst = mergeStructs(params.Burst, temporal.Burst);
        end
        if isfield(temporal, 'Scheduled')
            params.Scheduled = mergeStructs(params.Scheduled, temporal.Scheduled);
        end
        if isfield(temporal, 'Random')
            params.Random = mergeStructs(params.Random, temporal.Random);
        end
    end
end

function merged = mergeStructs(base, override)
    % mergeStructs - Merge two structs, override takes precedence
    merged = base;
    if isstruct(override)
        fields = fieldnames(override);
        for i = 1:length(fields)
            merged.(fields{i}) = override.(fields{i});
        end
    end
end

function selectedType = selectTransmitterType(types)
    % selectTransmitterType - Randomly select a transmitter type
    if isempty(types)
        selectedType = 'Simulation';
    elseif iscell(types)
        selectedType = types{randi(length(types))};
    else
        selectedType = types;
    end
end

function totalDuration = calculateTotalTransmissionDuration(transmissionPattern)
    % calculateTotalTransmissionDuration - Sum up all transmission intervals
    
    intervals = transmissionPattern.Intervals;
    if isempty(intervals) || (size(intervals, 1) == 1 && all(intervals == 0))
        totalDuration = 0;
        return;
    end
    
    totalDuration = 0;
    for i = 1:size(intervals, 1)
        totalDuration = totalDuration + (intervals(i, 2) - intervals(i, 1));
    end
end

function modConfig = generateModulationConfig(obj, bandwidth, modParams)
    % generateModulationConfig - Generate modulation config from scenario params
    %
    % Symbol Rate Calculation:
    %   SymbolRate = Bandwidth / (1 + RolloffFactor)
    
    modConfig = struct();
    
    % Select modulation type from scenario params
    modTypes = modParams.Types;
    if iscell(modTypes)
        selectedType = modTypes{randi(length(modTypes))};
    else
        selectedType = modTypes;
    end
    modConfig.Type = selectedType;
    
    % Get rolloff factor
    rolloffFactor = modParams.RolloffFactor;
    
    % Calculate symbol rate from bandwidth
    modConfig.SymbolRate = bandwidth / (1 + rolloffFactor);
    
    % Get samples per symbol
    if isstruct(modParams.SamplesPerSymbol)
        spsMin = modParams.SamplesPerSymbol.Min;
        spsMax = modParams.SamplesPerSymbol.Max;
        modConfig.SamplesPerSymbol = randi([spsMin, spsMax]);
    else
        modConfig.SamplesPerSymbol = modParams.SamplesPerSymbol;
    end
    
    % Select order based on modulation type (from scenario config defaults)
    modConfig.Order = selectModulationOrder(selectedType, modParams);
    
    % Calculate bits per symbol
    if modConfig.Order >= 2
        modConfig.BitsPerSymbol = log2(modConfig.Order);
    else
        modConfig.BitsPerSymbol = 1;  % For analog modulations
    end
    
    obj.logger.debug('Scenario: Modulation %s, Order %d, SymbolRate %.2f kHz', ...
        modConfig.Type, modConfig.Order, modConfig.SymbolRate / 1e3);
end

function msgConfig = generateMessageConfig(~, modulationConfig, txDuration, msgParams)
    % generateMessageConfig - Generate message config from scenario params
    %
    % Message Length Calculation:
    %   Length = SymbolRate × BitsPerSymbol × TransmissionDuration
    
    msgConfig = struct();
    
    % Select message type from scenario params
    msgTypes = msgParams.Types;
    if iscell(msgTypes)
        selectedType = msgTypes{randi(length(msgTypes))};
    else
        selectedType = msgTypes;
    end
    msgConfig.Type = selectedType;
    
    % Calculate message length based on symbol rate, bits per symbol, and duration
    symbolRate = modulationConfig.SymbolRate;
    bitsPerSymbol = modulationConfig.BitsPerSymbol;
    
    % Calculate required bits (with some margin for framing overhead)
    calculatedLength = ceil(symbolRate * bitsPerSymbol * txDuration * 1.1); % 10% overhead margin
    
    % Apply bounds from scenario config
    lengthMin = msgParams.Length.Min;
    lengthMax = msgParams.Length.Max;
    
    % Clamp to bounds
    msgConfig.Length = max(lengthMin, min(lengthMax, calculatedLength));
    
    % Store calculation info for debugging
    msgConfig.CalculatedLength = calculatedLength;
    msgConfig.SymbolRate = symbolRate;
    msgConfig.TxDuration = txDuration;
end

function order = selectModulationOrder(modType, modParams)
    % selectModulationOrder - Select modulation order based on type
    %
    % Orders are from scenario config DefaultOrders
    
    % Get orders from scenario config
    if isfield(modParams.DefaultOrders, modType)
        orders = modParams.DefaultOrders.(modType);
    else
        % Default orders based on common modulation types
        % Note: For digital modulations, Order must be >= 2
        switch modType
            case {'PSK', 'OQPSK'}
                orders = [2, 4, 8, 16];
            case 'QAM'
                orders = [16, 64, 256];
            case {'FSK', 'CPFSK', 'GFSK'}
                orders = [2, 4, 8];
            case {'GMSK', 'MSK', 'OOK'}
                orders = 2;
            case {'FM', 'PM', 'AM', 'SSBAM', 'DSBAM', 'DSBSCAM', 'VSBAM'}
                orders = 1;  % Analog: Order not used, but set to 1
            otherwise
                orders = [2, 4];  % Default: at least 2 for digital
        end
    end
    
    % Select random order
    if isscalar(orders)
        order = orders;
    else
        order = orders(randi(length(orders)));
    end
    
    % Ensure order is at least 2 for digital modulations
    analogTypes = {'FM', 'PM', 'AM', 'SSBAM', 'DSBAM', 'DSBSCAM', 'VSBAM'};
    if ~ismember(modType, analogTypes) && order < 2
        order = 2;
    end
end

function pattern = generateTemporalPattern(obj, temporalParams)
    % generateTemporalPattern - Generate temporal transmission pattern
    
    pattern = struct();
    
    % Select pattern type based on distribution
    patternTypes = temporalParams.PatternTypes;
    distribution = temporalParams.PatternDistribution;
    
    % Normalize distribution
    distribution = distribution / sum(distribution);
    
    % Random selection based on distribution
    r = rand();
    cumDist = cumsum(distribution);
    typeIdx = find(r <= cumDist, 1, 'first');
    if isempty(typeIdx)
        typeIdx = 1;
    end
    selectedType = patternTypes{typeIdx};
    
    pattern.Type = selectedType;
    pattern.ObservationDuration = temporalParams.ObservationDuration;
    pattern.NumFrames = temporalParams.NumFramesPerScenario;
    
    switch selectedType
        case 'Continuous'
            pattern.DutyCycle = 1.0;
            pattern.StartTime = 0;
            pattern.EndTime = temporalParams.ObservationDuration;
            pattern.Intervals = [0, temporalParams.ObservationDuration];
            
        case 'Burst'
            burstParams = temporalParams.Burst;
            obsDur = temporalParams.ObservationDuration;
            % Scale durations to observation window to ensure bursts are visible
            onMin = min(burstParams.OnDuration.Min, obsDur * 0.8);
            onMax = min(burstParams.OnDuration.Max, obsDur * 0.8);
            offMin = min(burstParams.OffDuration.Min, obsDur * 0.5);
            offMax = min(burstParams.OffDuration.Max, obsDur * 0.5);
            delayMax = min(burstParams.InitialDelay.Max, obsDur * 0.3);
            delayMin = min(burstParams.InitialDelay.Min, delayMax);
            
            pattern.OnDuration = randomInRange(obj, onMin, onMax);
            pattern.OffDuration = randomInRange(obj, offMin, offMax);
            pattern.DutyCycle = pattern.OnDuration / (pattern.OnDuration + pattern.OffDuration);
            pattern.InitialDelay = randomInRange(obj, delayMin, delayMax);
            pattern.Intervals = generateBurstIntervals(pattern, obsDur);
            
        case 'Scheduled'
            schedParams = temporalParams.Scheduled;
            obsDur = temporalParams.ObservationDuration;
            slotMin = min(schedParams.SlotDuration.Min, obsDur * 0.3);
            slotMax = min(schedParams.SlotDuration.Max, obsDur * 0.3);
            pattern.SlotDuration = randomInRange(obj, slotMin, slotMax);
            pattern.NumSlots = randi([schedParams.SlotsPerFrame.Min, schedParams.SlotsPerFrame.Max]);
            pattern.AssignedSlot = randi(pattern.NumSlots);
            pattern.Intervals = generateScheduledIntervals(pattern, obsDur);
            
        case 'Random'
            randomParams = temporalParams.Random;
            pattern.NumBursts = randi([randomParams.NumBursts.Min, randomParams.NumBursts.Max]);
            pattern.Intervals = generateRandomIntervals(obj, randomParams, temporalParams.ObservationDuration, pattern.NumBursts);
    end
end

function intervals = generateBurstIntervals(pattern, observationDuration)
    intervals = [];
    t = pattern.InitialDelay;
    while t < observationDuration
        startTime = t;
        endTime = min(t + pattern.OnDuration, observationDuration);
        if endTime > startTime
            intervals = [intervals; startTime, endTime];
        end
        t = t + pattern.OnDuration + pattern.OffDuration;
    end
    if isempty(intervals)
        intervals = [0, 0];
    end
end

function intervals = generateScheduledIntervals(pattern, observationDuration)
    intervals = [];
    frameLength = pattern.SlotDuration * pattern.NumSlots;
    slotStart = (pattern.AssignedSlot - 1) * pattern.SlotDuration;
    
    t = 0;
    while t < observationDuration
        startTime = t + slotStart;
        endTime = min(startTime + pattern.SlotDuration, observationDuration);
        if endTime > startTime && startTime < observationDuration
            intervals = [intervals; startTime, endTime];
        end
        t = t + frameLength;
    end
    if isempty(intervals)
        intervals = [0, 0];
    end
end

function intervals = generateRandomIntervals(~, randomParams, observationDuration, numBursts)
    intervals = [];
    for i = 1:numBursts
        startRatio = randomParams.StartTimeRatio.Min + rand() * (randomParams.StartTimeRatio.Max - randomParams.StartTimeRatio.Min);
        durationRatio = randomParams.DurationRatio.Min + rand() * (randomParams.DurationRatio.Max - randomParams.DurationRatio.Min);
        
        startTime = startRatio * observationDuration;
        duration = durationRatio * observationDuration * (1 - startRatio);
        endTime = min(startTime + duration, observationDuration);
        
        if endTime > startTime
            intervals = [intervals; startTime, endTime];
        end
    end
    if isempty(intervals)
        intervals = [0, 0];
    end
end
