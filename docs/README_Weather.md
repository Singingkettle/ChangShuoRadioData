# Weather Configuration Guide

Weather is configured under the physical-environment factory:

```matlab
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather
```

Weather is part of the scenario physical environment. It contributes
environment metadata and future propagation-condition extensions, but time
advancement must follow `ScenarioPlan.Frame.FrameDurationSec`; it must not
reintroduce global legacy timing fields such as `TimeResolution`.

## Configuration Fields

Enable weather:

```matlab
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Enable = true;
```

Initial conditions:

```matlab
weather = config.Factories.Scenario.PhysicalEnvironment.Environment.Weather;
weather.InitialConditions.Temperature = 20;      % Celsius
weather.InitialConditions.Humidity = 50;         % percent, 0-100
weather.InitialConditions.Pressure = 1013;       % hPa
weather.InitialConditions.WindSpeed = 0;         % m/s
weather.InitialConditions.WindDirection = 0;     % degrees, 0-360
```

Evolution parameters describe per-frame random variation. The frame duration is
resolved by the scenario plan, so the weather update step should consume the
scenario frame duration rather than a separate raw config time step.

```matlab
weather.Evolution.TemperatureVariation = 0.1;    % Celsius
weather.Evolution.HumidityVariation = 0.5;       % percent
weather.Evolution.PressureVariation = 0.1;       % hPa
weather.Evolution.WindSpeedVariation = 0.2;      % m/s
weather.Evolution.WindDirectionVariation = 5;    % degrees
```

Physical constraints:

```matlab
weather.Constraints.TemperatureRange = [-40, 60];    % Celsius
weather.Constraints.HumidityRange = [0, 100];        % percent
weather.Constraints.PressureRange = [900, 1100];     % hPa
weather.Constraints.WindSpeedRange = [0, 50];        % m/s
```

## Defaults

Current defaults are defined near the scenario factory configuration:

- `config/_base_/factories/scenario_factory.m`
- `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/getDefaultConfiguration.m`

If a weather subfield is omitted, the physical-environment simulator uses its
documented default for that subfield. Do not use weather defaults to hide a
missing scenario timing contract; frame timing comes from `ScenarioPlan.Frame`.

## Example

```matlab
function config = my_weather_config()
    config.baseConfigs = {
        '_base_/logging/default.m'
        '_base_/runners/default.m'
        '_base_/factories/scenario_factory.m'
        '_base_/factories/message_factory.m'
        '_base_/factories/modulation_factory.m'
        '_base_/factories/transmit_factory.m'
        '_base_/factories/channel_factory.m'
        '_base_/factories/receive_factory.m'
    };

    weather = config.Factories.Scenario.PhysicalEnvironment.Environment.Weather;
    weather.Enable = true;
    weather.InitialConditions.Temperature = 35;
    weather.InitialConditions.Humidity = 85;
    weather.Evolution.TemperatureVariation = 0.5;
    weather.Evolution.HumidityVariation = 2.0;
    weather.Constraints.TemperatureRange = [25, 45];
    weather.Constraints.HumidityRange = [60, 95];
    config.Factories.Scenario.PhysicalEnvironment.Environment.Weather = weather;
end
```

Run through the public entry point:

```matlab
addpath('tools');
simulation(1, 1, 'my_weather_config.m');
```

## Related Code

- `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/initializeEnvironment.m`
- `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/updateWeatherConditions.m`
- `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/getDefaultConfiguration.m`
- `+csrd/+pipeline/+runtime/buildScenarioPlan.m`
