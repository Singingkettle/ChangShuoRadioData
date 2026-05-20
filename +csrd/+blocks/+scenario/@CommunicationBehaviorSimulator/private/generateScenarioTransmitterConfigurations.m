function [txConfigs, globalLayout] = generateScenarioTransmitterConfigurations(obj, ...
        transmitters, rxConfigs)
    % 中文说明：提供 CSRD 生产链路中的 generateScenarioTransmitterConfigurations 实现。
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

    % Initialize global layout.
    % Phase 2 (D7): only 'ReceiverCentric' is supported. The default
    % is enforced here to keep globalLayout.Strategy populated even
    % when the caller forgot to set it; any explicit non-ReceiverCentric
    % value will be rejected later by performScenarioFrequencyAllocation
    % (CSRD:Scenario:UnsupportedFrequencyStrategy).
    globalLayout = struct();
    if isfield(obj.Config, 'FrequencyAllocation') && isfield(obj.Config.FrequencyAllocation, 'Strategy')
        globalLayout.Strategy = obj.Config.FrequencyAllocation.Strategy;
    else
        globalLayout.Strategy = 'ReceiverCentric';
    end
    globalLayout.FrequencyAllocations = {};
    regulatoryEnabled = csrd.catalog.spectrum.RegionSpectrumSelector.isEnabled(obj.Config);
    regulatoryPlan = struct();
    if regulatoryEnabled
        if isempty(obj.scenarioRegulatoryPlan) || ...
                ~isfield(obj.scenarioRegulatoryPlan, 'EmitterPlans')
            error('CSRD:Spectrum:MissingScenarioRegulatoryPlan', ...
                ['Regulatory planning is enabled but scenarioRegulatoryPlan ', ...
                 'has not been initialized before transmitter generation.']);
        end
        regulatoryPlan = obj.scenarioRegulatoryPlan;
        globalLayout.Strategy = 'RegulatoryCatalog';
        globalLayout.Regulatory = struct( ...
            'Enable', true, ...
            'RegionId', regulatoryPlan.RegionId, ...
            'RegionName', regulatoryPlan.RegionName, ...
            'Authority', regulatoryPlan.Authority, ...
            'ServiceTier', regulatoryPlan.ServiceTier, ...
            'Receiver', regulatoryPlan.Receiver);
    else
        globalLayout.Regulatory = struct('Enable', false);
    end

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
        regulatoryEmitterPlan = struct();
        if regulatoryEnabled
            if i > numel(regulatoryPlan.EmitterPlans)
                error('CSRD:Spectrum:MissingEmitterPlan', ...
                    'Regulatory plan has %d emitter plans for %d transmitters.', ...
                    numel(regulatoryPlan.EmitterPlans), length(transmitters));
            end
            regulatoryEmitterPlan = regulatoryPlan.EmitterPlans(i);
        end

        txPlan = struct();
        txPlan.EntityID = transmitter.ID;

        % Physical group
        txPlan.Physical.Position = transmitter.Position;
        txPlan.Physical.PositionUnit = getEntityPositionUnit(transmitter);
        if isfield(transmitter, 'GeoPositionDeg')
            txPlan.Physical.GeoPositionDeg = transmitter.GeoPositionDeg;
        end
        txPlan.Physical.Velocity = requireEntityVelocity(transmitter, ...
            'Transmitter');

        % Hardware group
        txPlan.Hardware.Type = selectTransmitterType(txParams.Types);
        txPlan.Hardware.Power = randomInRange(obj, txParams.Power.Min, txParams.Power.Max);

        % ===== CALCULATION FLOW (Order matters!) =====
        
        % 1. First: Allocate BANDWIDTH based on receiver sample rate
        if regulatoryEnabled
            txPlan.Spectrum.PlannedBandwidth = regulatoryEmitterPlan.BandwidthHz;
            txPlan.Spectrum.PlannedFreqOffset = regulatoryEmitterPlan.CenterOffsetHz;
            txPlan.Spectrum.LowerBound = regulatoryEmitterPlan.CenterOffsetHz - ...
                regulatoryEmitterPlan.BandwidthHz / 2;
            txPlan.Spectrum.UpperBound = regulatoryEmitterPlan.CenterOffsetHz + ...
                regulatoryEmitterPlan.BandwidthHz / 2;
            txPlan.Spectrum.AbsoluteCenterFrequencyHz = ...
                regulatoryEmitterPlan.SelectedCenterFrequencyHz;
            txPlan.Regulatory = regulatoryEmitterPlan.Regulatory;
        else
            maxBandwidth = obj.unifiedReceiverConfig.SampleRate * txParams.BandwidthRatio.Max;
            minBandwidth = obj.unifiedReceiverConfig.SampleRate * txParams.BandwidthRatio.Min;
            txPlan.Spectrum.PlannedBandwidth = randomInRange(obj, minBandwidth, maxBandwidth);
            txPlan.Spectrum.PlannedFreqOffset = 0;
            txPlan.Spectrum.LowerBound = 0;
            txPlan.Spectrum.UpperBound = 0;
        end
        txPlan.Spectrum.ReceiverSampleRate = obj.unifiedReceiverConfig.SampleRate;

        % 2. Second: Generate TEMPORAL PATTERN (need transmission duration)
        temporalPattern = generateTemporalPattern(obj, temporalParams, i);
        if regulatoryEnabled && isfield(regulatoryEmitterPlan, 'TemporalPattern')
            temporalPattern = applyRegulatoryTemporalPattern( ...
                temporalPattern, regulatoryEmitterPlan.TemporalPattern);
        end
        txPlan.Temporal = temporalPattern;
        
        % Calculate total transmission duration from intervals
        totalTxDuration = calculateTotalTransmissionDuration(txPlan.Temporal);

        % 3. Third: Generate MODULATION config (symbol rate derived from bandwidth)
        if regulatoryEnabled
            txPlan.Modulation = generateRegulatoryModulationConfig(obj, ...
                txPlan.Spectrum.PlannedBandwidth, modParams, regulatoryEmitterPlan);
            modulationFamily = regulatoryEmitterPlan.ModulationFamily;
        else
            txPlan.Modulation = generateModulationConfig(obj, ...
                txPlan.Spectrum.PlannedBandwidth, modParams);
            modulationFamily = txPlan.Modulation.Type;
        end
        txPlan.Hardware.NumAntennas = selectNumAntennasForModulation( ...
            txParams.NumAntennas, modulationFamily);
        txPlan.Hardware.AntennaGain = calculateAntennaGain(obj, ...
            txPlan.Hardware.NumAntennas);

        % 4. Fourth: Generate MESSAGE config (length derived from symbol rate and duration)
        txPlan.Message = generateMessageConfig(obj, ...
            txPlan.Modulation, totalTxDuration, msgParams);

        txConfigs{end+1} = txPlan;
    end

    % Perform frequency allocation for all transmitters
    [txConfigs, globalLayout] = performScenarioFrequencyAllocation(obj, txConfigs, ...
        rxConfigs, observableRange, globalLayout);
