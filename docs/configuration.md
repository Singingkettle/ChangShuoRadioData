# CSRD Configuration Guide / 配置指南

CSRD uses modular MATLAB configuration files. A public config normally inherits
base components and then overrides only scenario-specific fields.

CSRD 使用模块化 MATLAB 配置文件。公开配置通常继承 `_base_` 下的组件，然后只覆盖场景
需要改动的字段。

## Load And Run / 加载与运行

```matlab
cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');

addpath(fullfile(pwd, 'tools'))
simulation(1, 1, 'csrd2025/csrd2025.m')
```

The loader resolves inheritance, normalizes runtime contracts, and rejects
contradictory runtime facts.

加载器会解析继承、归一化运行合同，并对互相矛盾的运行事实 fail-fast。

## Directory Structure / 目录结构

```text
config/
├── _base_/
│   ├── factories/
│   │   ├── scenario_factory.m
│   │   ├── message_factory.m
│   │   ├── modulation_factory.m
│   │   ├── transmit_factory.m
│   │   ├── channel_factory.m
│   │   └── receive_factory.m
│   ├── logging/
│   │   ├── default.m
│   │   └── debug.m
│   └── runners/
│       ├── default.m
│       └── high_performance.m
└── csrd2025/
    ├── csrd2025.m
    ├── csrd2025_full_coverage_validation.m
    ├── csrd2025_osm_raytracing_validation.m
    └── weather_example.m
```

## Inheritance / 继承

```matlab
function config = my_config()
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

    config.Runner.NumScenarios = 10;
    config.Log.Level = 'INFO';
    config.Factories.Scenario.Global.NumFramesPerScenario = 1;
end
```

## Runtime Contract / 运行合同

Phase 17/18 made the following fields authoritative:

| Runtime fact | Authority |
| --- | --- |
| Frame sample count | `Factories.Scenario.Global.FrameNumSamples` |
| Number of frames | `Factories.Scenario.Global.NumFramesPerScenario` |
| Observation duration | `Factories.Scenario.Global.ObservationDuration` |
| Receiver sample rate | receiver observation plan and `rxInfo.SampleRate` |
| Carrier frequency | receiver RF plan and `rxInfo.RealCarrierFrequency` |
| Planned bandwidth | transmitter scenario spectrum plan |
| Execution bandwidth/sample rate | modulator/channel/RF block output |
| Tx power | planner hardware power and `txInfo.Power` |
| Channel seed | non-empty `BurstId` plus deterministic seed inputs |

Do not set deprecated aliases such as `Runner.FixedFrameLength` or
`Factories.Scenario.Global.FrameLength`. They are rejected because duplicate
authorities can make signal, scene, and annotation diverge.

不要再设置 `Runner.FixedFrameLength` 或 `Factories.Scenario.Global.FrameLength`
这类旧别名。重复权威会导致信号、场景和标注不一致，因此现在直接报错。

## Frame Example / 帧配置示例

```matlab
fs = 20e6;
frameSamples = 262144;

config.Factories.Scenario.CommunicationBehavior.Receiver.SampleRate = fs;
config.Factories.Scenario.Global.NumFramesPerScenario = 1;
config.Factories.Scenario.Global.FrameNumSamples = frameSamples;
config.Factories.Scenario.Global.FrameDuration = frameSamples / fs;
config.Factories.Scenario.Global.ObservationDuration = frameSamples / fs;
```

## Validation Profiles / 验证配置

- `csrd2025/csrd2025.m`: normal example configuration.
- `csrd2025/csrd2025_full_coverage_validation.m`: full coverage validation matrix.
- `csrd2025/csrd2025_osm_raytracing_validation.m`: OSM/RayTracing stress profile.
- `csrd2025/weather_example.m`: weather configuration example.

Full validation writes ignored outputs under `data/`.
