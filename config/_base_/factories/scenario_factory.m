function config = scenario_factory()
    % scenario_factory - Scenario factory configuration (Blueprint)
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    % This is the "blueprint" configuration that defines SCENARIO-LEVEL parameters.
    % 
    % DESIGN PRINCIPLE:
    %   - This config is SELF-CONTAINED for scenario planning
    %   - Scenario planning does NOT access other factory configs
    %   - Defines "WHAT categories" to select from (Types lists)
    %   - Factory configs define "HOW each category works" (implementation details)
    %
    % The scenario defines THREE dimensions:
    %   1. SPATIAL: Map type, entity counts, positions, mobility
    %   2. TEMPORAL: Observation duration, transmission patterns
    %   3. FREQUENCY: Sample rates, bandwidths, frequency allocation
    %
    % MAP & CHANNEL MODELING (Two Approaches):
    %   1. Statistical: Virtual scene + statistical channel models (fast)
    %   2. OSM: Real OpenStreetMap + ray tracing channel models (accurate)
    %
    % TYPE SELECTION:
    %   - Map/Channel type: Statistical vs OSM (with selection ratio)
    %   - Transmitter/Receiver types: Selected here, implementation in tx/rx factory
    %   - Modulation types: Selected here, orders/details in modulation factory
    %   - Message types: Selected here, parameters in message factory
    
    %% ═══════════════════════════════════════════════════════════════════════
    %%                           METADATA
    %% ═══════════════════════════════════════════════════════════════════════
    config.Factories.Scenario.Description = 'Scenario blueprint configuration';
    config.Factories.Scenario.Version = '2025.3.0';
    config.Factories.Scenario.Architecture = 'Blueprint-Factory';
    
    %% ═══════════════════════════════════════════════════════════════════════
    %%                    SCENARIO FRAME POLICY
    %% ═══════════════════════════════════════════════════════════════════════
    %
    % Phase 33: frame shape is a per-scenario construction-plan fact.
    % The run-level RuntimePlan stores this policy only; ScenarioFactory
    % resolves concrete frame samples and frame count before each scenario
    % begins. All receivers within the same scenario share the resolved
    % frame shape so receiver-frame annotations remain directly comparable.

    config.Factories.Scenario.FramePolicy.FrameNumSamples.Mode = 'Choice';
    config.Factories.Scenario.FramePolicy.FrameNumSamples.Values = [1024, 2048, 4096];
    config.Factories.Scenario.FramePolicy.FrameNumSamples.Weights = [0.5, 0.3, 0.2];

    config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Mode = 'IntegerRange';
    config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Min = 4;
    config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Max = 10;
    
    %% ═══════════════════════════════════════════════════════════════════════
    %%                    PHYSICAL ENVIRONMENT (SPATIAL)
    %% ═══════════════════════════════════════════════════════════════════════
    
    % ===================== MAP & CHANNEL MODELING =====================
    %
    % Two approaches for scene modeling and channel simulation:
    %
    % 1. STATISTICAL (Virtual Scene + Statistical Channel Model)
    %    - Creates a virtual 3D scene with random entity placement
    %    - Uses statistical channel models (Rayleigh, Rician, etc.)
    %    - Faster computation, suitable for large-scale simulations
    %
    % 2. OSM (Real Map + Ray Tracing Channel Model)
    %    - Uses real OpenStreetMap data for accurate building geometry
    %    - Uses ray tracing for physically accurate channel modeling
    %    - More realistic but computationally intensive
    %
    % The ratio determines how often each approach is selected:
    
    config.Factories.Scenario.PhysicalEnvironment.Map.Types = {'Statistical', 'OSM'};
    config.Factories.Scenario.PhysicalEnvironment.Map.Ratio = [0.1, 0.9];
    
    % --- Statistical Scene Configuration ---
    % Virtual scene with statistical channel modeling
    config.Factories.Scenario.PhysicalEnvironment.Map.Statistical.Boundaries = [-2000, 2000, -2000, 2000]; % [xmin, xmax, ymin, ymax] meters
    config.Factories.Scenario.PhysicalEnvironment.Map.Statistical.Resolution = 100;  % meters per grid cell
    config.Factories.Scenario.PhysicalEnvironment.Map.Statistical.ChannelModel = 'Statistical';  % Uses statistical fading models
    
    % --- OSM Scene Configuration ---
    % Real map with ray tracing channel modeling
    currentFilePath = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(fileparts(fileparts(currentFilePath)));
    config.Factories.Scenario.PhysicalEnvironment.Map.OSM.DataDirectory = fullfile(projectRoot, 'data', 'map', 'osm');
    config.Factories.Scenario.PhysicalEnvironment.Map.OSM.FilePattern = '*.osm';
    config.Factories.Scenario.PhysicalEnvironment.Map.OSM.SpecificFile = '';  % Empty = random selection from DataDirectory
    config.Factories.Scenario.PhysicalEnvironment.Map.OSM.ChannelModel = 'RayTracing';  % Uses ray tracing propagation
    config.Factories.Scenario.PhysicalEnvironment.Map.OSM.EmptyGeometryPolicy = 'FlatTerrain';
    config.Factories.Scenario.PhysicalEnvironment.Map.OSM.FlatTerrain.Terrain = 'none';
    config.Factories.Scenario.PhysicalEnvironment.Map.OSM.FlatTerrain.Material = 'seawater';
    config.Factories.Scenario.PhysicalEnvironment.Map.OSM.FlatTerrain.MaxNumReflections = 1;
    
    
    % --- Entity Counts (Scenario-level) ---
    config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min = 1;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = 8;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Height.Min = 10;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Height.Max = 100;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.InitialDistribution = 'Random';
    
    config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Mobility.Model = 'ConstantVelocity';
    config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Mobility.MaxSpeed.Min = 0;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Mobility.MaxSpeed.Max = 30;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Mobility.AccelerationRange = [-2, 2];
    
    config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = 1;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = 4;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Height.Min = 5;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Height.Max = 50;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.InitialDistribution = 'Random';
    
    config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Mobility.Model = 'Stationary';
    config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Mobility.MaxSpeed.Min = 0;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Mobility.MaxSpeed.Max = 0;
    
    % --- Environment ---
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Enable = true;
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Temperature = 20;
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Humidity = 50;
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Pressure = 1013;
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.WindSpeed = 0;
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.WindDirection = 0;
    
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.TemperatureRange = [-40, 60];
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.HumidityRange = [0, 100];
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.PressureRange = [900, 1100];
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.WindSpeedRange = [0, 50];
    
    config.Factories.Scenario.PhysicalEnvironment.Environment.Obstacles.Enable = true;
    
    %% ═══════════════════════════════════════════════════════════════════════
    %%                    COMMUNICATION BEHAVIOR
    %% ═══════════════════════════════════════════════════════════════════════
    
    % ===================== UNIFIED RECEIVER CONFIGURATION =====================
    % DESIGN: All spectrum monitoring receivers share the SAME configuration
    % This simplifies spectrum sensing algorithm design by removing device heterogeneity
    %
    % The SampleRate determines the observable frequency range: [-SampleRate/2, SampleRate/2]
    % A single unified value is used for ALL receivers in the scenario
    config.Factories.Scenario.CommunicationBehavior.Receiver.Type = 'Simulation';
    config.Factories.Scenario.CommunicationBehavior.Receiver.SampleRate = 50e6;  % Hz (unified)
    config.Factories.Scenario.CommunicationBehavior.Receiver.CenterFrequency = 0;  % baseband
    config.Factories.Scenario.CommunicationBehavior.Receiver.RealCarrierFrequency = 2.4e9;  % Hz
    config.Factories.Scenario.CommunicationBehavior.Receiver.NumAntennas = 1;  % unified
    % NOTE: NoiseFigure, Sensitivity, AntennaGain detail params are in receive_factory.m

    % ===================== SDR RECEIVER CAPABILITY =====================
    % The monitoring receiver behaves like a real software-defined radio.
    % The selected model's capability profile (tuning range, max instantaneous
    % bandwidth, ADC bits, noise figure, channel count) bounds the scenario:
    %   - the unified SampleRate (the captured IBW) is capped to the model IBW
    %   - the unified NumAntennas is capped to the model channel count
    %   - the monitoring band center must lie inside the model tuning range
    % Supported models live in csrd.catalog.receiver.SdrReceiverCatalog
    % (USRP_B210, USRP_N310, BladeRF_2, HackRF_One, RTL_SDR, Airspy_R2,
    % SDRplay_RSPdx). USRP_B210 (70 MHz-6 GHz, 56 MHz IBW, 12-bit, 2 ch) is a
    % representative wideband spectrum-monitoring SDR.
    config.Factories.Scenario.CommunicationBehavior.Receiver.Sdr.Model = 'USRP_B210';

    % ===================== REGULATORY SPECTRUM PLANNING =====================
    % Phase 8 replaces arbitrary frequency / bandwidth / modulation sampling
    % with region-aware service planning. The physical scene is bound to a
    % regulatory region first; then the monitoring receiver band and each
    % transmitter's service, RF channel, bandwidth, and modulation family are
    % selected from that region's spectrum catalog.
    config.Factories.Scenario.CommunicationBehavior.Regulatory.Enable = true;
    config.Factories.Scenario.CommunicationBehavior.Regulatory.Region.Policy = 'Fixed';
    config.Factories.Scenario.CommunicationBehavior.Regulatory.Region.Fixed = 'CN';
    config.Factories.Scenario.CommunicationBehavior.Regulatory.ServiceTier = 'Tier1';
    config.Factories.Scenario.CommunicationBehavior.Regulatory.ExcludedServiceClasses = ...
        {'Radar', 'Radiolocation', 'Radionavigation'};
    config.Factories.Scenario.CommunicationBehavior.Regulatory.MonitoringBand.Selection = 'WeightedByRegion';
    config.Factories.Scenario.CommunicationBehavior.Regulatory.MaxBandwidthFractionOfSampleRate = 0.8;
    % Narrowband real-world services such as AM/land-mobile keep their
    % realistic occupied bandwidth, but the synthetic waveform sample rate
    % must still be high enough for the repository's Tx RF impairment chain.
    config.Factories.Scenario.CommunicationBehavior.Regulatory.MinimumModulatorSampleRateHz = 250e3;
    % Transmit power follows the service class (broadcast towers radiate far
    % more than handheld land-mobile radios or short-range devices). The
    % selector applies realistic per-ServiceClass dBm defaults; override any
    % class here, e.g.:
    %   config...Regulatory.ServicePowerDbm.Broadcast = [43, 60];
    %   config...Regulatory.ServicePowerDbm.ShortRangeDevice = [0, 14];
    
    % ===================== TRANSMITTER CONFIGURATION =====================
    % Scenario-level params: defines what the transmitter produces
    config.Factories.Scenario.CommunicationBehavior.Transmitter.Types = {'Simulation'};
    config.Factories.Scenario.CommunicationBehavior.Transmitter.Power.Min = 10;
    config.Factories.Scenario.CommunicationBehavior.Transmitter.Power.Max = 30;
    config.Factories.Scenario.CommunicationBehavior.Transmitter.NumAntennas.Min = 1;
    config.Factories.Scenario.CommunicationBehavior.Transmitter.NumAntennas.Max = 4;
    config.Factories.Scenario.CommunicationBehavior.Transmitter.BandwidthRatio.Min = 0.02;
    config.Factories.Scenario.CommunicationBehavior.Transmitter.BandwidthRatio.Max = 0.25;
    % NOTE: RF impairment detail params are in transmit_factory.m
    
    % ===================== TEMPORAL BEHAVIOR =====================
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternTypes = {...
        'Continuous', 'Burst', 'Scheduled', 'Random'};
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternDistribution = [0.4, 0.3, 0.2, 0.1];
    
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Continuous.DutyCycle = 1.0;
    
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Burst.OnDuration.Min = 0.01;
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Burst.OnDuration.Max = 0.1;
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Burst.OffDuration.Min = 0.01;
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Burst.OffDuration.Max = 0.2;
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Burst.DutyCycle.Min = 0.1;
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Burst.DutyCycle.Max = 0.8;
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Burst.InitialDelay.Min = 0;
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Burst.InitialDelay.Max = 0.5;
    
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Scheduled.SlotDuration.Min = 0.005;
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Scheduled.SlotDuration.Max = 0.02;
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Scheduled.SlotsPerFrame.Min = 4;
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Scheduled.SlotsPerFrame.Max = 16;
    
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Random.StartTimeRatio.Min = 0;
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Random.StartTimeRatio.Max = 0.5;
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Random.DurationRatio.Min = 0.1;
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Random.DurationRatio.Max = 0.9;
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Random.NumBursts.Min = 1;
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Random.NumBursts.Max = 5;
    % Explicit intervals are seconds inside the observation window. Use an
    % Nx2 matrix for all transmitters or a cell array with one Nx2 matrix
    % per transmitter. Empty means the Explicit mode is disabled.
    config.Factories.Scenario.CommunicationBehavior.TemporalBehavior.Explicit.Intervals = [];
    
    % ===================== MODULATION (Legacy explicit-random path) =====================
    % In Phase 8 the default path is Regulatory.Enable=true, so modulation
    % families come from the regional service catalog. This list is kept for
    % tests or explicit legacy/random planning with Regulatory.Enable=false.
    %
    % Scenario selects TYPE from this list
    % ModulationFactory looks up ORDER and DETAILS from modulation_factory.m
    %
    % DESIGN: Scenario only specifies WHICH types to use, not HOW they work
    config.Factories.Scenario.CommunicationBehavior.Modulation.Types = {'PSK', 'QAM'};
    
    % Symbol rate calculation parameters (used for bandwidth planning)
    config.Factories.Scenario.CommunicationBehavior.Modulation.RolloffFactor = 0.25;
    config.Factories.Scenario.CommunicationBehavior.Modulation.SamplesPerSymbol = 4;
    % OFDM multi-antenna abstraction:
    %   OSTBC keeps the historical spatial-diversity path;
    %   SpatialMultiplexing uses comm.OFDMModulator's transmit-stream
    %   dimension directly when validation needs independent antenna streams.
    config.Factories.Scenario.CommunicationBehavior.Modulation.OFDMMimoMode = 'OSTBC';
    
    % ===================== MESSAGE (source derived from modulation) ==========
    % The message source is NOT randomly selected: it is a deterministic
    % function of the modulation family enforced in the planner
    % (csrd.support.modulation.messageSourceForModulation):
    %   analog modulation (FM/PM/AM variants) -> Audio
    %   digital modulation (PSK/QAM/FSK/...)   -> RandomBit
    % This list only documents the registered sources; it is no longer used
    % to sample a source. MessageFactory looks up DETAILS from
    % message_factory.m, and message length is CALCULATED from bandwidth and
    % duration, not configured.
    config.Factories.Scenario.CommunicationBehavior.Message.Types = {'RandomBit', 'Audio'};
    
    % ===================== TRANSMISSION PATTERN =====================
    config.Factories.Scenario.CommunicationBehavior.TransmissionPattern.DefaultType = 'Continuous';
    
    % ===================== FREQUENCY ALLOCATION =====================
    config.Factories.Scenario.CommunicationBehavior.FrequencyAllocation.Strategy = 'ReceiverCentric';
    config.Factories.Scenario.CommunicationBehavior.FrequencyAllocation.MinSeparation = 50e3;
    config.Factories.Scenario.CommunicationBehavior.FrequencyAllocation.AllowOverlap = false;
    config.Factories.Scenario.CommunicationBehavior.FrequencyAllocation.MaxOverlap = 0.3;
    
    config.Factories.Scenario.LogDetails = true;
end