end

function unit = getEntityPositionUnit(entity)
    % getEntityPositionUnit - Return explicit physical coordinate unit.
    % 中文说明：Position 是米制坐标，GeoPositionDeg 只用于地理传播模型。
if isfield(entity, 'PositionUnit') && ~isempty(entity.PositionUnit)
    unit = char(string(entity.PositionUnit));
else
    unit = 'meters';
end
end

function velocity = requireEntityVelocity(entity, entityType)
    % requireEntityVelocity - Production declaration in CSRD.
    % 中文说明：requireEntityVelocity 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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

function params = getTransmitterParams(config)
    % getTransmitterParams - Extract transmitter parameters from config
    % 中文说明：getTransmitterParams 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.

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
    % 中文说明：getModulationParams 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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
    params.MinimumModulatorSampleRateHz = 0;
    params.OFDMMimoMode = 'OSTBC';
    
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
        if isfield(modConfig, 'OFDMMimoMode') && ~isempty(modConfig.OFDMMimoMode)
            params.OFDMMimoMode = char(string(modConfig.OFDMMimoMode));
        end
    end
    if isfield(config, 'Regulatory') && isstruct(config.Regulatory) && ...
            isfield(config.Regulatory, 'MinimumModulatorSampleRateHz') && ...
            isnumeric(config.Regulatory.MinimumModulatorSampleRateHz) && ...
            isscalar(config.Regulatory.MinimumModulatorSampleRateHz) && ...
            config.Regulatory.MinimumModulatorSampleRateHz > 0
        params.MinimumModulatorSampleRateHz = ...
            config.Regulatory.MinimumModulatorSampleRateHz;
    end
