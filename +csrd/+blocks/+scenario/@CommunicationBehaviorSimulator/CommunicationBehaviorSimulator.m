classdef CommunicationBehaviorSimulator < matlab.System
    % CommunicationBehaviorSimulator - Communication Behavior Modeling and Simulation
    %
    % This class implements comprehensive communication behavior modeling for wireless
    % scenarios, including modulation scheme selection, frequency allocation, bandwidth
    % assignment, and temporal transmission patterns. It works in conjunction with
    % PhysicalEnvironmentSimulator to create complete scenario definitions.
    %
    % Key Features:
    %   - Dynamic modulation scheme selection from available factory configurations
    %   - Intelligent frequency allocation within receiver observable ranges
    %   - Adaptive bandwidth assignment based on communication requirements
    %   - Temporal transmission pattern modeling (continuous, burst, scheduled)
    %   - Interference modeling and collision avoidance
    %   - Power control and link budget calculations
    %   - Multi-user coordination and resource allocation
    %
    % Communication Modeling Components:
    %   1. Modulation Management: Selection and configuration of modulation schemes
    %   2. Frequency Planning: Spectrum allocation and interference management
    %   3. Temporal Behavior: Transmission timing and pattern control
    %   4. Power Management: Transmit power and link budget optimization
    %   5. Protocol Simulation: Communication protocol behavior modeling
    %
    % Syntax:
    %   simulator = CommunicationBehaviorSimulator('Config', config)
    %   [txConfigs, rxConfigs, allocations] = simulator(frameId, entities, factoryConfigs)
    %
    % Properties:
    %   Config - Communication behavior configuration structure
    %
    % Methods:
    %   step - Generate communication configurations for current frame
    %   setupImpl - Initialize communication behavior modeling
    %   allocateFrequencies - Perform frequency allocation for transmitters
    %   assignModulationSchemes - Select appropriate modulation schemes
    %   generateTransmissionPatterns - Create temporal transmission behaviors
    %
    % Example:
    %   config = struct();
    %   config.FrequencyAllocation.Strategy = 'ReceiverCentric';
    %   config.FrequencyAllocation.MinSeparation = 100e3; % Hz
    %   config.ModulationSelection.Strategy = 'Adaptive';
    %   config.TransmissionPattern.DefaultType = 'Continuous';
    %   config.PowerControl.Strategy = 'FixedPower';
    %
    %   simulator = csrd.blocks.scenario.CommunicationBehaviorSimulator('Config', config);
    %   [txConfigs, rxConfigs, allocations] = simulator(1, entities, factoryConfigs);

    properties
        % Config - Communication behavior configuration structure
        % Type: struct with comprehensive communication modeling parameters
        %
        % Configuration Structure:
        %   .FrequencyAllocation - Frequency planning configuration
        %     .Strategy - Allocation strategy. Phase 2 supports a single
        %                 value: 'ReceiverCentric'. The historical
        %                 'Optimized' and 'Random' values were thin
        %                 wrappers around 'ReceiverCentric' and were
        %                 removed in Phase 2 (see audit D7); any other
        %                 value now throws CSRD:Scenario:UnsupportedFrequencyStrategy.
        %     .MinSeparation - Minimum frequency separation between signals (Hz)
        %     .MaxOverlap - Maximum allowed frequency overlap ratio
        %     .GuardBands - Guard band specifications for interference protection
        %
        %   .ModulationSelection - Modulation scheme selection configuration
        %     .Strategy - Selection strategy ('Adaptive', 'Random', 'Fixed')
        %     .PreferredSchemes - Preferred modulation schemes for different scenarios
        %     .QualityThresholds - Quality thresholds for scheme selection
        %
        %   .TransmissionPattern - Temporal behavior configuration
        %     .DefaultType - Default transmission pattern ('Continuous', 'Burst', 'Scheduled')
        %     .BurstParameters - Burst transmission parameters
        %     .SchedulingRules - Scheduling rules for coordinated transmissions
        %
        %   .PowerControl - Power management configuration
        %     .Strategy - Power control strategy ('FixedPower', 'LinkBudget', 'Adaptive')
        %     .DefaultPower - Default transmit power levels (dBm)
        %     .MaxPower - Maximum allowed transmit power (dBm)
        %
        %   .InterferenceManagement - Interference handling configuration
        %     .EnableCollisionAvoidance - Enable automatic collision avoidance
        %     .InterferenceThreshold - Interference threshold for coordination
        %     .CoordinationStrategy - Multi-user coordination approach
        Config struct = struct()
    end

    properties (Access = private)
        % logger - Logging system for debugging and monitoring
        logger

        % unifiedReceiverConfig - Unified receiver configuration for all receivers
        % DESIGN: All spectrum monitoring receivers share the SAME configuration
        % to simplify spectrum sensing algorithm design by removing device heterogeneity
        % Structure:
        %   .Type - Receiver type (e.g., 'Simulation')
        %   .SampleRate - Unified sample rate (Hz)
        %   .ObservableRange - Observable frequency range [-SampleRate/2, SampleRate/2]
        %   .CenterFrequency - Center frequency (baseband = 0)
        %   .RealCarrierFrequency - Actual RF carrier frequency (Hz)
        %   .NumAntennas - Number of antennas
        unifiedReceiverConfig struct = struct()

        % scenarioTxConfigs - Fixed transmitter configurations for the entire scenario
        scenarioTxConfigs

        % scenarioRxConfigs - Fixed receiver configurations for the entire scenario
        scenarioRxConfigs

        % scenarioGlobalLayout - Fixed global layout for the entire scenario
        scenarioGlobalLayout

        % scenarioRegulatoryPlan - Phase 8 region/service-aware RF plan.
        % Empty when CommunicationBehavior.Regulatory.Enable is false.
        scenarioRegulatoryPlan struct = struct()

        % scenarioEntities - Reference to entities with Snapshots (shared with PhysicalEnv)
        scenarioEntities

        % transmissionScheduler - Transmission scheduling engine for frame-level control
        transmissionScheduler

        % allocationHistory - History of previous frame states for continuity
        allocationHistory containers.Map

        % scenarioInitialized - Flag indicating if scenario-level configs are set
        scenarioInitialized logical = false
    end

    methods

        function obj = CommunicationBehaviorSimulator(varargin)
            % CommunicationBehaviorSimulator - Constructor for communication behavior simulator
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            %
            % Creates a new communication behavior simulator with configurable
            % frequency allocation, modulation selection, and transmission pattern
            % modeling capabilities.
            %
            % Syntax:
            %   obj = CommunicationBehaviorSimulator()
            %   obj = CommunicationBehaviorSimulator('Config', configStruct)
            %   obj = CommunicationBehaviorSimulator('PropertyName', PropertyValue, ...)

            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)
        % Main simulation methods - defined in separate files
        setupImpl(obj)
        [txConfigs, rxConfigs, globalLayout] = stepImpl(obj, frameId, entities)
    end

    methods (Static, Hidden)
        function rvs = projectReceiverViews(txSpectrum, rxConfigs, fallbackObservableRange)
            % projectReceiverViews - Phase 3 ReceiverView projection algorithm
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            %
            %   Given an emitter's placed Spectrum struct (PlannedFreqOffset
            %   + PlannedBandwidth) and the array of receiver configs, returns
            %   a struct array of canonical 5-field ReceiverView entries
            %   (audit §3.1.ter A / phase-3-construction.md §3.1.A):
            %     ReceiverId / ProjectedCenterOffsetHz / ProjectedLowerEdgeHz
            %     / ProjectedUpperEdgeHz / IsVisible / VisibilityReason.
            %
            %   Inputs:
            %     txSpectrum              - struct with fields PlannedBandwidth
            %                                and PlannedFreqOffset (Hz)
            %     rxConfigs               - cell array OR struct array of rx
            %                                configs (each may carry EntityID
            %                                and Observation.ObservableRange)
            %     fallbackObservableRange - retained only for API stability;
            %                                every receiver must carry its own
            %                                ObservableRange.
            %
            %   Phase 3 unified-receiver contract (§3.1.A): every Receiver
            %   shares the same Observation.CenterFrequency, so the
            %   ProjectedCenterOffsetHz equals txSpectrum.PlannedFreqOffset
            %   for every (Tx, Rx) pair. Phase 4 will swap this for true
            %   heterogeneous-rx CenterFrequency arithmetic without changing
            %   the schema.
            %
            %   Hidden + Static so unit tests can drive the algorithm
            %   without spinning up a full simulator pipeline.

            if ~isstruct(txSpectrum) || ~isfield(txSpectrum, 'PlannedBandwidth') ...
                    || ~isfield(txSpectrum, 'PlannedFreqOffset')
                error('CSRD:Scenario:MissingSpectrum', ...
                    ['projectReceiverViews: txSpectrum must contain ', ...
                     'PlannedBandwidth and PlannedFreqOffset fields.']);
            end

            rxList = csrd.blocks.scenario.CommunicationBehaviorSimulator ...
                .normalizeReceiverList(rxConfigs);

            rvs = struct('ReceiverId',              {}, ...
                          'ProjectedCenterOffsetHz', {}, ...
                          'ProjectedLowerEdgeHz',    {}, ...
                          'ProjectedUpperEdgeHz',    {}, ...
                          'IsVisible',               {}, ...
                          'VisibilityReason',        {});

            halfBw = txSpectrum.PlannedBandwidth / 2;
            placedOffset = txSpectrum.PlannedFreqOffset;
            for m = 1:numel(rxList)
                rxc = rxList{m};
                rxId = '';
                if isstruct(rxc) && isfield(rxc, 'EntityID') && ischar(rxc.EntityID)
                    rxId = rxc.EntityID;
                end
                rxRange = csrd.blocks.scenario.CommunicationBehaviorSimulator ...
                    .resolveObservableRange(rxc, fallbackObservableRange);
                halfWin = (rxRange(2) - rxRange(1)) / 2;

                % Phase 3 unified-rx case: identical CenterFrequency
                % across every receiver, so the projection equals the
                % placed offset.
                projOffset = placedOffset;
                lowerEdge  = projOffset - halfBw;
                upperEdge  = projOffset + halfBw;

                absCenter = abs(projOffset);
                if absCenter + halfBw <= halfWin + 1
                    isVis  = true;
                    reason = 'InBand';
                elseif absCenter - halfBw < halfWin
                    isVis  = false;
                    reason = 'EdgeClipped';
                else
                    isVis  = false;
                    reason = 'OutOfBand';
                end

                rvs(end + 1) = struct( ...
                    'ReceiverId',              rxId, ...
                    'ProjectedCenterOffsetHz', projOffset, ...
                    'ProjectedLowerEdgeHz',    lowerEdge, ...
                    'ProjectedUpperEdgeHz',    upperEdge, ...
                    'IsVisible',               isVis, ...
                    'VisibilityReason',        reason); %#ok<AGROW>
            end
        end

        function out = normalizeReceiverList(rxConfigs)
            % normalizeReceiverList - Internal helper for projectReceiverViews.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            if iscell(rxConfigs)
                out = rxConfigs(:)';
            elseif isstruct(rxConfigs)
                out = arrayfun(@(k) rxConfigs(k), 1:numel(rxConfigs), ...
                    'UniformOutput', false);
            else
                out = {};
            end
        end

        function r = resolveObservableRange(rxc, fallbackRange) %#ok<INUSD>
            % resolveObservableRange - Internal helper for projectReceiverViews.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            if ~isstruct(rxc)
                error('CSRD:Scenario:MissingReceiverObservableRange', ...
                    'Receiver config must be a struct with ObservableRange.');
            end
            if isfield(rxc, 'Observation') && isstruct(rxc.Observation) ...
                    && isfield(rxc.Observation, 'ObservableRange') ...
                    && isnumeric(rxc.Observation.ObservableRange) ...
                    && numel(rxc.Observation.ObservableRange) == 2
                r = rxc.Observation.ObservableRange;
                r = localValidateObservableRange(r);
                return
            end
            if isfield(rxc, 'ObservableRange') ...
                    && isnumeric(rxc.ObservableRange) ...
                    && numel(rxc.ObservableRange) == 2
                r = rxc.ObservableRange;
                r = localValidateObservableRange(r);
                return
            end
            error('CSRD:Scenario:MissingReceiverObservableRange', ...
                ['ReceiverView projection requires each receiver to carry ', ...
                 'Observation.ObservableRange or ObservableRange.']);
        end

        function validateFrequencyAllocationStrategy(strategyName)
            % validateFrequencyAllocationStrategy - Phase 2 (D7) strategy gate.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            %
            %   Phase 2 collapses FrequencyAllocation.Strategy down to the
            %   single supported value 'ReceiverCentric'. The legacy
            %   'Optimized' / 'Random' wrappers and the unknown-strategy
            %   silent fallback in performScenarioFrequencyAllocation have
            %   been removed (audit §3.5). Anything other than
            %   'ReceiverCentric' must fail fast here so misconfigured
            %   pipelines raise a deterministic, identifiable error
            %   instead of silently degrading to ReceiverCentric.
            %
            %   Exposed as a Hidden static method so unit tests can drive
            %   the gate without spinning up a full simulator pipeline.
            isCharRow = ischar(strategyName) && (isempty(strategyName) || isrow(strategyName));
            isStringScalar = isstring(strategyName) && isscalar(strategyName);
            if ~(isCharRow || isStringScalar)
                error('CSRD:Scenario:UnsupportedFrequencyStrategy', ...
                    ['FrequencyAllocation.Strategy must be a char row or string scalar ', ...
                     'equal to ''ReceiverCentric''; got class %s instead. ', ...
                     '''Optimized'' / ''Random'' were thin wrappers and were removed in Phase 2.'], ...
                    class(strategyName));
            end
            if ~strcmp(char(strategyName), 'ReceiverCentric')
                error('CSRD:Scenario:UnsupportedFrequencyStrategy', ...
                    ['FrequencyAllocation.Strategy=''%s'' is no longer supported. ', ...
                     'Only ''ReceiverCentric'' is available; ''Optimized'' / ''Random'' ', ...
                     'were thin wrappers and have been removed in Phase 2.'], ...
                    char(strategyName));
            end
        end
    end

    methods (Access = private)
        % Scenario-level configuration methods
        entities = initializeScenarioConfigurations(obj, entities)
        [txConfigs, rxConfigs, globalLayout] = generateFrameConfigurations(obj, frameId, entities)

        % Entity processing methods
        [transmitters, receivers] = separateEntitiesByType(obj, entities)
        rxConfigs = generateScenarioReceiverConfigurations(obj, receivers)
        [txConfigs, globalLayout] = generateScenarioTransmitterConfigurations(obj, transmitters, rxConfigs)
        entities = updateEntityCommunicationState(obj, entities, txConfigs, rxConfigs)

        % Frequency allocation methods
        % Phase 2 (D7): single strategy only ('ReceiverCentric').
        % Phase 3 (§3.1): rxConfigs threaded through so per-Rx
        % ReceiverViews can be projected on top of the placed offset.
        [txConfigs, globalLayout] = performScenarioFrequencyAllocation(obj, txConfigs, rxConfigs, observableRange, globalLayout)
        [txConfigs, globalLayout] = allocateFrequenciesReceiverCentric(obj, txConfigs, rxConfigs, observableRange, globalLayout)
        [txConfigs, globalLayout] = allocateFrequenciesFromRegulatoryPlan(obj, txConfigs, rxConfigs, observableRange, globalLayout)

        % Transmission state methods
        transmissionState = calculateTransmissionState(obj, frameId, txConfig)

        % Configuration generation methods
        gain = calculateAntennaGain(obj, numAntennas)
        bandwidth = calculateRequiredBandwidth(obj, modulationConfig)

        % Utility methods
        hasOverlap = checkFrequencyOverlap(obj, range1, range2)
        value = randomInRange(obj, minVal, maxVal)

        % Component initialization methods
        initializeTransmissionScheduler(obj)
        config = getDefaultConfiguration(obj)
    end

end

function r = localValidateObservableRange(r)
    % localValidateObservableRange - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    r = double(reshape(r, 1, 2));
    if any(~isfinite(r)) || r(2) <= r(1)
        error('CSRD:Scenario:InvalidReceiverObservableRange', ...
            'Receiver ObservableRange must be finite and strictly increasing.');
    end
end
