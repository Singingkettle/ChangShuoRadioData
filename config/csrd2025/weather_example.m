function config = weather_example()
    % weather_example - Weather configuration example for PhysicalEnvironment
    %
    % This example demonstrates how to configure weather conditions
    % for the PhysicalEnvironmentSimulator in CSRD2025.

    config.baseConfigs = {
                          '_base_/logging/default.m',
                          '_base_/runners/default.m',
                          '_base_/factories/scenario_factory.m',
                          '_base_/factories/message_factory.m',
                          '_base_/factories/modulation_factory.m',
                          '_base_/factories/transmit_factory.m',
                          '_base_/factories/channel_factory.m',
                          '_base_/factories/receive_factory.m'
                          };

    % Runner configuration
    config.Runner.NumScenarios = 2;
    config.Runner.FixedFrameLength = 1024;
    config.Runner.RandomSeed = 'shuffle';
    config.Runner.SimulationMode = 'Scenario-Driven';
    config.Runner.ValidationLevel = 'Moderate';

    % Data Storage Configuration
    config.Runner.Data.OutputDirectory = 'WeatherExample';
    config.Runner.Data.SaveFormat = 'mat';
    config.Runner.Data.CompressData = true;
    config.Runner.Data.MetadataIncluded = true;

    % Engine Configuration
    config.Runner.Engine.Handle = 'csrd.core.ChangShuo';
    config.Runner.Engine.ResetBetweenScenarios = true;

    % Logging Configuration
    config.Log.Name = 'WeatherExample';
    config.Log.Level = 'DEBUG';
    config.Log.SaveToFile = true;
    config.Log.DisplayInConsole = true;

    % Override Weather Configuration for Different Weather Scenarios
    % Example 1: Hot and Humid Tropical Weather
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Enable = true;
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Temperature = 35; % Hot tropical temperature
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Humidity = 85; % High humidity
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Pressure = 1010; % Slightly lower pressure
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.WindSpeed = 5; % Light wind
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.WindDirection = 90; % East wind

    % Weather Evolution - More dynamic changes for tropical weather
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.TemperatureVariation = 0.5; % More temperature variation
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.HumidityVariation = 2.0; % High humidity variation
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.PressureVariation = 0.3; % More pressure changes
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.WindSpeedVariation = 1.0; % Variable wind
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.WindDirectionVariation = 15; % Variable wind direction

    % Weather Constraints - Tropical ranges
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.TemperatureRange = [25, 45]; % Tropical temperature range
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.HumidityRange = [60, 95]; % High humidity range
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.PressureRange = [1000, 1020]; % Tropical pressure range
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.WindSpeedRange = [0, 15]; % Light to moderate wind

    % Configuration metadata
    config.Metadata.Version = '2025.1.0';
    config.Metadata.CreatedDate = datetime('now');
    config.Metadata.Description = 'Weather Configuration Example for CSRD Framework';
    config.Metadata.Author = 'ChangShuo';
    config.Metadata.WeatherScenario = 'Tropical Hot and Humid';
    config.Metadata.LastModified = datetime('now');
end