end

function params = getMessageParams(config)
    % getMessageParams - Extract message parameters from config
    % 中文说明：getMessageParams 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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
    % 中文说明：getTemporalParams 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    
    params = struct();
    
    % Default values
    params.PatternTypes = {'Continuous', 'Burst', 'Scheduled', 'Random'};
    params.PatternDistribution = [0.4, 0.3, 0.2, 0.1];
    params.ObservationDuration = [];
    params.NumFramesPerScenario = [];
    
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

    % Explicit pattern defaults. Intervals may be a single Nx2 matrix
    % shared by every transmitter or a 1xNumTx cell array of Nx2 matrices.
    params.Explicit.Intervals = [];

    if isfield(config, 'RuntimePlan') && isstruct(config.RuntimePlan) && ...
            isfield(config.RuntimePlan, 'Frame') && ...
            isstruct(config.RuntimePlan.Frame)
        framePlan = config.RuntimePlan.Frame;
        if isfield(framePlan, 'ObservationDurationSec')
            params.ObservationDuration = framePlan.ObservationDurationSec;
        end
        if isfield(framePlan, 'NumFramesPerScenario')
            params.NumFramesPerScenario = framePlan.NumFramesPerScenario;
        end
    end
    if isempty(params.ObservationDuration) || isempty(params.NumFramesPerScenario)
        error('CSRD:RuntimePlan:MissingFrameContract', ...
            ['CommunicationBehavior requires RuntimePlan.Frame.', ...
             'ObservationDurationSec and NumFramesPerScenario.']);
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
        if isfield(temporal, 'Explicit')
            params.Explicit = mergeStructs(params.Explicit, temporal.Explicit);
        end
    end
end

function merged = mergeStructs(base, override)
    % mergeStructs - Merge two structs, override takes precedence
    % 中文说明：mergeStructs 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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
    % 中文说明：selectTransmitterType 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    if isempty(types)
        selectedType = 'Simulation';
    elseif iscell(types)
        selectedType = types{randi(length(types))};
    else
        selectedType = types;
    end
end

function numAntennas = selectNumAntennasForModulation(numAntennaRange, modulationFamily)
    % selectNumAntennasForModulation - Keep hardware compatible with the
    % 中文说明：selectNumAntennasForModulation 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % Phase 8 service-driven modulation family before the blueprint
    % validator sees it.
    family = char(string(modulationFamily));
    minAnt = numAntennaRange.Min;
    maxAnt = numAntennaRange.Max;
    singleAntennaFamilies = {'FM','PM','AM','SSBAM','DSBAM','DSBSCAM','VSBAM', ...
        'FSK','MSK','CPFSK','GFSK','GMSK','OOK','PAM'};
    if ismember(family, singleAntennaFamilies)
        if minAnt > 1
            error('CSRD:Scenario:IncompatibleAntennaModulation', ...
                ['Modulation family %s is single-antenna in this pipeline, ', ...
                 'but Transmitter.NumAntennas.Min=%g.'], family, minAnt);
        end
        numAntennas = 1;
        return;
    end
    maxAllowed = min(maxAnt, 4);
    minAllowed = max(1, minAnt);
    if minAllowed > maxAllowed
        error('CSRD:Scenario:InvalidTxAntennaRange', ...
            'Transmitter.NumAntennas range [%g, %g] is incompatible with supported range [1, 4].', ...
            minAnt, maxAnt);
    end
    numAntennas = randi([minAllowed, maxAllowed]);
end

function pattern = applyRegulatoryTemporalPattern(pattern, temporalPattern)
    % applyRegulatoryTemporalPattern - Production declaration in CSRD.
    % 中文说明：applyRegulatoryTemporalPattern 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    recommended = char(string(temporalPattern));
    if isempty(recommended) || strcmp(recommended, pattern.Type)
        return;
    end
    obsDur = pattern.ObservationDuration;
    pattern.Type = recommended;
    switch recommended
        case 'Continuous'
            pattern.DutyCycle = 1.0;
            pattern.StartTime = 0;
            pattern.EndTime = obsDur;
            pattern.Intervals = [0, obsDur];
        case 'Burst'
            onDuration = min(obsDur, max(obsDur * 0.3, min(0.01, obsDur)));
            offDuration = max(obsDur - onDuration, 0);
            pattern.OnDuration = onDuration;
            pattern.OffDuration = offDuration;
            pattern.DutyCycle = onDuration / max(onDuration + offDuration, eps);
            pattern.InitialDelay = 0;
            pattern.Intervals = [0, onDuration];
        case 'Scheduled'
            pattern.SlotDuration = obsDur;
            pattern.NumSlots = 1;
            pattern.AssignedSlot = 1;
            pattern.Intervals = [0, obsDur];
    end
