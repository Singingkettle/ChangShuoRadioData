![Citybuster Studio Logo](assets/logo.svg)

# ChangShuo Radio Data (CSRD)

[English](README.md) | [中文](README.zh-CN.md)

CSRD 是一个 MATLAB 无线频谱感知数据生成系统。项目的核心要求是：生成
的 IQ 信号、仿真的场景状态、导出的 annotation 必须描述同一个无线事件。

当前架构不再使用“全局固定帧形状”的旧设计。一次运行只提供策略；每个
scenario 在执行前先生成冻结的 `ScenarioPlan`；每一帧都按照该计划执行；
annotation 分别记录设计事实、执行事实和测量事实。

## 快速上手

**新用户请先看 [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)**，里面有完整
流程：环境要求、OSM 地图数据、运行、输出结构、排错。

简而言之，在仓库根目录的 MATLAB 中：

```matlab
addpath(pwd)
addpath(fullfile(pwd, 'tools'))
simulation(1, 1, 'csrd2025/csrd2025.m')
```

生成数据写入 `data/CSRD2025/session_*/`（每场景一个 annotation JSON + IQ `.mat`）。

**首次运行前需要：**
- MATLAB **R2025a**，并安装 **Communications**、**Signal Processing**、**Phased
  Array System**、**Antenna** 工具箱。
- `data/map/osm/` 下的 **OSM 地图数据** —— 默认配置约 90% 用 OSM 射线追踪，地图
  目录为空会以 `CSRD:Scenario:MissingOSMFile` 快速失败。用
  `pip install requests && python tools/download_osm.py` 获取，或改用纯统计信道
  （`Map.Types = {'Statistical'}`）。

详见 [GETTING_STARTED.md](docs/GETTING_STARTED.md)。

## 当前入口

| 任务 | 入口 |
| --- | --- |
| 默认数据生成 | `tools/simulation.m` |
| 加载配置 | `csrd.runtime.config_loader` |
| 调度场景和 worker | `+csrd/SimulationRunner.m` |
| 生成单个场景 | `+csrd/+core/@ChangShuo` |
| 构建运行策略 | `csrd.pipeline.runtime.buildRuntimePlan` |
| 构建场景计划 | `csrd.pipeline.runtime.buildScenarioPlan` |
| 读取标注 | `csrd.pipeline.annotation.readAnnotation` |

从仓库根目录运行：

```matlab
addpath(pwd)
addpath(fullfile(pwd, 'tools'))
simulation(1, 1, 'csrd2025/csrd2025.m')
```

生成数据写入 `data/<DatasetName>/`。`data/` 下唯一应长期保留的内容是
`data/map/`，它保存本地地图资产。

## 运行模型

生产链路是：

```text
config_loader
  -> RuntimePlan          运行级策略和配置指纹
  -> SimulationRunner     场景调度、输出、失败统计
  -> ChangShuo
      -> ScenarioFactory.planScenario
      -> ScenarioPlan     冻结的场景施工图纸
      -> frame loop       按计划逐帧执行
      -> receiver frames  实际接收信号缓冲区
      -> annotation    Design / Execution / Measured 三层真值
```

关键合同：

- 原始配置只保存权威输入和抽样策略。
- `RuntimePlan` 是运行级策略对象，不保存已解析的场景帧事实。
- `ScenarioPlan.Frame` 保存单个 scenario 的 `FrameNumSamples`、
  `NumFramesPerScenario`、`FrameDurationSec` 和
  `ObservationDurationSec`。
- 一个 scenario 的生成分三步：先生成计划，再按计划执行，最后基于实际生成
  的信号写 annotation。
- `Truth.Design` 来自 `ScenarioPlan` 和设计期蓝图。
- `Truth.Execution` 来自实际样点插入、RF、channel、几何和执行元数据。
- `Truth.Measured` 来自接收信号的实际测量。

旧字段不是兼容入口。`Runner.FixedFrameLength`、
`Factories.Scenario.Global.FrameLength`、
`Factories.Scenario.Global.FrameNumSamples`、
`Factories.Scenario.Global.NumFramesPerScenario`、`FrameDuration`、
`ObservationDuration`、`config.Log` 和 `Runner.Log` 都会在配置边界报错。

