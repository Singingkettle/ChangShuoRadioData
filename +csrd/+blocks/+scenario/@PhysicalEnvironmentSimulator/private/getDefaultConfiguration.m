function config = getDefaultConfiguration(obj)
    % getDefaultConfiguration - Get default physical environment configuration
    %
    % Returns a default configuration structure for the physical environment
    % simulator with reasonable default values for all required fields.

    config = struct();

    % Map configuration
    config.Map.Type = 'Grid';
    config.Map.Boundaries = [-2000, 2000, -2000, 2000]; % 4km x 4km area
    config.Map.Resolution = 100; % meters

    % Entity configuration
    config.Entities.Transmitters.Count = [2, 6];
    config.Entities.Receivers.Count = [1, 3];
    config.Entities.InitialDistribution = 'Random';

    % Mobility configuration
    config.Mobility.DefaultModel = 'RandomWalk';
    config.Mobility.EnableCollisionAvoidance = true;

    % Environment configuration
    config.Environment.Weather.Enable = true;
    config.Environment.Weather.InitialConditions.Temperature = 20; % Celsius
    config.Environment.Weather.InitialConditions.Humidity = 50; % Percentage
    config.Environment.Weather.InitialConditions.Pressure = 1013; % hPa
    config.Environment.Weather.InitialConditions.WindSpeed = 0; % m/s
    config.Environment.Weather.InitialConditions.WindDirection = 0; % degrees

    % Weather Evolution Parameters
    config.Environment.Weather.Evolution.TemperatureVariation = 0.1;
    config.Environment.Weather.Evolution.HumidityVariation = 0.5;
    config.Environment.Weather.Evolution.PressureVariation = 0.1;
    config.Environment.Weather.Evolution.WindSpeedVariation = 0.2;
    config.Environment.Weather.Evolution.WindDirectionVariation = 5;

    % Weather Constraints
    config.Environment.Weather.Constraints.TemperatureRange = [-40, 60];
    config.Environment.Weather.Constraints.HumidityRange = [0, 100];
    config.Environment.Weather.Constraints.PressureRange = [900, 1100];
    config.Environment.Weather.Constraints.WindSpeedRange = [0, 50];

    config.Environment.Obstacles.Enable = true;

    % Time configuration
    config.TimeResolution = 0.1; % seconds per frame
end