end

function totalDuration = calculateTotalTransmissionDuration(transmissionPattern)
    % calculateTotalTransmissionDuration - Sum up all transmission intervals
    % 中文说明：calculateTotalTransmissionDuration 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    
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
    % 中文说明：generateModulationConfig 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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
    modConfig.Family = selectedType;
    
    % Get rolloff factor
    rolloffFactor = modParams.RolloffFactor;
    modConfig.RolloffFactor = rolloffFactor;
    modConfig.OFDMMimoMode = modParams.OFDMMimoMode;
    
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
    if isfield(modParams, 'MinimumModulatorSampleRateHz') && ...
            modParams.MinimumModulatorSampleRateHz > 0
        minSps = ceil(modParams.MinimumModulatorSampleRateHz / modConfig.SymbolRate);
        modConfig.SamplesPerSymbol = max(modConfig.SamplesPerSymbol, minSps);
    end
    
    % Select order based on modulation type (from scenario config defaults)
    modConfig.Order = selectModulationOrder(selectedType, modParams);
    
    % Calculate bits per symbol
    if modConfig.Order >= 2
        modConfig.BitsPerSymbol = log2(modConfig.Order);
    else
        modConfig.BitsPerSymbol = 1;  % For analog modulations
    end
    modConfig.ModulatorConfig = buildLegacyModulatorConfig(modConfig, bandwidth);
    
    obj.logger.debug('Scenario: Modulation %s, Order %d, SymbolRate %.2f kHz', ...
        modConfig.Type, modConfig.Order, modConfig.SymbolRate / 1e3);
end

function modConfig = generateRegulatoryModulationConfig(obj, bandwidth, modParams, emitterPlan)
    % generateRegulatoryModulationConfig - Generate modulation config from a
    % 中文说明：generateRegulatoryModulationConfig 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % regulatory service plan rather than from an unconstrained type list.
    modConfig = struct();
    modConfig.Type = char(string(emitterPlan.ModulationFamily));
    modConfig.Family = modConfig.Type;
    modConfig.Order = double(emitterPlan.ModulationOrder);
    modConfig.RolloffFactor = modParams.RolloffFactor;
    modConfig.OFDMMimoMode = modParams.OFDMMimoMode;
    modConfig.SymbolRate = bandwidth / (1 + modParams.RolloffFactor);
    if isstruct(modParams.SamplesPerSymbol)
        spsMin = modParams.SamplesPerSymbol.Min;
        spsMax = modParams.SamplesPerSymbol.Max;
        modConfig.SamplesPerSymbol = randi([spsMin, spsMax]);
    else
        modConfig.SamplesPerSymbol = modParams.SamplesPerSymbol;
    end
    if isfield(modParams, 'MinimumModulatorSampleRateHz') && ...
            modParams.MinimumModulatorSampleRateHz > 0
        minSps = ceil(modParams.MinimumModulatorSampleRateHz / modConfig.SymbolRate);
        modConfig.SamplesPerSymbol = max(modConfig.SamplesPerSymbol, minSps);
    end
    if modConfig.Order >= 2
        modConfig.BitsPerSymbol = log2(modConfig.Order);
    else
        modConfig.BitsPerSymbol = 1;
    end
    modConfig.ModulatorConfig = buildRegulatoryModulatorConfig(modConfig, bandwidth);
    obj.logger.debug(['Scenario: Regulatory modulation %s, Order %d, ', ...
        'SymbolRate %.2f kHz, Band=%s'], modConfig.Type, ...
        modConfig.Order, modConfig.SymbolRate / 1e3, emitterPlan.BandId);
end

