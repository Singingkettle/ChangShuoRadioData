[English](source-layout.md) | [中文](source-layout.zh-CN.md)

# CSRD 源代码布局

本页描述当前的源代码树。历史审计文档可能会提及已移除的包或辅助工具;请以本页为准进行当前的导航。

## 生产数据流

```text
tools/simulation.m
  -> csrd.runtime.config_loader
  -> csrd.pipeline.runtime.buildRuntimePlan
  -> csrd.SimulationRunner
  -> csrd.core.ChangShuo
  -> csrd.factories.ScenarioFactory.planScenario
  -> ScenarioPlan + FramePlan execution
  -> receiver frame assembly
  -> annotation export
```

核心不变量保持不变:信号数据、场景状态与标注必须描述同一个事件。

## 生产入口点

- `tools/simulation.m`:正式生成入口点。
- `csrd.runtime.config_loader`:模块化配置加载与运行级策略构建。
- `+csrd/SimulationRunner.m`:场景调度、输出目录、日志记录,以及运行器级别的验证。
- `+csrd/+core/@ChangShuo`:逐场景执行引擎。
- `+csrd/+pipeline/+runtime/buildScenarioPlan.m`:场景构建计划生成器。
- `+csrd/+pipeline/+annotation/readAnnotation.m`:标注读取器与 schema 校验门。

## 包职责

| 包 | 职责 |
| --- | --- |
| `+csrd/+blocks` | 场景、物理环境、调制、消息、RF、信道、接收机等模块。 |
| `+csrd/+catalog` | 监管频谱目录(`+spectrum`)与 SDR 监测接收机能力配置(`+receiver`)。 |
| `+csrd/+core` | `ChangShuo` 执行引擎以及帧/接收机编排。 |
| `+csrd/+factories` | 根据配置和场景计划构建生产模块的工厂对象。 |
| `+csrd/+pipeline` | 跨模块契约:运行时计划、标注、测量、链路预算、场景真值。 |
| `+csrd/+runtime` | 配置加载、日志记录、工具箱检查、系统信息、map/runtime 服务。 |
| `+csrd/+support` | 验证、文档审计、哈希、随机辅助工具、优化,以及测试支持相关的实用工具。 |

不要在 `+csrd/+utils` 下添加新的生产代码;该包已被移除。

## 场景级计划规则

运行级策略存放于 `RuntimePlan`;具体的逐场景事实存放于 `ScenarioPlan`。帧循环不应重新采样:

- 帧采样数
- 帧数量
- 选定的 map 文件
- Tx/Rx 数量或标识
- 通信调度

如果某个场景级事实需要随机性,应在第一帧之前抽取,并将其记录在 `ScenarioPlan` 中。

## 接收机与信号契约

- **监测接收机能力。** 接收机的行为类似于真实的 SDR。
  `csrd.catalog.receiver.SdrReceiverCatalog` 保存了常见型号(USRP B210/N310、BladeRF、HackRF、RTL-SDR、Airspy、SDRplay)的能力配置(调谐范围、最大瞬时带宽、ADC 位数、噪声系数、通道数)。所选型号会限制统一的 `SampleRate`(捕获的瞬时带宽)和天线数量,并将监测频段中心约束在该型号的调谐范围内。通过 `CommunicationBehavior.Receiver.Sdr.Model` 进行配置。
- **消息源契约。** 基带源是调制族的确定性函数:模拟族(FM/PM/AM 变体)使用 `Audio`,数字族使用 `RandomBit`
  (`csrd.support.modulation.messageSourceForModulation`)。该绑定在规划阶段、段构建阶段以及标注读取器中均被强制执行。
- **服务感知发射机。** 在监管规划下,发射功率和调制阶数遵循服务等级与信道带宽,每个国家目录涵盖广播、移动、陆地移动、ISM、短距离、航空和海事服务。

## OSM 与 RayTracing 注意事项

- OSM 的选择在文件层面是均衡的;未启用任何尺寸上限或运行时分级过滤器。
- 当平坦地形策略被显式声明并在元数据中可见时,空的/无建筑的 OSM 文件是有效的。
- 地理坐标用于 RayTracing 站点构建;距离、多普勒和移动则使用基于米的位置和速度。
- RayTracing 的回退(fallback)必须是显式的,并反映在执行元数据中。

## 生成输出位置

- 正式数据集生成写入 `data/<DatasetName>/` 下;`data/` 被 git 忽略,不得加入 git。
- 原始地图资源存放于 `data/map/` 下,必须予以保留。
- 自动化测试运行写入 `artifacts/tests/runs/` 下。
- 生成的测试配置写入 `artifacts/tests/generated_configs/` 下。
- 长时间运行的诊断和性能跟踪写入 `artifacts/` 下。
- 大型生成审计清单写入 `artifacts/audits/reports/` 下。
- 历史重构/审计结论保存在 `archive/history-2026-06-30` 分支上,而非 `main` 上。
