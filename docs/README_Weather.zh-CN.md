[English](README_Weather.md) | [中文](README_Weather.zh-CN.md)

# 天气配置指南

天气在物理环境工厂下进行配置：

```matlab
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather
```

## 今天的天气做什么——以及不做什么

天气**仅是环境元数据**。仿真器初始化一个天气状态（温度/湿度/气压/风），
按帧用下面的随机变化量演化它，并把该状态记录进物理环境的帧历史。它**不会**
进入传播链路：没有任何信道模型读取天气状态，因此它从不改变路径损耗、衰落
或任何一个生成的 IQ 样本。（代码库中存在大气条件钩子作为扩展点，但未接入
生产信道；且 csrd2025 实现的是**受控目标 SNR**而非链路预算驱动的 SNR，即使
接了大气损耗也不会移动实现的 SNR。）请把天气当作面向未来扩展的场景装饰，
而不是当前数据集中的物理效应。

时间推进必须遵循 `ScenarioPlan.Frame.FrameDurationSec`；天气不得重新引入诸如 `TimeResolution` 之类的全局遗留计时字段。

## 配置字段

启用天气：

```matlab
config.Factories.Scenario.PhysicalEnvironment.Environment.Weather.Enable = true;
```

`Enable = false` 的行为与完全没有 `Weather` 块**逐位一致**：使用静态默认
天气状态、不演化、不消耗随机数（由 `WeatherEnableTest` 守卫）。

初始条件：

```matlab
weather = config.Factories.Scenario.PhysicalEnvironment.Environment.Weather;
weather.InitialConditions.Temperature = 20;      % Celsius
weather.InitialConditions.Humidity = 50;         % percent, 0-100
weather.InitialConditions.Pressure = 1013;       % hPa
weather.InitialConditions.WindSpeed = 0;         % m/s
weather.InitialConditions.WindDirection = 0;     % degrees, 0-360
```

演化参数描述每帧的随机变化。帧时长由场景计划解析，因此天气更新步长应当采用场景帧时长，而不是单独的原始配置时间步长。

```matlab
weather.Evolution.TemperatureVariation = 0.1;    % Celsius
weather.Evolution.HumidityVariation = 0.5;       % percent
weather.Evolution.PressureVariation = 0.1;       % hPa
weather.Evolution.WindSpeedVariation = 0.2;      % m/s
weather.Evolution.WindDirectionVariation = 5;    % degrees
```

物理约束：

```matlab
weather.Constraints.TemperatureRange = [-40, 60];    % Celsius
weather.Constraints.HumidityRange = [0, 100];        % percent
weather.Constraints.PressureRange = [900, 1100];     % hPa
weather.Constraints.WindSpeedRange = [0, 50];        % m/s
```

## 默认值

当前默认值定义在场景工厂配置附近：

- `config/_base_/factories/scenario_factory.m`
- `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/getDefaultConfiguration.m`

如果省略某个天气子字段，物理环境模拟器会对该子字段使用其文档中记录的默认值。不要利用天气默认值来掩盖缺失的场景计时契约；帧计时来自 `ScenarioPlan.Frame`。

## 示例

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

通过公共入口点运行：

```matlab
addpath('tools');
simulation(1, 1, 'my_weather_config.m');
```

## 相关代码

- `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/initializeEnvironment.m`
- `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/updateWeatherConditions.m`
- `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/getDefaultConfiguration.m`
- `+csrd/+pipeline/+runtime/buildScenarioPlan.m`
