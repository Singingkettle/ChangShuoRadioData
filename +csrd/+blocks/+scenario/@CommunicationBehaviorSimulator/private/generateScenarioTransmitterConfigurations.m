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
        % Transmit power follows the regulatory service class (broadcast
        % towers high, short-range devices low) when regulatory planning is
        % active; otherwise it falls back to the flat scenario range.
        if regulatoryEnabled && isfield(regulatoryEmitterPlan, 'PowerDbmRange') && ...
                numel(regulatoryEmitterPlan.PowerDbmRange) == 2 && ...
                all(isfinite(regulatoryEmitterPlan.PowerDbmRange))
            txPlan.Hardware.Power = randomInRange(obj, ...
                regulatoryEmitterPlan.PowerDbmRange(1), ...
                regulatoryEmitterPlan.PowerDbmRange(2));
        else
            txPlan.Hardware.Power = randomInRange(obj, ...
                txParams.Power.Min, txParams.Power.Max);
        end

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
            txPlan.Modulation, totalTxDuration, msgParams, txPlan.EntityID);

        txConfigs{end+1} = txPlan;
    end

    % Perform frequency allocation for all transmitters
    [txConfigs, globalLayout] = performScenarioFrequencyAllocation(obj, txConfigs, ...
        rxConfigs, observableRange, globalLayout);
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

