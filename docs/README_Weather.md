# Weather Configuration Guide / 天气配置指南

Weather is part of the physical-environment plan produced by
`PhysicalEnvironmentSimulator`. It is configured under:

天气属于 `PhysicalEnvironmentSimulator` 负责的物理环境规划，配置路径为：

```matlab
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather
```

Default values live in:

- `config/_base_/factories/scenario_factory.m`
- `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/getDefaultConfiguration.m`

Runtime handling lives in:

- `initializeEnvironment.m`
- `updateEnvironmentalConditions.m`
- `updateWeatherConditions.m`

## Fields / 字段

```matlab
weather.Enable = true;

weather.InitialConditions.Temperature = 20;   % Celsius / 摄氏度
weather.InitialConditions.Humidity = 50;      % percent / 百分比
weather.InitialConditions.Pressure = 1013;    % hPa
weather.InitialConditions.WindSpeed = 0;      % m/s
weather.InitialConditions.WindDirection = 0;  % degrees / 度

weather.Evolution.TemperatureVariation = 0.1;
weather.Evolution.HumidityVariation = 0.5;
weather.Evolution.PressureVariation = 0.1;
weather.Evolution.WindSpeedVariation = 0.2;
weather.Evolution.WindDirectionVariation = 5;

weather.Constraints.TemperatureRange = [-40, 60];
weather.Constraints.HumidityRange = [0, 100];
weather.Constraints.PressureRange = [900, 1100];
weather.Constraints.WindSpeedRange = [0, 50];
```

## Example / 示例

Use the checked-in example as a starting point:

使用已有示例作为模板：

```matlab
cfg = csrd.runtime.config_loader('csrd2025/weather_example.m');

addpath(fullfile(pwd, 'tools'))
simulation(1, 1, 'csrd2025/weather_example.m')
```

## Modeling Notes / 建模说明

- Weather evolution currently uses random variations around the current state.
- Constraints clamp values to physically reasonable ranges.
- Wind direction is kept in degree units.
- Weather state is part of the physical environment; it should not be used to
  silently alter RF/channel metadata unless that effect is explicitly modeled
  and annotated.

当前天气演化是环境状态的一部分。任何天气对传播或信道的影响，都应当显式建模并写入元数据，
不能悄悄改变信号或标注。