## 目录结构

| 路径 | 作用 |
| --- | --- |
| `+csrd/` | 主 MATLAB package。 |
| `+csrd/+core/@ChangShuo/` | 单场景引擎和逐帧生成 helper。 |
| `+csrd/+factories/` | 场景、消息、调制、发射 RF、信道、接收 RF 的工厂。 |
| `+csrd/+blocks/` | 场景仿真器和物理层 block。 |
| `+csrd/+pipeline/` | 运行计划、标注、测量、链路预算、场景时间和信号 gating 合同。 |
| `+csrd/+runtime/` | 配置加载、日志、地图 helper、性能 trace、toolbox 检查和系统信息。 |
| `+csrd/+catalog/` | 频谱法规目录和可复用 profile。 |
| `+csrd/+support/` | 内部验证、hash、文档审计、随机数和维护 helper。 |
| `config/` | 基础配置和公开 `csrd2025` 配置。 |
| `tools/` | 公开入口、CI gate、审计、诊断、可视化和维护脚本。 |
| `tests/` | MATLAB 单元测试和回归测试。 |
| `docs/` | 当前英文文档和历史审计归档。 |
| `data/map/` | 本地 OSM/map 资产，清理时不要删除。 |

当前 package 说明见
[`docs/architecture/source-layout.md`](docs/architecture/source-layout.md)。

## 配置

默认配置从 `config/csrd2025/csrd2025.m` 开始。自定义配置通过
`baseConfigs` 继承 `config/_base_/` 下的基础片段。

帧多样性使用 `Factories.Scenario.FramePolicy`：

```matlab
config.Factories.Scenario.FramePolicy.FrameNumSamples.Mode = 'Choice';
config.Factories.Scenario.FramePolicy.FrameNumSamples.Values = [1024, 2048, 4096];
config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Mode = 'IntegerRange';
config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Min = 4;
config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Max = 10;
```

日志唯一权威是 `config.Logging`。默认大规模运行使用 `LargeMC`：

```matlab
config.Logging.Policy = 'LargeMC';
config.Logging.Console.Enabled = true;
config.Logging.File.Enabled = true;
config.Logging.Progress.Mode = 'Summary';
```

OSM 选择采用文件级均匀覆盖策略。当前生产逻辑没有默认文件大小上限，也没有
“大地图分级排除”。大 OSM 文件可能因为 MATLAB `siteviewer` 和 `raytrace`
处理几何而较慢；这是性能事实，不应被静默跳过或降级。

更多配置说明见 [`docs/configuration.md`](docs/configuration.md)。

## 验证

快速 smoke：

```matlab
addpath(pwd)
addpath(fullfile(pwd, 'tools', 'ci'))
run_csrd_ci_smoke('IncludePhase4', false, 'BaselineScenarios', 1)
```

常用聚焦测试：

```matlab
runtests('tests/unit/ScenarioPlanBuildTest.m')
runtests('tests/unit/ScenarioPlanFrozenBeforeFrameExecutionTest.m')
runtests('tests/unit/BuildSourceAnnotationTest.m')
runtests('tests/unit/MeasurementCompletenessHookTest.m')
```

## 文档

- [`docs/README.md`](docs/README.md)：英文文档索引。
- [`docs/configuration.md`](docs/configuration.md)：当前配置和运行计划合同。
- [`docs/annotation-schema.md`](docs/annotation-schema.md)：annotation 消费合同。
- [`docs/audits/manual-full-code-review-guide.md`](docs/audits/manual-full-code-review-guide.md)：人工代码 review 指南。
- [`docs/audits/`](docs/audits/)：历史审计快照，只作为证据，不作为当前操作规范。

如果需要旧 JSAC 时代的行为，请查看历史稳定 revision：
[a6d09a4b264894b76f852ce33bfd82adc7b270b5](https://github.com/Singingkettle/ChangShuoRadioData/tree/a6d09a4b264894b76f852ce33bfd82adc7b270b5)。
