[English](configuration.md) | [中文](configuration.zh-CN.md)

# CSRD 配置与运行时计划

本文档描述当前的配置契约。它取代了将帧长度或观测时长视为全局已解析字段的旧说明。

核心规则:原始配置只存储授权方(authorities)与采样策略。每个场景在执行开始前,都会从 `ScenarioPlan` 接收其具体的构造计划。

## 分层

| 层 | 所有者 | 包含内容 | 不得包含 |
| --- | --- | --- | --- |
| 原始配置 | `config/*.m` | 用户意图、授权方、随机策略 | 派生的帧时长、观测时长、遗留别名 |
| `RuntimePlan` | `csrd.pipeline.runtime.buildRuntimePlan` | 运行级别策略与配置指纹 | 场景解析后的帧事实 |
| `ScenarioPlan` | `csrd.pipeline.runtime.buildScenarioPlan` | 单个场景的具体事实 | 帧执行期间重新采样的值 |
| 执行元数据 | RF/信道/接收机模块 | 实际的采样网格与模型执行事实 | 被当作测量值使用的设计猜测 |
| 标注 | 标注流水线 | 设计、执行、测量三个真值平面 | 静默回退或未标注的 NaN |

## 原始配置授权方

常见的顶层字段:

- `Runner.NumScenarios`:本次运行中的场景数量。
- `Runner.RandomSeed`:用于确定性重放的根种子。
- `Runner.Data.OutputDirectory`:数据集输出根目录。
- `Logging.Policy`:日志策略,例如 `Standard` 或 `LargeMC`。

帧多样性通过 `Factories.Scenario.FramePolicy` 配置。

固定帧形状:

```matlab
config.Factories.Scenario.FramePolicy.FrameNumSamples.Mode = 'Fixed';
config.Factories.Scenario.FramePolicy.FrameNumSamples.Value = 262144;
config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Mode = 'Fixed';
config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Value = 1;
```

场景级别的多样性:

```matlab
config.Factories.Scenario.FramePolicy.FrameNumSamples.Mode = 'Choice';
config.Factories.Scenario.FramePolicy.FrameNumSamples.Values = [1024 4096 16384];
config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Mode = 'IntegerRange';
config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Min = 1;
config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Max = 8;
```

接收机采样率与载波是接收机的授权字段,而非由信道回填:

```matlab
config.Factories.Scenario.CommunicationBehavior.Receiver.SampleRate = 50e6;
config.Factories.Scenario.CommunicationBehavior.Receiver.RealCarrierFrequency = 2.45e9;
```

## ScenarioPlan

在每个场景开始之前,`ScenarioFactory.planScenario` 会解析:

- `ScenarioId`
- `Frame.FrameNumSamples`
- `Frame.NumFramesPerScenario`
- `Frame.SampleRateHz`
- `Frame.FrameDurationSec`
- `Frame.ObservationDurationSec`
- 地图选择与信道模型
- 发射机与接收机计划
- 通信发射调度
- `DatasetAccounting.NumReceiverFrames`

一旦该计划构建完成,帧循环就只能消费它。如果某个模块需要更改某项场景级别的事实,该更改应归属于计划构建阶段,而不是放在 `generateSingleFrame` 内部。

## 标注来源

- `Truth.Design`:从 `ScenarioPlan` 和设计时模块计划复制而来的值。
- `Truth.Execution`:来自实际波形插入、RF、信道、地图与采样网格执行的事实。
- `Truth.Measured`:根据生成信号计算得到的测量值。

对于一个有效信源(live source),其测量字段必须是有限值。只有在显式标记 `MeasurementStatus='NoSignal'` 时,空信源或被裁剪掉的信源才可使用 NaN。

## OSM 策略

OSM 的选择是文件级别的均衡覆盖。在当前生产行为中,没有默认的大小上限,也没有大地图分层。

- `Map.Types` 和 `Map.Ratio` 决定某个场景使用 OSM 还是其他地图类型。
- OSM 候选项按种子与场景调度进行确定性排序与打乱。
- `SpecificFile` 为验证或冒烟配置固定一个确切的文件。
- `MaxFileSizeMB` 会被拒绝;较慢的大地图是一项性能事实,而不是过滤规则。

## 已拒绝的遗留字段

以下字段属于配置错误:

- `Runner.FixedFrameLength`
- `Runner.Log`
- 顶层 `Log`
- `Factories.Scenario.Global.FrameLength`
- `Factories.Scenario.Global.FrameNumSamples`
- `Factories.Scenario.Global.NumFramesPerScenario`
- `Factories.Scenario.Global.FrameDuration`
- `Factories.Scenario.Global.ObservationDuration`
- 被当作帧定时授权方使用的原始 `TimeResolution`
- `Channel.LinkBudget.CarrierFrequency`
- `Map.OSM.MaxFileSizeMB`
- 在新生产配置中使用诸如 `SeedValue` 和 `SegmentID` 之类的兼容别名

## 验证

```matlab
cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
assert(isfield(cfg, 'RuntimePlan'));

run_csrd_ci_smoke('IncludePhase4', false, 'BaselineScenarios', 1)
```
