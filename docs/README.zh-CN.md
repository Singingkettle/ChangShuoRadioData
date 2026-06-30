# CSRD 文档索引

[English](README.md) | [中文](README.zh-CN.md)

**第一次生成数据集?请从
[`GETTING_STARTED.zh-CN.md`](GETTING_STARTED.zh-CN.md) 开始。** 请以根目录的
[`README.md`](../README.md)、本索引、配置指南以及架构指南作为当前的操作文档。每篇文档都在顶部链接了对应的中文版(`.zh-CN.md`)。

## 当前文档

| 文档 | 用途 |
| --- | --- |
| [`GETTING_STARTED.zh-CN.md`](GETTING_STARTED.zh-CN.md) | **从这里开始。** 环境要求、OSM/Python 前置条件、如何生成数据、输出布局、故障排查。 |
| [`../README.md`](../README.md) | 项目概览、当前入口点、运行时模型、仓库布局。 |
| [`configuration.zh-CN.md`](configuration.zh-CN.md) | 原始配置权威源、`RuntimePlan` 策略、按场景的 `ScenarioPlan`、已弃用的遗留字段。 |
| [`architecture/source-layout.zh-CN.md`](architecture/source-layout.zh-CN.md) | 当前源码包的职责与生产数据流。 |
| [`annotation-schema.zh-CN.md`](annotation-schema.zh-CN.md) | 标注契约:`Truth.Design`、`Truth.Execution`、`Truth.Measured`、接收机视图。 |
| [`examples/annotation-downstream.zh-CN.md`](examples/annotation-downstream.zh-CN.md) | 下游消费者示例:读取标注并导出 COCO。 |
| [`README_Weather.zh-CN.md`](README_Weather.zh-CN.md) | 天气配置路径、单位、默认值以及 ScenarioPlan 时序说明。 |

## 配置

修改仿真输入时,请从 [`configuration.zh-CN.md`](configuration.zh-CN.md) 入手。当前模型如下:

1. 原始配置保存权威源与采样策略。
2. `csrd.runtime.config_loader` 构建运行级别的 `RuntimePlan`。
3. `ScenarioFactory.planScenario` 在每个场景执行之前构建一个冻结的 `ScenarioPlan`。
4. 帧生成遵循该计划;标注会分别记录设计、执行与实测事实。

不要为旧的帧字段添加兼容性回退。诸如
`Factories.Scenario.Global.FrameNumSamples`、`FrameDuration`、
`ObservationDuration`、`Runner.FixedFrameLength` 以及 `OSM.MaxFileSizeMB` 等已弃用字段属于配置错误。

## 架构

生产路径为:

```text
tools/simulation.m
  -> csrd.runtime.config_loader
  -> csrd.SimulationRunner
  -> csrd.core.ChangShuo
  -> csrd.factories.ScenarioFactory.planScenario
  -> physical environment / communication behavior / waveform / RF / channel
  -> receiver frame assembly
  -> annotation export
```

当前的包结构图见 [`architecture/source-layout.zh-CN.md`](architecture/source-layout.zh-CN.md)。

## 验证

评审时有用的入口点:

```matlab
run_csrd_ci_smoke('IncludePhase4', false, 'BaselineScenarios', 1)
simulation(1, 1, 'csrd2025/csrd2025.m')
```

生成的验证输出应归入被忽略的 `artifacts/` 或 `data/` 目录下。`data/map/` 是唯一被当作源资产对待的数据子树。

## 历史材料

记录项目如何走到当前状态的重构审计、阶段说明、交接文档以及通宵 bug 排查的发现,都保存在
[`archive/history-2026-06-30`](https://github.com/Singingkettle/ChangShuoRadioData/tree/archive/history-2026-06-30)
分支上,而非 `main` 分支。它们是证据,而非当前的操作说明。生成的审计清单不会提交;请在被忽略的 `artifacts/` 目录下重新生成它们。
