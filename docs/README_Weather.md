# Weather Configuration Guide for PhysicalEnvironment

This guide explains how to configure weather conditions for the `PhysicalEnvironmentSimulator` in the CSRD framework.

## Configuration Structure

The weather configuration is organized under the PhysicalEnvironment section:

```matlab
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.*
```

## Configuration Sections

### 1. Enable/Disable Weather Simulation

```matlab
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Enable = true;
```

### 2. Initial Weather Conditions

Set the starting weather conditions for the simulation:

```matlab
% Temperature in Celsius
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Temperature = 20; 

% Humidity percentage (0-100)
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Humidity = 50; 

% Atmospheric pressure in hPa
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Pressure = 1013; 

% Wind speed in m/s
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.WindSpeed = 0; 

% Wind direction in degrees (0-360)
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.WindDirection = 0; 
```

### 3. Weather Evolution Parameters

Control how weather conditions change over time (standard deviation for random variations):

```matlab
% Temperature variation (°C)
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.TemperatureVariation = 0.1; 

% Humidity variation (%)
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.HumidityVariation = 0.5; 

% Pressure variation (hPa)
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.PressureVariation = 0.1; 

% Wind speed variation (m/s)
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.WindSpeedVariation = 0.2; 

% Wind direction variation (degrees)
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.WindDirectionVariation = 5; 
```

### 4. Weather Constraints

Set physical limits for weather parameters:

```matlab
% Temperature range [min, max] in Celsius
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.TemperatureRange = [-40, 60]; 

% Humidity range [min, max] in percentage
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.HumidityRange = [0, 100]; 

% Pressure range [min, max] in hPa
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.PressureRange = [900, 1100]; 

% Wind speed range [min, max] in m/s
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.WindSpeedRange = [0, 50]; 
```

## Example Weather Scenarios

### Tropical Climate
```matlab
% Hot and humid conditions
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Temperature = 35;
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Humidity = 85;
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Pressure = 1010;

% More dynamic variations
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.TemperatureVariation = 0.5;
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.HumidityVariation = 2.0;

% Tropical constraints
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.TemperatureRange = [25, 45];
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.HumidityRange = [60, 95];
```

### Arctic Climate
```matlab
% Cold and dry conditions
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Temperature = -20;
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Humidity = 30;
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Pressure = 1020;

% High wind variations
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.WindSpeedVariation = 2.0;
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.WindDirectionVariation = 20;

% Arctic constraints
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.TemperatureRange = [-40, 10];
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.HumidityRange = [10, 70];
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.WindSpeedRange = [0, 30];
```

### Stable Indoor Environment
```matlab
% Controlled indoor conditions
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Temperature = 22;
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Humidity = 45;
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.Pressure = 1013;
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.InitialConditions.WindSpeed = 0;

% Minimal variations
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.TemperatureVariation = 0.05;
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.HumidityVariation = 0.1;
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.PressureVariation = 0.01;
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Evolution.WindSpeedVariation = 0;

% Tight indoor constraints
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.TemperatureRange = [18, 26];
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.HumidityRange = [30, 60];
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Constraints.WindSpeedRange = [0, 1];
```

## Usage

1. Create your configuration file (e.g., `my_weather_config.m`)
2. Set the weather parameters as shown above
3. Run your simulation with the configuration:

```matlab
config = my_weather_config();
runner = csrd.SimulationRunner(config);
runner.run();
```

## Notes

- All weather parameters have sensible defaults if not specified
- Weather evolution uses Gaussian random variations
- Constraints are enforced to prevent unrealistic values
- Wind direction is automatically kept within 0-360 degree range
- The weather system is designed to be extensible for future enhancements

## Files Modified

- `config/_base_/factories/scenario_factory.m` - Base weather configuration
- `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/updateWeatherConditions.m` - Weather evolution logic
- `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/initializeEnvironment.m` - Weather initialization
- `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/getDefaultConfiguration.m` - Default weather settings
- `config/csrd2025/weather_example.m` - Complete weather configuration example 