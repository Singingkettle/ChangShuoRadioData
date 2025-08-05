function config = scenario_factory()
    % scenario_factory - Scenario factory configuration
    %
    % Core scenario configuration with dual-component architecture.

    config.Factories.Scenario.Description = 'Dual-component scenario factory';
    config.Factories.Scenario.Version = '2025.1.0';
    config.Factories.Scenario.Architecture = 'DualComponent';

    % Global Scenario Parameters
    config.Factories.Scenario.Global.Duration = 1.0;
    config.Factories.Scenario.Global.NumFramesPerScenario = 5;
    config.Factories.Scenario.Global.FrameLength = 1024;
    config.Factories.Scenario.Global.SampleRate = 1e6;
    config.Factories.Scenario.Global.FrequencyBand = [900e6, 2.4e9];

    % Physical Environment Configuration
    config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min = 1;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = 4;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = 1;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = 2;
    config.Factories.Scenario.PhysicalEnvironment.Entities.InitialDistribution = 'Random';

    % Map Configuration
    config.Factories.Scenario.PhysicalEnvironment.Map.Boundaries = [-2000, 2000, -2000, 2000];
    config.Factories.Scenario.PhysicalEnvironment.Map.Resolution = 100;
    config.Factories.Scenario.PhysicalEnvironment.MapTypeRatio.StatisticalRatio = 0.1;
    config.Factories.Scenario.PhysicalEnvironment.MapTypeRatio.OSMRatio = 0.9;

    % OSM Configuration
    currentFilePath = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(fileparts(fileparts(currentFilePath)));
    config.Factories.Scenario.PhysicalEnvironment.OSMDataDirectory = fullfile(projectRoot, 'data', 'map', 'osm');
    config.Factories.Scenario.PhysicalEnvironment.OSMFilePattern = '*.osm';
    config.Factories.Scenario.PhysicalEnvironment.OSMMapFile = '';

    % Environment Configuration
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Enable = true;
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Temperature = 20; % Celsius
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Humidity = 50; % Percentage
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Pressure = 1013; % hPa
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.WindSpeed = 0; % m/s
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.WindDirection = 0; % degrees

    % Weather Evolution Parameters
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.TemperatureVariation = 0.1; % Standard deviation for temperature changes
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.HumidityVariation = 0.5; % Standard deviation for humidity changes
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.PressureVariation = 0.1; % Standard deviation for pressure changes
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.WindSpeedVariation = 0.2; % Standard deviation for wind speed changes
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.WindDirectionVariation = 5; % Standard deviation for wind direction changes (degrees)

    % Weather Constraints
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.TemperatureRange = [-40, 60]; % Min/Max temperature in Celsius
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.HumidityRange = [0, 100]; % Min/Max humidity percentage
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.PressureRange = [900, 1100]; % Min/Max pressure in hPa
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.WindSpeedRange = [0, 50]; % Min/Max wind speed in m/s

    % Obstacles Configuration
    config.Factories.Scenario.PhysicalEnvironment.Environment.Obstacles.Enable = true;

    % Communication Behavior Configuration
    config.Factories.Scenario.CommunicationBehavior.FrequencyAllocation.Strategy = 'ReceiverCentric';
    config.Factories.Scenario.CommunicationBehavior.FrequencyAllocation.MinSeparation = 100e3;
    config.Factories.Scenario.CommunicationBehavior.ModulationSelection.Strategy = 'Adaptive';
    config.Factories.Scenario.CommunicationBehavior.ModulationSelection.PreferredSchemes = {'PSK', 'QAM', 'OFDM'};

    % Transmission Pattern Configuration
    config.Factories.Scenario.CommunicationBehavior.TransmissionPattern.DefaultType = 'Continuous';
    config.Factories.Scenario.CommunicationBehavior.TransmissionPattern.TypeDistribution = [0.6, 0.3, 0.1];
    config.Factories.Scenario.CommunicationBehavior.TransmissionPattern.Burst.DurationRange = [0.01, 0.1];
    config.Factories.Scenario.CommunicationBehavior.TransmissionPattern.Burst.PeriodRange = [0.1, 1.0];
    config.Factories.Scenario.CommunicationBehavior.TransmissionPattern.Burst.DutyCycleRange = [0.1, 0.8];
    config.Factories.Scenario.CommunicationBehavior.TransmissionPattern.Scheduled.TimeSlotDuration = 0.01;
    config.Factories.Scenario.CommunicationBehavior.TransmissionPattern.Scheduled.FrameLength = 0.1;
    config.Factories.Scenario.CommunicationBehavior.TransmissionPattern.Scheduled.CoordinationStrategy = 'TDMA';

    % Power Control Configuration
    config.Factories.Scenario.CommunicationBehavior.PowerControl.Strategy = 'LinkBudget';
    config.Factories.Scenario.CommunicationBehavior.PowerControl.DefaultPower = 20;
    config.Factories.Scenario.CommunicationBehavior.PowerControl.PowerRange = [10, 30];
    config.Factories.Scenario.CommunicationBehavior.PowerControl.MaxPower = 30;

    % Legacy Compatibility
    config.Factories.Scenario.Transmitters.Count.Min = config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min;
    config.Factories.Scenario.Transmitters.Count.Max = config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max;
    config.Factories.Scenario.Transmitters.Types = {'Ideal', 'PhaseNoise', 'PowerAmplifier', 'IQImbalance', 'DCOffset'};
    config.Factories.Scenario.Receivers.Count.Min = config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min;
    config.Factories.Scenario.Receivers.Count.Max = config.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max;
    config.Factories.Scenario.Receivers.Types = {'IdealDemod', 'RRFSimulator', 'LNAReceiver', 'PhaseNoiseLimited'};
end