function modulatorConfig = buildRegulatoryModulatorConfig(modConfig, bandwidth)
    % buildRegulatoryModulatorConfig - Production declaration in CSRD.
    % 中文说明：buildRegulatoryModulatorConfig 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    modulatorConfig = struct();
    switch char(string(modConfig.Type))
        case 'OFDM'
            fftLength = 2048;
            guard = 144;
            usableBins = fftLength - 2 * guard;
            subcarrierSpacing = max(15e3, ceil(bandwidth / usableBins / 1e3) * 1e3);

            modulatorConfig.base.mode = "qam";
            modulatorConfig.ofdm.FFTLength = fftLength;
            modulatorConfig.ofdm.NumGuardBandCarriers = [guard; guard];
            modulatorConfig.ofdm.InsertDCNull = true;
            modulatorConfig.ofdm.CyclicPrefixLength = 144;
            modulatorConfig.ofdm.Subcarrierspacing = subcarrierSpacing;
            modulatorConfig.ofdm.Windowing = false;
            modulatorConfig.mimo.Mode = localValidateOFDMMimoMode(modConfig);
        case 'OQPSK'
            modulatorConfig.beta = modConfig.RolloffFactor;
            modulatorConfig.span = 10;
            modulatorConfig.SymbolMapping = "Gray";
            modulatorConfig.PhaseOffset = 0;
        otherwise
            if isfield(modConfig, 'RolloffFactor') && modConfig.RolloffFactor > 0
                modulatorConfig.beta = modConfig.RolloffFactor;
            end
    end
end

function modulatorConfig = buildLegacyModulatorConfig(modConfig, bandwidth)
    % buildLegacyModulatorConfig - Production declaration in CSRD.
    % 中文说明：buildLegacyModulatorConfig 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    modulatorConfig = struct();
    switch char(string(modConfig.Type))
        case 'OFDM'
            fftLength = 512;
            guard = 32;
            usableBins = fftLength - 2 * guard;
            subcarrierSpacing = max(15e3, ceil(bandwidth / usableBins / 1e3) * 1e3);

            modulatorConfig.base.mode = "qam";
            modulatorConfig.ofdm.FFTLength = fftLength;
            modulatorConfig.ofdm.NumGuardBandCarriers = [guard; guard];
            modulatorConfig.ofdm.InsertDCNull = true;
            modulatorConfig.ofdm.CyclicPrefixLength = 64;
            modulatorConfig.ofdm.Subcarrierspacing = subcarrierSpacing;
            modulatorConfig.ofdm.Windowing = false;
            modulatorConfig.mimo.Mode = localValidateOFDMMimoMode(modConfig);
        case 'OTFS'
            delayLength = 512;
            subcarrierSpacing = max(15e3, ceil(bandwidth / max(1, delayLength - 8) / 1e3) * 1e3);

            modulatorConfig.base.mode = "qam";
            modulatorConfig.otfs.DelayLength = delayLength;
            modulatorConfig.otfs.Subcarrierspacing = subcarrierSpacing;
            modulatorConfig.otfs.padType = "CP";
            modulatorConfig.otfs.padLen = 16;
        case 'SCFDMA'
            fftLength = 512;
            dataSubcarriers = 300;
            subcarrierSpacing = max(15e3, ceil(bandwidth / dataSubcarriers / 1e3) * 1e3);

            modulatorConfig.base.mode = "qam";
            modulatorConfig.scfdma.FFTLength = fftLength;
            modulatorConfig.scfdma.CyclicPrefixLength = 64;
            modulatorConfig.scfdma.Subcarrierspacing = subcarrierSpacing;
            modulatorConfig.scfdma.SubcarrierMappingInterval = 1;
            modulatorConfig.scfdma.NumDataSubcarriers = dataSubcarriers;
        case 'OQPSK'
            modulatorConfig.beta = modConfig.RolloffFactor;
            modulatorConfig.span = 10;
            modulatorConfig.SymbolMapping = "Gray";
            modulatorConfig.PhaseOffset = 0;
        otherwise
            if isfield(modConfig, 'RolloffFactor') && modConfig.RolloffFactor > 0
                modulatorConfig.beta = modConfig.RolloffFactor;
            end
    end
end