function params = getTransmitterParams(config)
    % getTransmitterParams - Extract transmitter parameters from config
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.

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
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
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
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
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
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    
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

    if isfield(config, 'ScenarioPlan') && isstruct(config.ScenarioPlan) && ...
            isfield(config.ScenarioPlan, 'Frame') && ...
            isstruct(config.ScenarioPlan.Frame)
        framePlan = config.ScenarioPlan.Frame;
        if isfield(framePlan, 'ObservationDurationSec')
            params.ObservationDuration = framePlan.ObservationDurationSec;
        end
        if isfield(framePlan, 'NumFramesPerScenario')
            params.NumFramesPerScenario = framePlan.NumFramesPerScenario;
        end
    end
    if isempty(params.ObservationDuration) || isempty(params.NumFramesPerScenario)
        error('CSRD:ScenarioPlan:MissingFrameContract', ...
            ['CommunicationBehavior requires ScenarioPlan.Frame.', ...
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
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
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
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
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
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    % Phase 8 service-driven modulation family before the blueprint
    % validator sees it.
    family = char(string(modulationFamily));
    minAnt = numAntennaRange.Min;
    maxAnt = numAntennaRange.Max;
    % OTFS is single-antenna-only in AntennaModulationMatrix ('OTFS' is
    % Allowed at 1 antenna, Forbidden at 2/4/8/16); without it here the planner
    % draws 2/4 antennas for OTFS, the blueprint validator rejects it, and the
    % scenario is resampled up to 50 times (wasteful, and risks exhausting the
    % resample budget). Keep this list consistent with the antenna matrix.
    singleAntennaFamilies = {'FM','PM','AM','SSBAM','DSBAM','DSBSCAM','VSBAM', ...
        'FSK','MSK','CPFSK','GFSK','GMSK','OOK','PAM','OTFS'};
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
    % Draw only from valid antenna bins ([1 2 4 8 16]); a raw integer range
    % would yield non-bin counts (e.g. 3) that the blueprint validator rejects,
    % wasting resample attempts and intermittently failing high-Tx scenarios.
    antennaBins = [1 2 4 8 16];
    candidates = antennaBins(antennaBins >= minAllowed & antennaBins <= maxAllowed);
    if isempty(candidates)
        error('CSRD:Scenario:InvalidTxAntennaRange', ...
            ['Transmitter.NumAntennas range [%g, %g] contains no valid antenna ', ...
             'bin from [1 2 4 8 16].'], minAnt, maxAnt);
    end
    numAntennas = candidates(randi(numel(candidates)));
end

function pattern = applyRegulatoryTemporalPattern(pattern, temporalPattern)
    % applyRegulatoryTemporalPattern - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
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
            % Realize a repeating ON/OFF train (not a single full-front block)
            % so later frames see the periodic emitter the 'Burst' label
            % promises, instead of going silent after one block.
            pattern.OnDuration = obsDur * 0.2;
            pattern.OffDuration = obsDur * 0.2;
            pattern.InitialDelay = 0;
            pattern.DutyCycle = pattern.OnDuration / ...
                (pattern.OnDuration + pattern.OffDuration);
            pattern.Intervals = generateBurstIntervals(pattern, obsDur);
        case 'Scheduled'
            % Realize a genuinely intermittent (slotted) emission so the signal
            % matches the 'Scheduled' label, instead of a single full-window
            % slot ([0, obsDur]) that is indistinguishable from a Continuous
            % emitter while the annotation still advertises 'Scheduled'.
            pattern.SlotDuration = obsDur * 0.2;
            pattern.NumSlots = 4;
            pattern.AssignedSlot = 1;
            pattern.DutyCycle = 1 / pattern.NumSlots;
            pattern.Intervals = generateScheduledIntervals(pattern, obsDur);
    end
    % Guard against a degenerate rebuild collapsing to the no-activity
    % sentinel: fall back to a truthful continuous emission rather than an
    % empty/idle one mislabelled as Burst/Scheduled.
    if isempty(pattern.Intervals) || ...
            (size(pattern.Intervals, 1) == 1 && all(pattern.Intervals(1, :) == 0))
        pattern.Type = 'Continuous';
        pattern.DutyCycle = 1.0;
        pattern.Intervals = [0, obsDur];
    end
end

function totalDuration = calculateTotalTransmissionDuration(transmissionPattern)
    % calculateTotalTransmissionDuration - Sum up all transmission intervals
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    
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
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
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
    
    % Calculate symbol rate from bandwidth, then snap it to an integer
    % submultiple of the receiver sample rate. This keeps the Tx RF chain's
    % modulator->receiver resample ratio a small, exact rational (the
    % regulatory path achieves the same implicitly through discrete catalog
    % bandwidths; the legacy continuous-bandwidth path would otherwise yield
    % an intractable rational and fail in TRFSimulator.resampleToTarget).
    modConfig.SymbolRate = snapSymbolRateToReceiverGrid(obj, ...
        bandwidth / (1 + rolloffFactor));

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

function symbolRate = snapSymbolRateToReceiverGrid(obj, rawSymbolRate)
    % snapSymbolRateToReceiverGrid - Snap symbol rate to a receiver submultiple.
    % Inputs: communication simulator, raw symbol rate (Hz).
    % Outputs: nearest symbol rate of the form ReceiverSampleRate / integer, so
    %   the modulator-to-receiver resample ratio stays a small exact rational.
    receiverRate = obj.unifiedReceiverConfig.SampleRate;
    divisor = max(1, round(receiverRate / rawSymbolRate));
    symbolRate = receiverRate / divisor;
end

function symbolRate = snapNarrowSymbolRateToReceiverGrid(obj, rawSymbolRate)
    % snapNarrowSymbolRateToReceiverGrid - Snap only narrow rates to the grid.
    % Inputs: communication simulator, raw symbol rate (Hz).
    % Outputs: for narrow channels (receiver-submultiple divisor >= 50, i.e. a
    %   bandwidth distortion under ~2%), the nearest exact ReceiverSampleRate /
    %   integer; wider channels are returned unchanged so the regulatory
    %   catalog bandwidth is preserved exactly. Narrow odd channels such as the
    %   8.33 kHz airband otherwise produce an intractable modulator-to-receiver
    %   resample ratio in TRFSimulator.
    receiverRate = obj.unifiedReceiverConfig.SampleRate;
    divisor = max(1, round(receiverRate / rawSymbolRate));
    if divisor >= 50
        symbolRate = receiverRate / divisor;
    else
        symbolRate = rawSymbolRate;
    end
end

function modConfig = generateRegulatoryModulationConfig(obj, bandwidth, modParams, emitterPlan)
    % generateRegulatoryModulationConfig - Generate modulation config from a
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    % regulatory service plan rather than from an unconstrained type list.
    modConfig = struct();
    modConfig.Type = char(string(emitterPlan.ModulationFamily));
    modConfig.Family = modConfig.Type;
    modConfig.Order = double(emitterPlan.ModulationOrder);
    modConfig.RolloffFactor = modParams.RolloffFactor;
    modConfig.OFDMMimoMode = modParams.OFDMMimoMode;
    % Narrow channels (e.g. 8.33 kHz airband) whose rate shares no factors with
    % the receiver rate would yield an intractable modulator->receiver resample
    % ratio in TRFSimulator. Snap only narrow rates onto an exact receiver
    % submultiple (sub-2% bandwidth shift); wide channels keep their exact
    % catalog bandwidth.
    modConfig.SymbolRate = snapNarrowSymbolRateToReceiverGrid(obj, ...
        bandwidth / (1 + modParams.RolloffFactor));
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

function [fftLength, guard, scs, cpLen] = localOfdmGridForBandwidth(bandwidth)
    % localOfdmGridForBandwidth - standards-faithful OFDM grid that tracks the
    % planned channel bandwidth. Subcarrier spacing is FIXED at the LTE/5G-NR
    % numerology-0 value (15 kHz); the FFT size and the number of used
    % subcarriers scale with the bandwidth, so realized OBW = usableBins*scs
    % approximates the planned bandwidth. The previous code instead inflated the
    % spacing on a FIXED 1760-bin grid with a max(15 kHz, .) floor, which pinned
    % realized OBW to 1760*15 kHz = 26.4 MHz for every channel <= 26.4 MHz.
    scs = 15e3;
    numUsed = max(12, round(bandwidth / scs));         % used (data+pilot) subcarriers
    fftSet = [256, 512, 1024, 2048, 4096];             % comm.OFDMModulator-supported sizes
    idx = find(fftSet >= numUsed / 0.85, 1);           % leave ~15% for guard bands
    if isempty(idx)
        fftLength = fftSet(end);                       % clamp: > 4096 unsupported
        numUsed = min(numUsed, round(0.85 * fftLength));
    else
        fftLength = fftSet(idx);
    end
    guard = max(1, round((fftLength - numUsed) / 2));  % so usableBins = fft-2*guard ~= numUsed
    cpLen = round(fftLength / 14);                      % ~7% cyclic prefix (LTE normal CP)
end

function modulatorConfig = buildRegulatoryModulatorConfig(modConfig, bandwidth)
    % buildRegulatoryModulatorConfig - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    modulatorConfig = struct();
    switch char(string(modConfig.Type))
        case 'OFDM'
            [fftLength, guard, subcarrierSpacing, cpLen] = ...
                localOfdmGridForBandwidth(bandwidth);

            modulatorConfig.base.mode = "qam";
            modulatorConfig.ofdm.FFTLength = fftLength;
            modulatorConfig.ofdm.NumGuardBandCarriers = [guard; guard];
            modulatorConfig.ofdm.InsertDCNull = true;
            modulatorConfig.ofdm.CyclicPrefixLength = cpLen;
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
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    modulatorConfig = struct();
    switch char(string(modConfig.Type))
        case 'OFDM'
            [fftLength, guard, subcarrierSpacing, cpLen] = ...
                localOfdmGridForBandwidth(bandwidth);

            modulatorConfig.base.mode = "qam";
            modulatorConfig.ofdm.FFTLength = fftLength;
            modulatorConfig.ofdm.NumGuardBandCarriers = [guard; guard];
            modulatorConfig.ofdm.InsertDCNull = true;
            modulatorConfig.ofdm.CyclicPrefixLength = cpLen;
            modulatorConfig.ofdm.Subcarrierspacing = subcarrierSpacing;
            modulatorConfig.ofdm.Windowing = false;
            modulatorConfig.mimo.Mode = localValidateOFDMMimoMode(modConfig);
        case 'OTFS'
            % Realized OBW = (DelayLength-8)*scs. Fix the spacing at 15 kHz and
            % scale the delay grid with the planned bandwidth so OBW tracks it,
            % instead of the max(15 kHz, .) floor on a fixed 512-bin grid that
            % pinned OBW to 504*15 kHz = 7.56 MHz for every channel <= 7.56 MHz.
            subcarrierSpacing = 15e3;
            delayLength = max(16, round(bandwidth / subcarrierSpacing) + 8);

            modulatorConfig.base.mode = "qam";
            modulatorConfig.otfs.DelayLength = delayLength;
            modulatorConfig.otfs.Subcarrierspacing = subcarrierSpacing;
            modulatorConfig.otfs.padType = "CP";
            modulatorConfig.otfs.padLen = 16;
        case 'SCFDMA'
            % Realized OBW = NumDataSubcarriers*scs. Scale the FFT + used
            % subcarriers with the planned bandwidth at a fixed 15 kHz spacing
            % (same grid as OFDM), instead of the max(15 kHz, .) floor on a fixed
            % 300-subcarrier grid that pinned OBW to 300*15 kHz = 4.5 MHz.
            [fftLength, guard, subcarrierSpacing, cpLen] = ...
                localOfdmGridForBandwidth(bandwidth);
            dataSubcarriers = fftLength - 2 * guard;

            modulatorConfig.base.mode = "qam";
            modulatorConfig.scfdma.FFTLength = fftLength;
            modulatorConfig.scfdma.CyclicPrefixLength = cpLen;
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
    % Inputs: modulation config with optional OFDMMimoMode.
    % Outputs: validated mode string stored in ModulatorConfig.mimo.Mode.
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

function msgConfig = generateMessageConfig(~, modulationConfig, txDuration, msgParams, emitterId)
    % generateMessageConfig - Generate message config from scenario params
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    % Message Length Calculation:
    %   Length = SymbolRate × BitsPerSymbol × TransmissionDuration
    %
    % Message source is a deterministic function of the modulation family,
    % never a random draw: analog families (FM/PM/AM variants) must use the
    % continuous audio source, digital families must use the random bit
    % source. Feeding a 0/1 bit stream to an analog modulator (which scales
    % or integrates a continuous baseband) produces a physically meaningless
    % waveform, so the binding is enforced here rather than sampled from a
    % configured type list.

    msgConfig = struct();

    % Resolve message source from the modulation family (analog -> Audio,
    % digital -> RandomBit). msgParams.Types is no longer used for selection;
    % it only documents the registered sources for legacy callers.
    modulationFamily = '';
    if isfield(modulationConfig, 'Family') && ~isempty(modulationConfig.Family)
        modulationFamily = char(string(modulationConfig.Family));
    elseif isfield(modulationConfig, 'Type') && ~isempty(modulationConfig.Type)
        modulationFamily = char(string(modulationConfig.Type));
    end
    if isempty(modulationFamily)
        error('CSRD:Scenario:MissingModulationFamilyForMessage', ...
            ['generateMessageConfig requires the modulation family to bind ', ...
             'the message source; modulationConfig.Type/Family is empty.']);
    end
    msgConfig.Type = csrd.support.modulation.messageSourceForModulation(modulationFamily);
    msgConfig.ModulationFamily = modulationFamily;
    msgConfig.IsDigital = ~csrd.support.modulation.isAnalogModulationFamily(modulationFamily);

    % Analog emitters draw their audio clip deterministically from a
    % per-emitter seed so different transmitters carry different program
    % material while a fixed scenario seed always reproduces the same clip.
    if strcmp(msgConfig.Type, 'Audio')
        if nargin < 5 || isempty(emitterId)
            emitterId = '';
        end
        msgConfig.Seed = csrd.support.hash.shortInt32Hash( ...
            sprintf('AudioSelect|%s|%s', char(string(emitterId)), modulationFamily));
    end

    % Calculate message length based on symbol rate and duration.
    symbolRate = modulationConfig.SymbolRate;
    bitsPerSymbol = modulationConfig.BitsPerSymbol;

    if msgConfig.IsDigital
        % Digital: the source is bits; the modulator groups them into symbols
        % and upsamples by SamplesPerSymbol, so the SPS factor cancels and the
        % required bit-count is symbolRate*bitsPerSymbol*duration (+margin).
        calculatedLength = ceil(symbolRate * bitsPerSymbol * txDuration * 1.1);
    else
        % Analog (FM/PM/AM ...): the source (audio) is modulated sample-by-sample
        % at the modulator rate symbolRate*SamplesPerSymbol with NO upsampling,
        % so the source must supply that many samples to cover the burst.
        % Without the SamplesPerSymbol factor the produced signal is only
        % ~1/SamplesPerSymbol of the segment and gateToDuration zero-pads the
        % rest with silence (45-86% of every analog burst).
        samplesPerSymbol = 1;
        if isfield(modulationConfig, 'SamplesPerSymbol') && ...
                ~isempty(modulationConfig.SamplesPerSymbol) && ...
                isfinite(modulationConfig.SamplesPerSymbol) && ...
                modulationConfig.SamplesPerSymbol > 0
            samplesPerSymbol = double(modulationConfig.SamplesPerSymbol);
        end
        calculatedLength = ceil(symbolRate * samplesPerSymbol * txDuration * 1.1);
    end
    
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
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
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
            case {'APSK', 'DVBSAPSK'}
                orders = [16, 32, 64, 128, 256];  % ring constellations need >= 16
            case 'Mill88QAM'
                orders = [16, 32, 64, 256];
            case 'OTFS'
                orders = [4, 16, 64];  % inner QAM/PSK order
            case {'ASK', 'PAM', 'SCFDMA'}
                orders = [4, 8, 16, 32, 64];
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
    if ~csrd.support.modulation.isAnalogModulationFamily(modType) && order < 2
        order = 2;
    end
end

function pattern = generateTemporalPattern(obj, temporalParams, txIndex)
    % generateTemporalPattern - Generate temporal transmission pattern
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    
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
            % Only slots whose start lies inside the observation window produce
            % a real interval; assigning a later slot returns the empty [0,0]
            % sentinel, which the fallback below would otherwise turn into a
            % CONTINUOUS emission still labelled 'Scheduled' (signal contradicts
            % annotation). Clamp the assigned slot to the startable range so the
            % emitter is a truthful slotted one.
            maxStartableSlot = max(1, ceil(obsDur / pattern.SlotDuration));
            pattern.AssignedSlot = randi(min(pattern.NumSlots, maxStartableSlot));
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

    % Guarantee at least one active interval inside the observation window.
    % generateBurst/Scheduled/Random return the [0, 0] no-activity sentinel
    % for very short observations; without a fallback a planned transmitter
    % would silently emit an all-idle (zero-source) scenario.
    if isempty(pattern.Intervals) || ...
            (size(pattern.Intervals, 1) == 1 && all(pattern.Intervals(1, :) == 0))
        % A degenerate pattern collapsed to the no-activity sentinel. The
        % fallback emits continuously across the window, so relabel the pattern
        % as Continuous to keep the annotation's Type/DutyCycle truthful to the
        % realized signal instead of advertising a slotted/bursty emitter that
        % never existed.
        pattern.Type = 'Continuous';
        pattern.DutyCycle = 1.0;
        pattern.StartTime = 0;
        pattern.EndTime = temporalParams.ObservationDuration;
        pattern.Intervals = [0, temporalParams.ObservationDuration];
    end
end

function intervals = selectExplicitIntervals(explicitParams, txIndex, observationDuration)
    % selectExplicitIntervals - Resolve per-transmitter explicit bursts.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
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
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
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
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
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
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
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