function mode = localValidateOFDMMimoMode(modConfig)
    % localValidateOFDMMimoMode - Resolve the explicit OFDM spatial abstraction.
    % 中文说明：解析 OFDM 多天线抽象，避免把 OSTBC 和独立空间流混成隐式行为。
    % Inputs / 输入: modulation config with optional OFDMMimoMode.
    % 输出 / Outputs: validated mode string stored in ModulatorConfig.mimo.Mode.
    if isfield(modConfig, 'OFDMMimoMode') && ~isempty(modConfig.OFDMMimoMode)
        mode = char(string(modConfig.OFDMMimoMode));
    else
        mode = 'OSTBC';
    end
    allowed = {'OSTBC', 'SpatialMultiplexing'};
    idx = find(strcmpi(mode, allowed), 1, 'first');
    if isempty(idx)
        error('CSRD:Scenario:InvalidOFDMMimoMode', ...
            'OFDMMimoMode must be one of {%s}; got %s.', ...
            strjoin(allowed, ', '), mode);
    end
    mode = allowed{idx};
end

function msgConfig = generateMessageConfig(~, modulationConfig, txDuration, msgParams)
    % generateMessageConfig - Generate message config from scenario params
    % 中文说明：generateMessageConfig 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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
    msgConfig.LengthMin = lengthMin;
    msgConfig.LengthMax = lengthMax;
    
    % Store calculation info for debugging
    msgConfig.CalculatedLength = calculatedLength;
    msgConfig.SymbolRate = symbolRate;
    msgConfig.TxDuration = txDuration;
end

function order = selectModulationOrder(modType, modParams)
    % selectModulationOrder - Select modulation order based on type
    % 中文说明：selectModulationOrder 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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

function pattern = generateTemporalPattern(obj, temporalParams, txIndex)
    % generateTemporalPattern - Generate temporal transmission pattern
    % 中文说明：generateTemporalPattern 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    
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
    if pattern.NumFrames > 0
        pattern.FrameDuration = pattern.ObservationDuration / pattern.NumFrames;
    else
        pattern.FrameDuration = pattern.ObservationDuration;
    end
    
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

        case 'Explicit'
            pattern.Intervals = selectExplicitIntervals( ...
                temporalParams.Explicit, txIndex, temporalParams.ObservationDuration);
            pattern.NumBursts = size(pattern.Intervals, 1);

        otherwise
            error('CSRD:Scenario:UnknownTemporalPattern', ...
                'Unsupported TemporalBehavior pattern type "%s".', ...
                char(string(selectedType)));
    end
end

function intervals = selectExplicitIntervals(explicitParams, txIndex, observationDuration)
    % selectExplicitIntervals - Resolve per-transmitter explicit bursts.
    if ~isstruct(explicitParams) || ~isfield(explicitParams, 'Intervals') || ...
            isempty(explicitParams.Intervals)
        error('CSRD:Scenario:MissingExplicitIntervals', ...
            ['TemporalBehavior.Explicit.Intervals is required when ', ...
             'PatternTypes selects Explicit.']);
    end

    raw = explicitParams.Intervals;
    if iscell(raw)
        if txIndex > numel(raw) || isempty(raw{txIndex})
            error('CSRD:Scenario:MissingExplicitIntervalsForTx', ...
                'Explicit intervals are missing for transmitter index %d.', ...
                txIndex);
        end
        intervals = raw{txIndex};
    else
        intervals = raw;
    end

    if ~isnumeric(intervals) || size(intervals, 2) ~= 2 || ...
            isempty(intervals) || any(~isfinite(intervals(:)))
        error('CSRD:Scenario:InvalidExplicitIntervals', ...
            'Explicit intervals must be a finite non-empty Nx2 numeric matrix.');
    end
    if any(intervals(:, 2) <= intervals(:, 1))
        error('CSRD:Scenario:InvalidExplicitIntervals', ...
            'Explicit intervals must have strictly positive durations.');
    end
    if any(intervals(:) < 0) || any(intervals(:) > observationDuration)
        error('CSRD:Scenario:InvalidExplicitIntervals', ...
            ['Explicit intervals must lie within [0, ObservationDuration] ', ...
             'seconds.']);
    end
    if size(intervals, 1) > 1 && any(intervals(2:end, 1) < intervals(1:end-1, 2))
        error('CSRD:Scenario:InvalidExplicitIntervals', ...
            'Explicit intervals must be sorted and non-overlapping per transmitter.');
    end
end

function intervals = generateBurstIntervals(pattern, observationDuration)
    % generateBurstIntervals - Production declaration in CSRD.
    % 中文说明：generateBurstIntervals 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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
    % generateScheduledIntervals - Production declaration in CSRD.
    % 中文说明：generateScheduledIntervals 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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
    % generateRandomIntervals - Production declaration in CSRD.
    % 中文说明：generateRandomIntervals 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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
