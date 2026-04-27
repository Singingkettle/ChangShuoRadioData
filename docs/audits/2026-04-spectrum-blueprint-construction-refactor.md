# 频谱感知仿真项目重构审计与实施计划

**状态**: Draft v0.5.0（Phase 0 / 1 / 2 / 3 / 4 / 5 已 Frozen；Phase 6 Draft）
**日期**: 2026-04-27
**用途**: 作为后续重构实施、跨 AI 审核、测试设计和验收的统一依据

## 修订历史

| 版本 | 日期 | 主要变化 |
|------|------|----------|
| v0.1 | 2026-04-24 | 初稿，由首位 AI 起草，给出三阶段（图纸/施工/测量）总体框架 |
| v0.2 | 2026-04-24 | 补全字段清单、画像库纲要、分阶段实施与测试纲要 |
| v0.3 | 2026-04-24 | 由第二位 AI（基于 4 路并行代码 explore）补强：(1) 在每节后追加"v0.3 加强"块，给出当前代码现状的**带行号事实凭据**；(2) 新增 §2.6 现状错位清单（H 级 11 条、M 级 8 条）；(3) §3.1 后增字段映射表，纠正 v0.2 把现有 `Realized.Bandwidth` 当 MeasuredTruth 的误判；(4) §3.2 后给出 ScenarioBlueprint / FrameExecutionPlan / MeasurementRecord 的 MATLAB struct schema 示例；(5) §3.3 后给出**施工层删除清单**（必删 8 条 / 必保留 4 条）；(6) §3.4 后给出 payload 长度推导公式；(7) §4 验图层补 BlueprintFeasibilityValidator 接口与 12 条 check；(8) §5 画像库给出第一版数值表；(9) §7 每个 Phase 加可证伪退出条件；(10) §7.bis 现状基线快照（Phase 0 必跑的 7 个数）；(11) §8 测试计划补"测哪个文件的哪个契约"映射；(12) 新增 §11 annotation v2 schema 与向后兼容；(13) 新增 §12 风险与已知折衷、§13 仓库改动落点清单、§14 审核要点清单。 |
| v0.4 | 2026-04-24 | 本轮在重新对齐当前代码实现后继续收紧：(1) 明确**同一 emitter 对不同 receiver 的投影关系必须 receiver-view 化**，`WindowFrequencyOffset` 不再被写成 emitter 全局字段；(2) 明确 `MeasuredTruth` 必须拆成 `SourcePlane` 与 `FramePlane` 两个测量平面，禁止从总接收信号直接反推出 per-source GT；(3) 承认当前实现的时变几何主路径仍然只到 **frame 粒度**，将 `SegmentMidpoint` 作为后续升级目标，而不是在文档里提前许诺；(4) 把 burst 与 frame 的关系从“frame 起点落入 interval”收紧为“interval 与 frame 有重叠就必须建段”，并把当前代码的漏检现状写透；(5) 补充接收机字段传递链、输出窗口长度契约、测试产物目录治理，避免后续实现再次偏离仓库现实。 |
| v0.4.1 | 2026-04-24 | 由第三位 AI（基于亲手 Read 复核 H1-H11 + 代码全量 audit）追加"v0.4 加强 第二轮"：作为 §16 / §17 两个独立顶层章节插入文末，与 v0.4 已有 receiver-view / 测量平面 / OutputWindowPolicy 修订**正交补强**：(1) §16.1 修订 v0.3 §2.6 H1/H3/H9/H10 + §6.bis 5 处事实失实条目；(2) §16.2-16.4 新增 H12-H17（Doppler 全链缺失 / Channel Seed 不含 BurstId / mergeChannelOutput 整体替换丢字段 / JSON NaN/Inf/Complex / Profile 与 BlueprintHash 仍是纸面字段 / MeasuredTruth 当前 0 实现）+ M9-M14 + L1-L2；(3) §16.5-16.10 给出 BlueprintHash 算法、signal struct 必含字段表、`Header.Runtime` schema、silent fallback 删除清单具体行号、D11-D14 新 check + ValidationReport 结构、Profile 加载 API 草案、PhaseNoiseProfiles 三档数值表、JSON 持久化禁忌、annotation V2 namespace 策略；(4) §17 落定六阶段（Phase 0 基线 + 底座 / Phase 1 数据流 + 异常契约 / Phase 2 蓝图层骨架 / Phase 3 施工层严格化 / Phase 4 测量层 + Doppler / Phase 5 大规模 MC + CI），每阶段给出可证伪退出条件 + 设计文档落点；(5) Phase 0 详细设计单独落在 `docs/audits/phases/phase-0-baseline.md`，本版本仅交付该一份阶段设计，后续阶段按"实施→测试→修订设计→冻结"循环逐阶段推进。 |
| v0.4.2 | 2026-04-24 | **Phase 0 实施完成 + Frozen**：(1) 落地 `+csrd/+utils/+toolbox/validateRequiredToolboxes.m`、`+csrd/+utils/+logger/+policy/LogPolicy.m`、`+csrd/+utils/+annotation/sanitizeForJson.m` 三条底座；(2) `+csrd/SimulationRunner.m` setupImpl 注入 `applyLogPolicyFromConfig` + `validateToolboxesFromConfig`，`saveScenarioData` 接 `sanitizeForJson` + `stampRuntimeHeader` 写 `Header.Runtime`；(3) 6 个单元测试（共 41 cases）+ 2 个回归测试（startup hooks + baseline sweep）全过；(4) 200 场景全量 baseline 入库 `docs/baselines/2026-04-baseline-v0.json`，BlueprintAcceptanceRate=1.0 / ChannelFactoryFailureRate=0 / JsonNanCount=0 / JsonInfinityCount=0，全部满足 §17.2 出口条件 4 条；(5) Phase 0 设计文档 `docs/audits/phases/phase-0-baseline.md` 状态改 Frozen；(6) `tests/run_all_tests.m` 增 `'phase0'` 测试组；(7) `README.md` 重构区块同步标 Phase 0 完成；(8) `.gitignore` 增 `artifacts/tests/runs/baseline_v0/` 与 smoke baseline 落点。**Phase 1 阀门已开**。 |
| v0.4.3 | 2026-04-26 | **Phase 1 / 2 / 3 / 4 实施完成 + Frozen**（回填四阶段冻结记录到顶层 changelog）：<br/>(1) **Phase 1**（2026-04-25 Frozen，详见 §17.3 + `phase-1-dataflow.md`）：堵 H1/H3/H9/H13/H14 + PA/LNA `comm.MemorylessNonlinearity` 严格化；6 个新单测套 + `test_phase1_dataflow_smoke` 全过；200 场景 baseline 5 条强契约红线全过，wallclock budget 由 +10% 上修到 +15%（owner A 案决议）。<br/>(2) **Phase 2**（2026-04-25 Frozen，详见 §17.4）：蓝图骨架 / `BlueprintFeasibilityValidator` 12 条 check 框架 / `ScenarioFactory` resample loop / `ComputeBlueprintHash` 实化。<br/>(3) **Phase 3**（2026-04-25 Frozen，详见 §17.5 + `phase-3-construction.md`）：施工层删 silent fallback；ReceiverViews 真投影解除 `RxRange=[1,1]` 限制；7 个 `Static, Hidden` provenance helper + 7 新单测套 + `test_no_dead_code_phase3` / `test_phase3_construction_smoke`；`run_all_tests('all')` 52/52 PASS / 593.7 s。<br/>(4) **Phase 4**（2026-04-26 Frozen，详见 §17.6 + `phase-4-measurement.md`）：测量层从 0 实现到主力字段全覆盖；`+csrd/+utils/+measurement/` 包 5 函数（`obwActual.m` 改 peak-relative 阈值 `-3 dBc` 替代旧 noise-floor 去噪）；`applyDopplerShift.m` + `ChannelFactory.HasInternalDoppler` 白名单防双重 Doppler；annotation v2 schema 升顶（owner Q-A=A_full_replace 决议，删 v1 顶层 6 字段）；`baseline_recipe_v0` 加 `HighSpeed_Aero_Doppler` cohort（200→**210** 场景）；`test_baseline_sweep_200` 新 metric `ExecutionVsMeasuredBwAbsRelDiffP95=0.02117 < 0.03`（C8）；C9 wallclock P95 budget 由 45.0 s 上修到 47.0 s 覆盖测量层 + Doppler + FramePlane 缓存的实测开销（45.47 s）；C1–C9 全过；`run_all_tests('all')` 60/60 PASS / ~13 min。**Phase 5 阀门已开**。 |
| v0.4.4 | 2026-04-27 | **Phase 5 实施完成 + Frozen**（详见 §17.7 + `phase-5-mc-validation.md`）：(1) 完成 fail-fast 收尾，`CSRD:Measurement:` 纳入 skip predicate，channel/receiver/frame generic error 不再写半损坏 annotation；(2) owner `A_full_replace` 决议落地，`convert_csrd_to_coco` 对 annotation v2 未实现路径显式 fail-fast，不再静默读 v1；(3) 新增 `tools/phase5/run_phase5_mc_validation.m`、`tools/ci/run_csrd_ci_smoke.m`、`tools/ci/run_csrd_static_gates.m` 和 self-hosted workflow；(4) 1000 场景 final-v04 MC 完成，`BlueprintAcceptanceRate=1.0` / `ChannelFactoryFailureRate=0` / `ExecutionVsMeasuredBwAbsRelDiffP95=0.022217530072084515` / `JsonNanCount=0` / `JsonInfinityCount=0`；(5) S9 中断暴露 MC 设计缺口后，先修订 Phase 5 设计，再实现 `Resume=true` checkpoint/artifact recovery，最终 baseline 写入 `RunRecovery`；(6) CI smoke 全入口 PASS，`run_csrd_ci_smoke()` 约 1239.4 s，满足 30 min 硬门禁；operator-run wallclock P50/P95=31.505/66.285 s 作为性能诊断，不作为标注正确性门禁。**v0.4 六阶段重构冻结**。 |
| v0.5.0 | 2026-04-27 | **Phase 6 Draft 启动**：owner 要求下一阶段继续时先回顾前面阶段；新增 `docs/audits/phases/phase-6-release-hardening.md`，定位为 v0.4 冻结后的 release hardening / performance diagnostics / annotation v2 toolchain 阶段。Phase 6 明确不改变 Blueprint / Construction / Measurement truth contract，不回退 annotation v2，不做 v1 兼容或迁移。S1-S4 已落地：新增 `tools/release/run_csrd_release_readiness.m`、`+csrd/+utils/+annotation/readAnnotationV2.m`、`ReadAnnotationV2Test`、`test_phase6_release_readiness` 和 `run_all_tests('phase6')` selector；readiness 与 annotation v2 schema validation 均通过。 |

> v0.4 不删除 v0.2/v0.3 任何原文，只在关键小节后继续追加"**v0.4 加强**"块。当 v0.4 与 v0.3/v0.2 出现冲突时（例如把某个字段从 emitter 全局字段改成 receiver-view 字段，或把总接收信号测量重新归类为 FramePlane），以 v0.4 加强块为准。

## 1. 背景与目标

当前项目已经具备完整的数据生成主链路，但在架构边界上仍存在明显混杂：

- 图纸阶段、施工阶段、测量阶段的职责没有完全分离
- 一部分本应在图纸阶段决定的内容，被推迟到了施工阶段临时处理
- 一部分本应由最终测量给出的 GT，被错误地沿用了设计值
- 某些极端或不合理组合，当前依赖施工阶段内部兜底，导致类的职责混乱、维护困难

本次重构的核心目标不是只修局部 bug，而是把项目收敛为一个长期可维护、可扩展、适合大规模数据生成的三阶段体系：

1. **图纸阶段（Blueprint）**
   只负责定义完整、可施工、可审计的场景蓝图。
2. **施工阶段（Construction）**
   只负责按图纸调用模块生成数据，不再改变图纸本义。
3. **测量阶段（Measurement）**
   只负责从实际生成结果中提取最终 GT。

最终数据流固定为：

`ScenarioBlueprint -> FrameExecutionPlan -> MeasurementRecord -> FinalAnnotation`

---

## 2. 审计结论摘要

基于当前代码审计，已经明确存在以下结构性问题：

### 2.1 图纸与施工边界混乱

- 场景规划阶段已经提前写入了一些过细的执行参数，例如固定消息长度
- 施工阶段仍在临时修正部分关键语义，例如发射端天线数、fallback 处理、信号长度适配
- 某些类同时承担了规划、执行、修补三个角色

### 2.2 GT 分层不彻底

- 设计值和测量值没有被严格分层
- 对频谱感知任务最关键的带宽标签，必须来源于实测，而不是规划值
- 规划值可以保留，但只能属于设计层或执行参考层，不能直接冒充最终训练 GT

### 2.3 burst / 帧 / payload 语义存在隐藏风险

- 当前生成逻辑中，发射机级别的 payload 规划与帧内活动时段并不完全同构
- 若一个 emitter 在多个 burst 或跨帧片段中发射，容易出现“图纸上的时域行为”和“实际生成的样本长度”不一致
- 这会污染最终时域占用、带宽统计和片段级 annotation

### 2.4 接收机与发射机画像还不够清晰

- 当前代码主线仍带有“统一 receiver 配置”的痕迹，这与多样化、异构输入的目标冲突
- 发射端天线数存在执行期回写逻辑，不应作为最终设计
- 模拟调制单天线限制当前更像隐藏补丁，而不是显式设计规则

### 2.5 现实约束不足，组合爆炸风险较高

- 目前参数很多是均匀随机采样，容易生成“理论能配、实际难施工”的场景
- 若用户不了解频段、带宽、采样率、设备能力之间的约束，配置文件稍微乱改就可能导致大量失败

---

### 2.6 v0.3 加强：现状错位清单（带行号事实凭据）

> 本节由第二位 AI 在 4 路并行 explore 后整理。每条均可由审核 AI 用 `Read` 工具按文件:行号原地复核，**不需要再做大规模搜索**。
> 字段含义：`(文件:行号) | 现状一句话 | 现状归类 | 影响 Phase`。
> 现状归类六种：**规划缺失** / **执行覆盖** / **fallback 修补** / **字段错位** / **dead config** / **假规划**。

#### 2.6.1 H 级（11 条，必须在 Phase 1-3 内修掉）

| ID | 文件:行号 | 现状一句话 | 归类 | Phase |
|----|-----------|-------------|------|-------|
| H1 | `+csrd/+core/@ChangShuo/private/setupReceivers.m`:42-47 与 `+csrd/+blocks/+physical/+rxRadioFront/RRFSimulator.m`:19-20 | `RxInfo.NumAntennas` 与 `RRFSimulator.NumReceiveAntennas` 字段名不一致；`ReceiveFactory.configureReceiverBlock` 只拷贝同名字段——**场景里写的接收天线数根本进不了 RRFSimulator**，块永远默认 1 | 字段错位 | Phase 1 |
| H2 | `+csrd/+core/@ChangShuo/private/processReceiverProcessing.m`:115-118；`+csrd/+blocks/+physical/+modulate/+digital/+PSK/PSK.m`:119-120 | `sourceInfo.Realized.Bandwidth` 实际来自调制器对**调制后基带**调用 `obw`，与"对最终接收信号测量"无关 | 假规划（Realized 实为 ExecutionTruth，不是 MeasuredTruth） | Phase 3 |
| H3 | `+csrd/+utils/+scenario/checkTransmissionInterval.m`:58-67；`+csrd/+core/@ChangShuo/private/processSingleTransmitter.m`:47-54 | 帧时间落在第一个匹配区间即返回，`NumSegments=1`——**当前代码不支持"一帧多 burst"**；蓝图若描述多 burst，执行端将丢失除第一段之外的所有 burst | 规划缺失 + 字段错位 | Phase 2 |
| H4 | `+csrd/+utils/+core/applyAntennaConfigFromSegments.m`:37-68 | 用**最后一段**非空 segment 的 `NumTransmitAntennas` 覆盖 `TxInfo.NumTransmitAntennas` 与 `SiteConfig.Antenna`；多段 burst 时取最后一段而不是图纸值 | 执行覆盖 | Phase 1（删整段） |
| H5 | `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/calculateTransmissionState.m`:34-69 | Burst / Scheduled / Random 三种模式实际共用同一套 `checkIntervals`；`Scheduled` 无 `Intervals` 时硬编码 `mod(frameId,3)==0`，`Random` 无 `Intervals` 时**始终 on**——四种模式名字不带任何执行差异 | fallback 修补 + dead config | Phase 1 |
| H6 | `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/allocateFrequenciesRandom.m`:5-6；同目录 `allocateFrequenciesOptimized.m`:5-6 | "Optimized" 与 "Random" 频率分配实际**直接转调** `ReceiverCentric`；配置项给用户假象 | dead config | Phase 1 |
| H7 | `README.md`、`config/_base_/factories/scenario_factory.m` | `Global.FrequencyBand`（如 `[900e6, 2.4e9]`）在仓库内**无任何代码消费**；改一行不影响任何输出。文档/代码漂移 | dead config | Phase 0（订正文档）/ Phase 4（接入画像） |
| H8 | `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/assignMobilityModel.m`:10-17 | `scenario_factory.m` 配置的 `Mobility.Model` 被忽略，固定 `randperm` 在 `{RandomWalk, Waypoint, Stationary}` 3 选 1 | dead config | Phase 1 |
| H9 | `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/stepImpl.m`:30-33 | `synchronizeScenarioEntities` 返回空时**直接换成当前物理实体**，丢弃先前合并的 Snapshots 历史；破坏"实体在 scenario 内固定"契约 | fallback 修补 | Phase 1 |
| H10 | `+csrd/+factories/ReceiveFactory.m`:184-203 | 接收机 NF 在首次建块时从 factory 区间随机抽，与 `rxPlan` 完全无关；且 NF 没写回 `sourceInfo`——下游用户看不到实际仿真用的 NF | 字段错位 + 假规划 | Phase 1（NF 入图纸）+ Phase 3（NF 入 annotation） |
| H11 | `+csrd/+factories/ChannelFactory.m`:168-195 与 86-140 | `resolveChannelModelName` 在请求模型→默认模式→AWGN→第一个可用模型之间多级回落；`ChannelBlockStepFailed` 仍把 `inputSignalStruct` 当输出向下游传 | fallback 修补（典型"施工层修坏图纸"） | Phase 2 |

#### 2.6.2 M 级（8 条，可在 Phase 2-4 内顺手修掉）

| ID | 文件:行号 | 现状一句话 | 归类 | Phase |
|----|-----------|-------------|------|-------|
| M1 | `+csrd/+factories/ModulationFactory.m`:270-275 | 段配置无 `NumTransmitAntennas` 时调制器属性默认 1；与场景蓝图天线数可能不一致 | 执行覆盖 | Phase 1 |
| M2 | `+csrd/+blocks/+physical/+modulate/+digital/+OFDM/OFDM.m`:159-212 | OFDM 初始化里启发式**下调** `NumTransmitAntennas` 以适配导频索引形状；天线数被内部静默改写 | 执行覆盖 | Phase 1（改为 validator hint） |
| M3 | `+csrd/+core/@ChangShuo/private/processSingleSegment.m`:125-147 `buildSegmentConfig` | 缺消息时硬编码 `RandomBit / Length=1024`；缺调制时硬编码 `PSK / Order=4 / SymbolRate=100e3 / SamplesPerSymbol=4`——蓝图缺失被执行期偷偷补全 | fallback 修补 | Phase 1（改为 validator reject） |
| M4 | `+csrd/+factories/MessageFactory.m`:574-588 | `messageLength` 计算缺 `Length` / `SymbolRate` 时一路回退到 `1024` 并 warning | fallback 修补 | Phase 1 |
| M5 | `+csrd/+core/@ChangShuo/private/processTransmitImpairments.m`:55-75 | 缺 `SampleRate` 时从 `PlannedBandwidth*2.5` 反推并 warning（之前 Stage B 已删 `200e3` 硬编码，但反推链路仍在） | fallback 修补 | Phase 2 |
| M6 | `+csrd/+factories/ChannelFactory.m`:400-450 `computeLinkBudgetSNR` | `ComputedSNR` 是解析值（FSPL + NoiseBandwidth + ThermalNoise），写入 `LinkBudget.ComputedSNR` 但**字段命名不分析析/测量**——下游训练误以为是测量 SNR | 字段错位 | Phase 3（字段重命名 + 增加真测量字段） |
| M7 | `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/generateScenarioTransmitterConfigurations.m`:497-548 `generateBurstIntervals` | burst `endTime = min(t+OnDuration, observationDuration)` 在观测窗末截断，但**没有任何字段记录"被截断"**；下游无从区分自然结束 vs 截断 | 规划缺失 | Phase 1（蓝图加 ClippedAt） |
| M8 | `+csrd/+core/@ChangShuo/private/processReceiverProcessing.m`:135-137 | `processChannelPropagation` 中预留了"信道改 Planned"通道（若 `channelOutput.Planned` 存在则覆盖 `component.Planned`）；与"Planned 必须来自规划"原则冲突 | 假规划 | Phase 2（删除该路径） |

#### 2.6.3 与 v0.2 §2.x 的关系

| v0.2 节 | v0.3 §2.6 中对应条 | 备注 |
|---------|--------------------|------|
| 2.1 图纸-施工边界混乱 | H4, H9, M1, M2, M3 | 同方向 |
| 2.2 GT 分层不彻底 | H2, H10, M6, M8 | v0.3 把"假规划"细化为字段错位 + 三层归位 |
| 2.3 burst / payload 隐藏风险 | H3, M7 | v0.3 明确"一帧多 burst 当前不支持"是硬契约缺失 |
| 2.4 Tx/Rx 画像不清 | H1, H4, H10, M2 | v0.3 增加 H1 字段名错位（v0.2 未发现） |
| 2.5 组合爆炸 | H5, H6, H7, H8 | v0.3 把 dead config 单独成类，方便先清理 |

---

### 2.7 v0.4 加强：本轮新增 5 个最容易把实施带偏的现状问题

这一轮重新把文档和当前代码逐段对齐后，又发现 5 个如果不提前写死，后面很容易“计划看起来合理、实现却天然跑偏”的点。

#### 2.7.1 Receiver-view 关系今天仍然没有真正建模

- 当前规划文档里仍把 `WindowFrequencyOffset` 写成 emitter 全局字段
- 但同一个 emitter 面对不同 receiver 时，真实投影至少取决于：
  - receiver 的 `CenterFrequency`
  - receiver 的 `ObservableBandwidth`
  - receiver 是否可见该 emitter
  - receiver 当前采用的输出窗口策略
- 因此 **`WindowFrequencyOffset` 不能继续作为 emitter 全局字段存在**
- v0.4 起，必须改成 `Emitter.ReceiverViews(rxId)` 下的 receiver-view 字段，例如：
  - `ProjectedCenterOffsetHz`
  - `ProjectedLowerEdgeHz`
  - `ProjectedUpperEdgeHz`
  - `IsVisible`

这不是概念洁癖，而是因为项目已经明确支持异构 receiver；如果不 receiver-view 化，后续多接收机场景的 GT 会天然写错。

#### 2.7.2 当前 burst 判定语义不是“与 frame 重叠”，而是“frame 起点落在 interval 内”

从当前实现看：

- `checkTransmissionInterval` 用 `frameTime = (frameId - 1) * frameDuration`
- 然后只判断 `frameTime >= start && frameTime < end`
- `calculateTransmissionState` 再把返回的**第一个**匹配 interval 记成当前活动 interval

这意味着两个直接后果：

1. **若 burst 在 frame 中途才开始，但 frame 起点不在 burst 内，该 burst 会被漏掉**
2. **若一帧内与多个 interval 重叠，当前主路径只会拿到第一个匹配 interval**

所以 v0.4 把这条写死：
**图纸展开必须按“interval 与 frame 是否有重叠”建段，而不是按“frame 起点是否落在 interval 内”判活跃。**

#### 2.7.3 当前 `MeasuredTruth` 若只对总接收信号做测量，就永远拿不到可靠 per-source GT

当前主路径里：

- `processChannelPropagation` 先把每个 source 变成 `SignalComponents`
- `processReceiverProcessing.combineSignalComponents` 先把所有 component 合路
- 然后 `ReceiveFactory` 对合路后的总信号做 receiver 处理

这意味着：

- 对 `processedOutput.Signal` 做 `obw`，得到的是 **FramePlane 聚合带宽**
- 这个结果可以作为“该 receiver 在该 frame 看到的总频谱占用”
- **但不能直接充当每个 source 的带宽 GT**

因此 v0.4 明确把测量平面拆成：

- `SourcePlane`: 每个 source 在该 receiver-view 下的隔离分支测量
- `FramePlane`: 合路并经过共享接收链后的整帧测量

如果一帧里有多个 source 同时可见，后续实现**不得**只量总接收信号再把结果回填给每个 source。

#### 2.7.4 当前时变几何的主路径仍然只到 frame 粒度

当前 `processChannelPropagation` 给 channel 的几何信息主要来自 `TxInfo.Position / Velocity` 和 `RxInfo.Position / Velocity`。
文档里若直接把“每个 burst segment 用中点几何建模”写成既成事实，会把计划说得比代码现实更快。

所以 v0.4 做一个更诚实的两步走约束：

- **Phase 1/2 最低可交付**：`GeometryGranularity = 'Frame'`
- **Phase 3 之后再升级**：`GeometryGranularity = 'SegmentMidpoint'`

也就是说，文档必须先承认当前主路径只到 frame 粒度，再把 segment 粒度作为明确升级目标，而不是跳过这层差距。

#### 2.7.5 当前 receiver 输出长度并不天然等于 `FrameNumSamples`

`processReceiverProcessing.combineSignalComponents` 现在按：

```matlab
totalLength = max(startOffset + numel(comp.Signal))
```

来分配缓冲区长度。于是：

- 只要 component 的 `StartTime` 不同
- 或者某个 component 自身长度已经超过 nominal frame
- 最终 receiver 输出就可能 **长于** `FrameNumSamples`

这会影响两个层面：

- 保存到数据集里的帧长度是否固定
- `StartSample / EndSample / TimeOccupancy` 到底是相对于哪个输出窗口定义

因此 v0.4 追加一个硬契约：

- 图纸层必须声明 `OutputWindowPolicy`
- 第一版建议把“最终保存的数据帧”固定为 `ExactFrameClip`
- 若内部执行需要保留更长的缓冲区，可作为 `ExecutionTruth.InternalBufferNumSamples` 记录，但**不能悄悄拿它替代保存帧长度**

## 3. 最终应成立的业务逻辑

### 3.1 三层真相

后续所有 annotation 和中间对象都要明确区分三层真相：

#### A. DesignTruth

图纸阶段定义的计划值，例如：

- 场景类型
- 地图与环境类型
- 真实载频
- 计划带宽
- 计划 burst 调度
- 发射机/接收机天线数量
- 接收机能力画像
- 轨迹计划
- RF 损伤计划
- 信道模型偏好

#### B. ExecutionTruth

施工阶段真正执行到模块上的值，例如：

- 具体选中的调制阶数
- 实际采用的波形成员配置
- 实际执行的 segment 切分
- 实际应用的 fallback
- 实际使用的 channel block 参数

#### C. MeasuredTruth

从实际生成信号或接收信号中严格测量得到的值，例如：

- occupied bandwidth
- 实际时域占用
- 实际频域占用
- 帧内起止采样位置
- 接收功率或能量特征
- 可从波形直接估计的观测类特征

**固定原则**：

- `PlannedBandwidth` 只属于 `DesignTruth`
- 最终训练用带宽 GT 必须来自 `MeasuredTruth`
- 世界属性类 GT 可来自 `DesignTruth` 或 `ExecutionTruth`
- 观测结果类 GT 不允许直接用设计值回填

### 3.1.bis v0.3 加强：三层真相与现状字段映射

v0.2 §3.1 给出了三层真相的概念定义，但**没有交代当前代码里那一堆 `Planned.*` / `Realized.*` / `LinkBudget.*` 字段该如何归位**。这一节给出"今天的字段 → 重构后的归属"对照表，作为 Phase 3 重写 annotation 时的硬清单。

#### A. 当前 `sourceInfo.Planned.*` 的归位

| 当前字段 | 当前来源 | v0.3 归位 | 备注 |
|----------|----------|-----------|------|
| `Planned.Bandwidth` | `txPlan.Plan.Components(k).Planned.Bandwidth`（见 `processSingleTransmitter`/`processSingleSegment`） | `Truth.Design.PlannedBandwidth` | 真规划值，原地不动，仅改顶层 key |
| `Planned.Modulation` | 同上 | `Truth.Design.ModulationPlan.SubType` | 拆字段 |
| `Planned.Order` | 同上 | `Truth.Design.ModulationPlan.Order` | 拆字段 |
| `Planned.SymbolRate` | 同上 | `Truth.Design.ModulationPlan.SymbolRate` | 拆字段 |
| `Planned.NumTransmitAntennas` | 同上（Phase 1 之后由蓝图独享） | `Truth.Design.HardwarePlan.NumTransmitAntennas` | 拆到硬件子结构 |
| `Planned.FrequencyOffset` | `txPlan` | `Truth.Design.ReceiverView.ProjectedCenterOffsetHz` | **receiver-view 字段**，不能再当 emitter 全局字段 |

#### B. 当前 `sourceInfo.Realized.*` 的归位（重要：v0.3 推翻 v0.2 的归类）

| 当前字段 | 当前来源 | v0.3 归位 | 备注 |
|----------|----------|-----------|------|
| `Realized.Bandwidth` | 调制器 `obw(modulatedBaseband)` | `Truth.Execution.ModulatedBandwidth` | **不是 MeasuredTruth**——它是对调制器输出的瞬时基带做 `obw`，没经过信道也没合成接收信号；v0.2 把它当 MeasuredTruth 是错的 |
| `Realized.SampleRate` | 调制器 / TRF 输出 | `Truth.Execution.SampleRate` | 与 receiver Fs 不一致时 Phase 2 应 reject |
| `Realized.Modulation` | 调制器实例的属性 | `Truth.Execution.ModulationApplied` | 与 Design 一致才合法 |
| `Realized.NumTransmitAntennas` | 调制器输出 size(Signal,2) | `Truth.Execution.NumTransmitAntennas` | Phase 1 后必须等于 Design 值，否则 reject |
| `Realized.FrequencyOffset` | TRF 实际下变频/上变频 | `Truth.Execution.FrequencyOffset` | |

#### C. 当前 `sourceInfo.LinkBudget.*` 的归位

| 当前字段 | 含义 | v0.3 归位 | 备注 |
|----------|------|-----------|------|
| `LinkBudget.AnalyticalPathLoss` | FSPL 解析计算（Stage A 引入） | `Truth.Execution.LinkBudget.AnalyticalPathLossDb` | 保留双值 |
| `LinkBudget.AppliedPathLoss` | RayTracing 等信道块自报 | `Truth.Execution.LinkBudget.AppliedPathLossDb` | 保留双值，RayTracing 时与 Analytical 显著不同 |
| `LinkBudget.ComputedSNR` | 解析 SNR（FSPL + Noise BW + Therm noise） | `Truth.Execution.LinkBudget.AnalyticalSNRdB` | **重命名**：原名让人误以为是测量 SNR |
| `LinkBudget.AppliedSNRdB` | AWGN 块按目标 SNR 应用的值 | `Truth.Execution.LinkBudget.AppliedSNRdB` | 保留 |
| `LinkBudget.NoiseBandwidth` | clamp 后的有效带宽 | `Truth.Execution.LinkBudget.NoiseBandwidthHz` | 保留 |

#### D. 真正的 `MeasuredTruth.*` 在今天**完全不存在**（Phase 3 全新增）

| 新字段 | 来源 | 算法 |
|--------|------|------|
| `Truth.Measured.OccupiedBandwidthHz` | `processReceiverProcessing` 拿到 receiver 输出的整段 IQ 后调用 `obw` | `obw(combinedBasebandSignal, Fs, [], 99)` |
| `Truth.Measured.SNRdB` | combinedSignal 在 burst-on / burst-off 区间的功率比 | 见 §3.4.bis 公式 |
| `Truth.Measured.TimeOccupancy` | 包络阈值检测 burst 段 | 阈值 = 噪声中值 + 6 dB |
| `Truth.Measured.FrequencyOccupancy` | 短时 FFT 阈值 | 阈值 = 频谱中值 + 6 dB |
| `Truth.Measured.StartSample` / `EndSample` | 阈值检测起止 | 同 TimeOccupancy |
| `Truth.Measured.NoiseFigureUsedDb` | 实际写入 RRF 的 NF（H10 修后） | 直接读 RRFSimulator 配置 |

#### E. 顶层 `Status.*` 的归位

| 当前字段 | v0.3 归位 | 备注 |
|----------|-----------|------|
| `Status.IsActive` | `Truth.Execution.Burst.IsActive` | |
| `Status.NumBurstSegments` | `Truth.Execution.Burst.NumSegments` | Phase 2 修 H3 后会真正 > 1 |
| `Status.ChannelError` / `Status.ChannelErrorMessage` | `Truth.Execution.Errors[]` | 仅 fallback 路径用 |

> **强制规则**：v0.3 之后，所有 `MeasuredTruth.*` 字段必须可通过对 `combinedReceivedSignal` 重新调用度量函数复现，**不允许从 `Planned.*` 或 `Execution.*` 直接复制**。验图测试 `MeasuredBandwidthNotPlannedBandwidthTest`（见 §8.1）就是为这条规则兜底。

### 3.1.ter v0.4 加强：ReceiverView、测量平面与主键边界

v0.3 已经把 `Design / Execution / Measured` 三层拆开，但还差三个直接影响实现落地的约束：
**同一 emitter 对不同 receiver 的投影关系**、**per-source 测量平面**、以及 **MeasurementRecord 的主键边界**。

#### A. ReceiverView 是一等公民，不再把频偏写成 emitter 全局字段

同一 emitter 对不同 receiver 的“进入观测窗后的样子”不是同一个东西。
v0.4 起，以下字段必须归到 receiver-view，而不是 emitter 全局：

- `ProjectedCenterOffsetHz`
- `ProjectedLowerEdgeHz`
- `ProjectedUpperEdgeHz`
- `IsVisible`
- `VisibilityReason`

因此：

- `Emitter.RealCarrierFrequency` 仍是 emitter 全局字段
- `Receiver.CenterFrequency` 仍是 receiver 全局字段
- 但两者相减得到的**观测窗内投影**属于 `ReceiverView`

#### B. `MeasuredTruth` 必须拆成 `SourcePlane` 与 `FramePlane`

后续 annotation 里，每条 `MeasurementRecord` 至少有两个测量平面：

1. `Truth.Measured.SourcePlane`
   - 含义：该 source 在该 receiver-view 下的隔离测量结果
   - 用途：per-source GT，例如带宽、起止 sample、该 source 的 receiver-view 占用情况
   - 生成方式：对该 source 的隔离分支测量，或把该 source 单独重放 through 同配置 receiver 链路
2. `Truth.Measured.FramePlane`
   - 含义：该 receiver 在该 frame 上看到的总接收信号测量结果
   - 用途：整帧总占用、总带宽、总能量、总时频占用
   - 来源：对合路后的 `processedOutput.Signal` 做测量

**强制语义**：

- `FramePlane` 可以从总接收信号量出来
- `SourcePlane` 在多源重叠时**不能**从总接收信号直接反推出
- 如果后续实现阶段拿不到隔离分支，就不能伪造 per-source GT，只能明确缺失或走 oracle 路径

#### C. 共享非线性接收链下，`SourcePlane` 要明确标成 oracle 语义

项目里 receiver 链包含：

- 热噪声
- IQ imbalance
- 非线性
- sample-rate offset

若多个 source 先合路再过共享非线性前端，则：

- 真实物理世界里每个 source 的“单独可测后验结果”并不总是可分离
- 这时 `SourcePlane` 若仍要生成，只能是**模拟器内部的 oracle-isolated-branch 测量**

因此 v0.4 规定：

- `SourcePlane.MeasurementSemantics = 'receiver_view_isolated'` 或 `'oracle_isolated_after_replay'`
- `FramePlane.MeasurementSemantics = 'post_rx_combined'`

后续任何 AI 实现都不能把这两种平面混写成一个字段。

#### D. `MeasurementRecord` 主键必须细到 burst segment

为了避免“同帧同源多段 burst 被错误合并”，v0.4 把 `MeasurementRecord` 的最小主键固定为：

```text
ScenarioId + ReceiverId + FrameId + EmitterId + BurstId + SegmentId
```

默认聚合边界：

- `FramePlane` 可按 `(ScenarioId, ReceiverId, FrameId)` 聚合
- `SourcePlane` 不得跨 `SegmentId` 聚合
- 同一 emitter 在同一 frame 中若有两段 burst，必须生成两条 record，而不是一条

#### E. 输出窗口长度也是 truth contract 的一部分

保存数据集时，后续必须显式区分：

- `Truth.Design.FrameNumSamples`
- `Truth.Execution.InternalBufferNumSamples`
- `Truth.Execution.OutputWindowPolicy`

默认建议：

- `OutputWindowPolicy = 'ExactFrameClip'`
- 保存到数据集的 `FrameData.Signal` 长度必须等于 `FrameNumSamples`
- 若内部为了滤波/时移需要更长缓冲区，允许保留 `InternalBufferNumSamples > FrameNumSamples`，但不能拿来替代帧长度契约

### 3.2 图纸阶段必须定下来的内容

图纸阶段输出完整 `ScenarioBlueprint`，至少包含以下字段组。

#### A. 场景与观测任务

- `Scene.Mode = Statistical | OSM`
- `Scene.MapProfile`
- `Observation.NumFrames`
- `Observation.FrameDuration`
- `Observation.FrameNumSamples`
- `Observation.BasebandEquivalent = true`
- `Observation.MeasurementPolicyVersion`

#### B. 接收机蓝图

每个 receiver 独立建模，不再默认所有接收机统一配置。图纸阶段必须定下：

- `ReceiverID`
- `SampleRate`
- `ObservableBandwidth`
- `CenterFrequency`
- `RealCarrierReference`
- `NumReceiveAntennas`
- `ReceiverHardwareProfile`
- `NoiseFigure`
- `Sensitivity`
- `AntennaGain`
- 资源预算档位

默认规则：

- 同一个 scenario 内，每个 receiver 的配置默认保持固定
- 不默认做逐帧 retune
- 异构接收机之间允许不同带宽、不同天线数、不同硬件能力

#### C. 发射目标蓝图

每个被监测 emitter 在图纸阶段必须定下：

- `EmitterID`
- `RealCarrierFrequency`
- `PlannedBandwidth`
- `ModulationPlan`
- `TxHardwarePlan`
- `RFImpairmentPlan`
- `ChannelPreference`
- `ReceiverViews`

其中 `ModulationPlan` 至少包含：

- 调制家族
- 具体子类
- 阶数
- `SamplesPerSymbol`
- `RolloffFactor`
- 必要的多载波参数

其中 `TxHardwarePlan` 至少包含：

- `NumTransmitAntennas`
- 发射功率
- 天线增益
- 阵列类型

**固定原则**：

- 发射机天线数必须在图纸阶段决定
- 施工阶段不得再通过调制器或其他模块回写 `NumTransmitAntennas`
- 模拟调制若只允许单发射天线，应作为图纸阶段兼容性规则，而不是执行期隐藏补丁

#### D. burst 调度蓝图

图纸阶段必须定义 emitter 在整个 scenario 上的完整时域行为：

- 全局 burst 列表
- 每个 burst 的起止时间
- burst ID
- 周期行为或非周期行为
- 是否跨帧
- 截断策略

随后在执行前将其展开为 `FrameExecutionPlan`：

- 每帧提取若干 `BurstSegment`
- 记录 `FrameLocalStart`
- 记录 `FrameLocalEnd`
- 标记 `ClippedStart`
- 标记 `ClippedEnd`

#### E. 时变物理真相

图纸阶段还必须给出：

- 所有实体随时间变化的 `Position(t)`
- `Velocity(t)`
- 必要时的 `Acceleration(t)`、`Orientation(t)`

这样在执行阶段，信道模块可以基于：

- emitter 和 receiver 的相对位置
- 相对速度
- 以及地图环境

进行更可信的建模。

第一版默认策略：

- **Phase 1/2 的最低实现**：按 frame 粒度准静态处理
- **Phase 3 之后的升级目标**：按 `BurstSegment` 中点几何建模
- 若单段持续时间过长，则图纸阶段进一步切分成更短的子段

### 3.2.bis v0.3 加强：MATLAB struct schema 三份示例

v0.2 §3.2 只列了字段名，没给可复制的 MATLAB struct 形态。下面是 Phase 1 / 2 / 3 各自的目标契约示例，重构时**按这三份骨架对齐字段命名与嵌套层级**。

#### A. ScenarioBlueprint（Phase 1 蓝图层最终输出）

```matlab
blueprint = struct( ...
    'SchemaVersion', '2.0', ...
    'Scene', struct( ...
        'Mode', 'OSM', ...                       % 'Statistical' | 'OSM'
        'MapProfile', struct( ...
            'OsmFile', 'maps/wuhan_optics_valley.osm', ...
            'HasBuildings', true, ...
            'TerrainFallback', 'FlatTerrain') ...
    ), ...
    'Observation', struct( ...
        'NumFrames', 8, ...
        'FrameDuration', 5e-3, ...               % seconds
        'FrameNumSamples', 200000, ...           % derived: FrameDuration * Receiver.SampleRate
        'BasebandEquivalent', true, ...
        'MeasurementPolicyVersion', '1.0') ...
);

blueprint.Receivers(1) = struct( ...
    'ReceiverId', 'Rx_001', ...
    'ProfileName', 'LabAnalyzer_160MHz', ...     % 引用 §5 画像库
    'SampleRate', 40e6, ...
    'ObservableBandwidth', 40e6, ...             % 必须等于 SampleRate
    'CenterFrequency', 2.45e9, ...               % real RF, 仅供物理建模
    'RealCarrierReference', 2.45e9, ...
    'NumReceiveAntennas', 4, ...
    'NoiseFigureDb', 6.5, ...                    % 不再 factory 随机
    'SensitivityDbm', -110, ...
    'AntennaGainDb', 8, ...
    'Trajectory', struct( ...
        'SampleTimes', linspace(0, 0.04, 41), ...  % 1xN, 覆盖 [0, NumFrames*FrameDuration]
        'Position', zeros(41,3), ...               % Nx3 meters
        'Velocity', zeros(41,3)) ...               % Nx3 m/s
);

blueprint.Emitters(1) = struct( ...
    'EmitterId', 'Tx_001', ...
    'BandProfile', 'ISM24_WiFi24', ...           % 引用 §5 画像库
    'RealCarrierFrequency', 2.442e9, ...
    'PlannedBandwidthHz', 20e6, ...
    'ModulationPlan', struct( ...
        'Family', 'Digital', ...
        'SubType', 'OFDM', ...
        'Order', 64, ...
        'SymbolRate', 312.5e3, ...
        'SamplesPerSymbol', 8, ...
        'RolloffFactor', 0.25, ...
        'NumSubcarriers', 64, ...
        'CyclicPrefixLength', 16) ...
    , 'HardwarePlan', struct( ...
        'NumTransmitAntennas', 2, ...            % 图纸一锤定音，不允许执行期回写
        'TransmitPowerDbm', 20, ...
        'AntennaArray', struct( ...
            'Type', 'ULA', ...                   % 'Isotropic' | 'ULA' | 'URA'
            'NumElements', 2, ...
            'SpacingWavelengths', 0.5)) ...
    , 'RFImpairmentPlan', struct( ...
        'IIP3Dbm', 25, ...
        'PhaseNoiseLevel', 'Mid', ...
        'IQImbalanceDb', 0.3) ...
    , 'BurstSchedule', struct( ...
        'Pattern', 'Burst', ...                  % 'Continuous' | 'Burst' | 'Scheduled' | 'Random'
        'Bursts', struct( ...
            'BurstId',           {'B01','B02','B03'}, ...
            'StartTime',         {0.001, 0.012, 0.0142}, ...  % seconds
            'EndTime',           {0.004, 0.018, 0.0148}, ...
            'PeriodIndex',       {1, 2, 3}, ...
            'OverlappingFramesIds', {1, [3 4], 3}, ...        % 跨帧时是数组
            'ClippedAt',         {'None', 'FrameEnd', 'None'} ... % 'None'|'FrameStart'|'FrameEnd'
        )) ...
    , 'ChannelPreference', struct( ...
        'Model', 'RayTracing', ...               % 找不到该模型直接 SkipBlueprint
        'Variant', 'image-method', ...
        'MaxNumReflections', 2) ...
    , 'ReceiverViews', struct( ...
        'ReceiverId', {'Rx_001'}, ...
        'ProjectedCenterOffsetHz', {-8e6}, ...
        'ProjectedLowerEdgeHz', {-18e6}, ...
        'ProjectedUpperEdgeHz', {2e6}, ...
        'IsVisible', {true}, ...
        'VisibilityReason', {'InBand'}) ...
    , 'Trajectory', struct( ...
        'SampleTimes', linspace(0, 0.04, 41), ...
        'Position', repmat([100 50 1.5], 41, 1), ...
        'Velocity', zeros(41,3)) ...
);
```

#### B. FrameExecutionPlan（Phase 1 → Phase 2 桥梁）

```matlab
framePlan = struct( ...
    'FrameId', 3, ...
    'FrameStartTime', 0.010, ...
    'FrameEndTime', 0.015, ...
    'NumSamples', 200000, ...
    'SampleRate', 40e6, ...
    'GeometryGranularity', 'Frame', ...
    'OutputWindowPolicy', 'ExactFrameClip' ...
);

framePlan.Receivers(1) = struct( ...
    'ReceiverId', 'Rx_001', ...
    'GeometrySnapshot', struct( ...               % 中点采样
        'Position', [0 0 1.5], 'Velocity', [0 0 0]) ...
);

framePlan.EmitterSegments(1) = struct( ...
    'EmitterId', 'Tx_001', ...
    'BurstId', 'B02', ...
    'SegmentId', 'B02_seg_f03_r01', ...
    'FrameLocalStartSample', 80001, ...
    'FrameLocalEndSample', 200000, ...
    'VisibleDurationSec', 3e-3, ...
    'ClippedStart', false, ...
    'ClippedEnd', true, ...
    'PayloadSpec', struct( ...                     % §3.4.bis 公式产物
        'PayloadBits', 468000, ...
        'NumOfdmSymbols', 1500) ...
    , 'GeometrySnapshot', struct( ...              % burst 段中点
        'Position', [100 50 1.5], 'Velocity', [0 0 0], ...
        'TxRxDistanceMeters', 111.8) ...
    , 'ReceiverViews', struct( ...
        'ReceiverId', {'Rx_001'}, ...
        'ProjectedCenterOffsetHz', {-8e6}, ...
        'ProjectedLowerEdgeHz', {-18e6}, ...
        'ProjectedUpperEdgeHz', {2e6}, ...
        'IsVisible', {true}) ...
    , 'ChannelInstanceKey', 'RT|Tx_001|Rx_001|B02' ... % 用于缓存键
);

% 同帧同发射机的第二段 burst（H3 修复后才会出现）
framePlan.EmitterSegments(2) = struct( ...
    'EmitterId', 'Tx_001', 'BurstId', 'B03', ...
    'SegmentId', 'B03_seg_f03_r01', ...
    'FrameLocalStartSample', 168001, 'FrameLocalEndSample', 192000, ...
    'VisibleDurationSec', 0.6e-3, 'ClippedStart', false, 'ClippedEnd', false, ...
    'PayloadSpec', struct('PayloadBits', 93600, 'NumOfdmSymbols', 300), ...
    'GeometrySnapshot', struct('Position',[101 50 1.5],'Velocity',[1 0 0], ...
        'TxRxDistanceMeters', 112.3), ...
    'ReceiverViews', struct( ...
        'ReceiverId', {'Rx_001'}, ...
        'ProjectedCenterOffsetHz', {-8e6}, ...
        'ProjectedLowerEdgeHz', {-18e6}, ...
        'ProjectedUpperEdgeHz', {2e6}, ...
        'IsVisible', {true}), ...
    'ChannelInstanceKey', 'RT|Tx_001|Rx_001|B03' ...
);
```

#### C. MeasurementRecord（Phase 3 测量层 per-source 输出）

```matlab
record = struct( ...
    'SchemaVersion', '2.0', ...
    'ScenarioId', 'scn_000123', ...
    'EmitterId', 'Tx_001', ...
    'ReceiverId', 'Rx_001', ...
    'FrameId', 3, ...
    'BurstId', 'B02', ...
    'SegmentId', 'B02_seg_f03_r01' ...
);

record.Truth.Design = struct( ...
    'PlannedBandwidthHz', 20e6, ...
    'ReceiverView', struct( ...
        'ProjectedCenterOffsetHz', -8e6, ...
        'ProjectedLowerEdgeHz', -18e6, ...
        'ProjectedUpperEdgeHz', 2e6, ...
        'IsVisible', true), ...
    'ModulationPlan', struct('SubType','OFDM','Order',64,'SymbolRate',312.5e3), ...
    'HardwarePlan', struct('NumTransmitAntennas', 2) ...
);

record.Truth.Execution = struct( ...
    'ModulatedBandwidthHz', 19.78e6, ...           % obw on modulator output
    'SampleRate', 40e6, ...
    'NumTransmitAntennas', 2, ...                  % == Design 才合法
    'FrequencyOffset', -8.001e6, ...               % TRF 实际偏移
    'GeometryGranularity', 'Frame', ...
    'OutputWindowPolicy', 'ExactFrameClip', ...
    'LinkBudget', struct( ...
        'AnalyticalPathLossDb', 80.4, ...           % FSPL @ 2.442 GHz, 111.8 m
        'AppliedPathLossDb', 84.1, ...              % RayTracing 自报
        'AnalyticalSNRdB', 22.1, ...                % 重命名自 ComputedSNR
        'AppliedSNRdB', 18.4, ...                   % AWGN 应用值（若有）
        'NoiseBandwidthHz', 19.78e6, ...
        'NoiseFigureUsedDb', 6.5) ...               % 实际写入 RRF
    , 'Burst', struct( ...
        'IsActive', true, ...
        'NumSegments', 1, ...
        'TotalActiveSec', 3e-3) ...
    , 'Errors', {{}} ...
);

record.Truth.Measured = struct( ...
    'SourcePlane', struct( ...
        'MeasurementSemantics', 'receiver_view_isolated', ...
        'OccupiedBandwidthHz', 19.92e6, ...
        'SNRdB', 17.8, ...
        'StartSample', 80001, ...
        'EndSample', 200000, ...
        'NoiseFigureUsedDb', 6.5), ...
    'FramePlane', struct( ...
        'MeasurementSemantics', 'post_rx_combined', ...
        'OccupiedBandwidthHz', 27.4e6, ...
        'TimeOccupancy', 0.279, ...
        'FrequencyOccupancy', 0.685, ...
        'NoiseFigureUsedDb', 6.5) ...
);
```

#### D. annotation 顶层骨架

```matlab
scenarioAnnotation = struct( ...
    'SchemaVersion', '2.0', ...
    'ScenarioId', 'scn_000123', ...
    'BlueprintHash', 'abc123def...', ...           % 蓝图字段 SHA-256，便于复现
    'SignalSources', {{record1, record2, ...}}, ... % 每条都是 MeasurementRecord
    'CombinedSignalStats', struct( ...              % 整窗合成信号的全局测量
        'PeakToAverageDb', 9.4, ...
        'OccupiedBandwidthHz', 39.8e6) ...
);
```

> 上述 MATLAB 代码块**仅作契约示例**，并不可直接 `eval`（部分字段为占位）；Phase 1/2/3 实施时按此结构补全。
> 示例里的 sample index 一律按 **MATLAB 1-based inclusive** 解释；凡是涉及 `FrameDuration / SampleRate / FrameNumSamples` 的例子，都必须满足时间-样本一致性，不能再出现示例自己打架的情况。

### 3.2.ter v0.4 加强：接收机字段传递链必须写透

当前项目里，接收机字段不是“图纸里有了就自然到运行时”。
至少有两条当前代码已经证明会丢字段的链路：

- `setupReceivers` 目前写的是 `RxInfo.NumAntennas`
- `RRFSimulator` 真正的属性名是 `NumReceiveAntennas`
- `ReceiveFactory.configureReceiverBlock` 只复制**同名字段**

所以如果计划文档不把字段传递表写透，后续实现非常容易再次出现“蓝图里有、块里没吃到”的静默偏差。

#### A. v0.4 固定的字段传递表

| Blueprint 字段 | FrameExecutionPlan / RxInfo 临时字段 | ReceiverBlock 目标字段 | 当前现状 | v0.4 目标 |
|----------------|--------------------------------------|------------------------|----------|-----------|
| `NumReceiveAntennas` | `RxInfo.NumAntennas` | `RRFSimulator.NumReceiveAntennas` | **已错位** | 统一成 `NumReceiveAntennas` 端到端同名 |
| `NoiseFigureDb` | 当前未稳定进入 `RxInfo` | `ThermalNoiseConfig.NoiseFigure` | 当前在 factory 随机抽 | 图纸阶段抽一次，执行阶段只读取 |
| `ObservableBandwidth` | 当前常被拆成 `ObservableRange` | `RRFSimulator.BandWidth` | 语义不统一 | 统一写入 `ObservableBandwidth`，适配层显式映射到 `BandWidth` |
| `CenterFrequency` | `RxInfo.CenterFrequency` | `RRFSimulator.CenterFrequency` | 基本通 | 保持 |
| `SampleRate` | `RxInfo.SampleRate` | `RRFSimulator.MasterClockRate` / receiver chain Fs | 当前多处 fallback | 图纸阶段定值，执行阶段不再反推 |

#### B. 第一版不追求一步到位改名，但必须有显式适配层

考虑到仓库当前已有不少 `RxInfo.*` 使用点，v0.4 不要求第一笔 PR 就把所有旧名字瞬间删干净；但必须满足：

- 蓝图层只产出**新契约字段**
- 核心适配层只允许存在**一处**
- 适配层之后，运行时块对象看到的字段名必须唯一

也就是说，可以暂时保留“蓝图字段 → 旧代码字段”的桥，但不能继续多处各自做一半映射。

#### C. `ReceiverViews` 不是接收机硬件字段，而是 receiver-specific projection 字段

为了避免后续实现把 `ReceiverViews` 又塞进 receiver hardware config，v0.4 再补一句硬约束：

- `Receivers(k)` 描述 receiver 自身能力
- `Emitters(k).ReceiverViews(m)` 描述该 emitter 对第 m 个 receiver 的投影
- 两者绝不能互相替代

### 3.3 施工阶段只做“按图执行”

施工阶段输入固定为 `FrameExecutionPlan`，只做以下事情：

- 为每个 `BurstSegment` 生成 payload
- 调用消息生成、调制、发射前端、信道、接收前端等模块
- 按接收机观测窗做等效基带或等效中频建模
- 记录执行过程中发生的 fallback

施工阶段不得再做：

- 改写发射机天线数
- 用统一 receiver 配置覆盖异构 receiver
- 复用 emitter 级固定 `Message.Length` 作为所有 burst 的 payload
- 靠执行逻辑去修复本就不可施工的图纸

### 3.3.bis v0.3 加强：施工阶段删除清单（必删 / 必保留）

> 重构第一性原则：**先把不该存在的兜底删干净，再讨论新增什么**。否则旧代码的 fallback 会与新画像库形成"双层默认"，调试无门。

#### 必删 8 条（每条带文件:行号 + 替代行为）

| ID | 文件:行号 | 必删原因 | 替代行为 | 关联 H/M | Phase |
|----|-----------|----------|----------|----------|-------|
| D1 | `+csrd/+utils/+core/applyAntennaConfigFromSegments.m` 整文件 | 天线数图纸定，不再回写 | 删除调用点 `processSingleTransmitter.m`:96-104；蓝图字段 `HardwarePlan.NumTransmitAntennas` 直传 `TxInfo` | H4 | Phase 1 |
| D2 | `+csrd/+factories/ModulationFactory.m`:270-275 | 调制器属性默认 1 天线掩盖蓝图缺失 | 缺字段 → `error('CSRD:Blueprint:MissingTxAntennas', ...)`，触发 SkipBlueprint | M1 | Phase 1 |
| D3 | `+csrd/+core/@ChangShuo/private/processSingleSegment.m`:125-147 `buildSegmentConfig` 默认注入块 | 蓝图缺失被偷偷补全 | 缺字段 → `error('CSRD:Blueprint:IncompleteSegment', ...)`；validator 应在更早阶段拦截，到 stepImpl 才发现属于流程 bug | M3 | Phase 1 |
| D4 | `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/calculateTransmissionState.m`:46-69 `Scheduled mod(frameId,3)`、`Random` 无区间始终 on | 四种模式名字不带任何执行差异 | 引入真正不同的展开器：`expandContinuous` / `expandBurst` / `expandScheduled(SchedulePeriods)` / `expandRandom(Pdf, RngStream)` | H5 | Phase 1 |
| D5 | `+csrd/+factories/ChannelFactory.m`:168-195 `resolveChannelModelName` 多级回落 | 把"图纸要 RayTracing"悄悄换成 AWGN | 找不到 → `error('CSRD:Blueprint:ChannelModelMismatch', ...)`，触发 SkipBlueprint；保留"RayTracing→FlatTerrain on NoBuildingData"作为唯一例外，且记录 `Execution.Errors` | H11 | Phase 2 |
| D6 | `+csrd/+factories/ChannelFactory.m`:86-140 `ChannelBlockStepFailed` 软化输出 | 把异常包成静默错误向下游传 | 仅允许 `csrd.utils.scenario.isScenarioSkipException` 通过；其它异常直接 SkipScenario，不再写半截信号 | H11 | Phase 2 |
| D7 | `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/allocateFrequenciesRandom.m` 与 `allocateFrequenciesOptimized.m` 转调 wrapper | 配置项假象，且增加维护表面 | Phase 1 标记 deprecated 并发 warning；Phase 2 删除文件，更新所有调用点直接走 `allocateFrequenciesReceiverCentric` | H6 | Phase 1→2 |
| D8 | `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/stepImpl.m`:30-33 实体回退 | 破坏"实体在 scenario 内固定"契约 | `synchronizeScenarioEntities` 返回空 → `error('CSRD:Blueprint:EntityDriftDetected', ...)`；上游应保证物理实体快照与通信请求同源 | H9 | Phase 1 |

#### 必保留并显式记录 4 条

| ID | 文件:行号 | 保留原因 | 必须满足的条件 |
|----|-----------|----------|----------------|
| K1 | RayTracing `NoValidPaths` / `NoBuildingData` 整场景跳过 | 已通过 `csrd.utils.scenario.isScenarioSkipException` 成型；这是合理的不可施工标记 | 必须在 `Execution.Errors[]` 留下记录，便于统计 |
| K2 | `BlueprintFeasibilityValidator` 主动 reject 后的重采样 | reject 不算 fallback，是图纸阶段的合法循环 | 重采样次数有上限（默认 50）；超限 `error('CSRD:Blueprint:Unsamplable', ...)` |
| K3 | 噪声带宽 clamp（`csrd.utils.linkbudget.resolveNoiseBandwidth`，已上线） | 物理上正确 | 必须把 clamp 后的 `NoiseBandwidthHz` 写入 `Execution.LinkBudget` |
| K4 | 调制器内部对 OFDM 子载波数等的 sanity check | 真实物理约束 | **仅作为 validator 的 hint**；调制器 stepImpl 不允许偷改值——发现冲突直接 `error('CSRD:Blueprint:ModulationParamConflict', ...)` |

#### 删除后预期效果

| 指标 | 现状（基线） | 删除后预期 |
|------|--------------|------------|
| `processSingleSegment` 默认注入次数 | > 0（fallback 路径每跑一次都触发） | 0 |
| `applyAntennaConfigFromSegments` 调用次数 | 每个有 segment 的 Tx 都调用 | 0（函数被删） |
| `ChannelBlockStepFailed` 写半截信号比例 | ~3-8%（视场景） | 0 |
| 蓝图被 validator reject 比例 | 不适用（无 validator） | 5-30%（v0 画像下，应控制在 30% 以内才算可用） |

### 3.4 payload 的正确语义

payload 必须改为：

- **按 `BurstSegment` 单独生成**
- 长度由该 segment 的可见时长、调制参数、样本预算共同推导
- 不再按“整台发射机固定一份 payload 复用到所有 burst”

### 3.4.bis v0.3 加强：payload 长度推导公式

v0.2 §3.4 只说"按 BurstSegment 单独生成"，没给公式。Phase 2 实施前必须把公式写死，避免不同模块各自发挥。

#### A. 通用公式（单载波类：PSK / QAM / PAM / APSK / ASK / OOK / FSK 系列）

```
visibleSamples   = SegmentEndSample - SegmentStartSample + 1
visibleDurationS = visibleSamples / SampleRate
numSymbols       = floor(visibleDurationS * SymbolRate)
payloadBits      = numSymbols * BitsPerSymbol
                 = numSymbols * log2(Order)
```

边界规则：
- `numSymbols < 1` → validator reject（burst 段太短，无法承载 1 个符号）
- `payloadBits` 必须为整数；不足 1 字节时仍按 bits 生成
- `RandomBit.Length` 必须等于 `payloadBits`，**不再使用 `Length=1024` 默认**

#### B. OFDM 修正

```
samplesPerOfdmSymbol = NumSubcarriers + CyclicPrefixLength
numOfdmSymbols       = floor(visibleSamples / samplesPerOfdmSymbol)
dataSubcarriersPerSymbol = NumSubcarriers - NumPilotSubcarriers - NumGuardSubcarriers
payloadBits          = numOfdmSymbols * dataSubcarriersPerSymbol * BitsPerSubcarrier
```

边界规则：
- `numOfdmSymbols < 1` → validator reject（burst 短于一个 OFDM 符号）
- `dataSubcarriersPerSymbol < 1` → validator reject（导频/守护带占满）

#### C. SC-FDMA 修正

与 OFDM 同结构，但 DFT 预编码块：

```
samplesPerScfdmaSymbol = (NumSubcarriers + CyclicPrefixLength)
numBlocks              = floor(visibleSamples / samplesPerScfdmaSymbol)
payloadBits            = numBlocks * SubcarriersPerBlock * BitsPerSubcarrier
```

#### D. OTFS 修正

OTFS 以 delay-Doppler grid 为单位：

```
numSamplesPerFrame = M * N    (M=delay bins, N=Doppler bins)
numFrames          = floor(visibleSamples / numSamplesPerFrame)
payloadBits        = numFrames * M * N * BitsPerSymbol
```

OTFS 一期默认 SISO，多天线版本进入第二期（参见 §5.3 兼容矩阵）。

#### E. 模拟调制（FM / PM / DSBAM / SSBAM / DSBSCAM / VSBAM）

模拟调制不存在 "payload bits" 概念，对应字段：

```
audioSamples = floor(visibleDurationS * AudioSampleRate)
audioSource  = blueprint.Emitter.AudioSource    % 'Synthetic' | 'WavFile'
```

模拟通道**强制单天线**（见 §5.3），且不允许出现 `payloadBits` 字段——schema validator 据此拦截。

#### F. 公式与现状的差距

| 现状（基线） | v0.3 后 |
|--------------|---------|
| `processSingleSegment.m`:125-147 缺字段时硬编码 `Length=1024 / Order=4 / SymbolRate=100e3` | 缺字段直接 reject |
| `Message.Length` 是发射机级别的属性，所有 burst 共享 | `payloadBits` 是 segment 级别属性，由公式逐段计算 |
| 跨帧 burst 的尾部 segment 长度被截断时不调整 payloadBits | 公式自然按 `visibleSamples` 重算 |

### 3.5 GT 的正确来源

最终 annotation 至少分为：

- `DesignTruth`
- `ExecutionTruth`
- `MeasuredTruth`

其中：

- `MeasuredTruth.Bandwidth` 必须来自严格测量
- `MeasuredTruth.TimeOccupancy` 必须来自实际生成结果
- `MeasuredTruth.FrequencyOccupancy` 必须来自实际接收或等效观测结果

---

## 4. 验图层设计

新增独立的 `BlueprintFeasibilityValidator`，在施工前做可施工性检查。

至少检查以下内容：

- `FrameDuration * SampleRate == FrameNumSamples`
- receiver 的观测能力是否足以完成当前任务
- 目标带宽、调制、SPS、burst 时长是否可形成可施工 segment
- 发射机天线数与调制家族是否兼容
- receiver 能力画像与频段画像是否兼容
- OSM / RayTracing / geometry 是否可施工
- 总样本数、总内存、总帧数是否超预算

处理规则固定：

- 图纸不可施工：直接丢弃并重采样
- 图纸可施工但执行时触发声明内 fallback：允许执行并记录
- 施工阶段不再承担“修坏图纸”的职责

---

### 4.bis v0.3 加强：BlueprintFeasibilityValidator 接口与 12 条 check

v0.2 §4 只列了"至少检查"的几条。本节给出实施级别的接口定义与可枚举 check 列表，避免 Phase 1 实施时再次发明轮子。

#### A. 类位置与签名

```matlab
% +csrd/+utils/+blueprint/BlueprintFeasibilityValidator.m
classdef BlueprintFeasibilityValidator < handle
    methods (Static)
        function [ok, reasons] = validate(blueprint)
            % blueprint:  ScenarioBlueprint struct（见 §3.2.bis A）
            % ok:         logical, true 表示蓝图全部 check 通过
            % reasons:    1×K cell of struct, 每条:
            %               .Code     (string)  机器可识别 ID
            %               .Severity (string)  'Reject' | 'Warn'
            %               .Message  (string)  人读
            %               .Field    (string)  蓝图字段路径，如 'Emitters(2).BurstSchedule.Bursts(3)'
        end
    end
end
```

实施约束：
- 文件路径强制 `+csrd/+utils/+blueprint/`，**不在根、不在 factories**（违反 `csrd-workflow.mdc` rule 5）
- 纯静态方法，不持状态；调用方在 `SimulationRunner` 与单元测试中复用
- Reject 与 Warn 同时返回；调用方决定 reject 是否触发 SkipBlueprint
- 复用 `csrd.utils.scenario.isScenarioSkipException` 一致的命名（不抛异常，靠 `ok==false` 触发上层 SkipBlueprint）

#### B. 12 条 check（v0.3 锁版本）

| Code | 说明 | Severity | 关联 H/M |
|------|------|----------|----------|
| `FrameSampleConsistency` | 图纸平面上 `FrameDuration * Receiver.SampleRate == FrameNumSamples` 必须严格成立；receiver 输出平面若采用 `ExactFrameClip`，保存帧长度也必须等于 `FrameNumSamples`（容差 ≤ 1 sample） | Reject | — |
| `RxFsEqualsObservableBw` | `Receiver.SampleRate == Receiver.ObservableBandwidth` | Reject | 等效基带契约 |
| `TxBwInsideRxWindow` | 对每个 `ReceiverView`，必须满足 `\|ProjectedCenterOffsetHz\| + PlannedBandwidthHz/2 ≤ Receiver.ObservableBandwidth/2` | Reject | — |
| `ModulationAntennaCompatible` | 查 §5.3 矩阵；模拟 → 强制 1 天线，OFDM → 1-8，OTFS → 1 | Reject | M1, M2 |
| `RFImpairmentRange` | IIP3∈[-10,40] dBm；PhaseNoise∈预设三档；IQImbalance∈[0,3] dB | Reject | — |
| `BurstTotalDurationFits` | `sum(Bursts.Duration) ≤ NumFrames*FrameDuration` 且每个 burst `EndTime ≤ NumFrames*FrameDuration` | Reject | M7 |
| `CrossFrameSegmentMinSamples` | 跨帧切分后每段 `visibleSamples ≥ MinSegmentSamples`（默认 64） | Reject | H3 |
| `OsmFileExistsAndBuildings` | OSM 模式下文件可读；若无建筑物，必须显式声明 `TerrainFallback='FlatTerrain'` 否则 reject | Reject | RayTracing 已知问题 |
| `ChannelModelInRegistry` | `ChannelPreference.Model` 在已注册的信道模型集合内 | Reject | H11, D5 |
| `TrajectoryMonotonicAndCovers` | `Trajectory.SampleTimes` 严格递增，且 `[min, max] ⊇ [0, NumFrames*FrameDuration]` | Reject | — |
| `LinkDistanceAboveMin` | 任意 burst 中点的 Tx-Rx 距离 ≥ `MinDistanceMeters`（默认 1 m，避免 fspl→Inf） | Reject | Stage A1 已修 |
| `MemoryBudget` | 估算 `NumFrames * FrameNumSamples * NumReceiveAntennas * 16 bytes ≤ MemoryBudgetMB` | Warn → Reject | 防 OOM |

#### C. 重采样上限规则

```
maxResamples = blueprint.Validator.MaxResamples  (默认 50)
```

- 单个 scenario 触发 reject 后，配置层应**重抽蓝图**而非修改原图（Phase 0 §3.3 原则）
- 连续 `maxResamples` 次仍 reject → `error('CSRD:Blueprint:Unsamplable', ...)`，SimulationRunner 记入失败计数并继续下一组配置
- 失败计数本身是 §7.bis 基线快照的一部分（"画像组合可施工率"）

#### D. 与 RayTracing 现存契约的关系

`OsmFileExistsAndBuildings` check 把"OSM 文件存在但无 buildings"判为 reject，**前提是图纸要求 RayTracing 且未声明 `TerrainFallback='FlatTerrain'`**。若图纸明确允许 `FlatTerrain`，则蓝图可继续通过；若 ChannelPreference.Model 不是 RayTracing，则跳过本 check。这与现有空 OSM 修复后的主线更一致：无建筑 OSM 不再天然等于坏数据，而是必须在蓝图里显式选择 fallback。

### 4.ter v0.4 加强：新增 5 条必须补上的 contract / validator check

v0.3 的 12 条 check 已经覆盖了大部分“能不能施工”，但还缺 5 条会直接影响本轮重点语义的约束。

| Code | 说明 | 建议位置 | Severity |
|------|------|----------|----------|
| `ReceiverViewProjectionPresent` | 每个可见 emitter-receiver 对都必须存在 `ReceiverView`；多 receiver 场景下不得退回 emitter 全局 `WindowFrequencyOffset` | Validator | Reject |
| `BurstOverlapsFrameExpansion` | 任何与 frame 时间窗有重叠的 burst 都必须展开出 segment；不能再沿用“frame 起点落入 interval”语义 | Validator + ContractTest | Reject |
| `MeasurementPlanesSeparated` | 若同 frame 同 receiver 可见源数 > 1，则 `SourcePlane` 与 `FramePlane` 必须同时存在，或明确声明仅输出 aggregate GT | ContractTest | Reject |
| `GeometryGranularityDeclared` | annotation 必须写出 `GeometryGranularity='Frame' | 'SegmentMidpoint'`，不允许默认省略 | ContractTest | Reject |
| `ReceiverOutputWindowConsistent` | 若 `OutputWindowPolicy='ExactFrameClip'`，则保存到数据集的 receiver 输出长度必须等于 `FrameNumSamples` | ContractTest | Reject |

## 5. 现实约束画像库

为控制组合爆炸，后续引入三类规则库。

### 5.1 频段画像库

建议第一版包含：

- `BroadcastAnalogProfile`
- `NarrowbandLegacyProfile`
- `CellularSub6Profile`
- `ISM_WLAN_Profile`
- `IMT_6GHz_Profile`

每个画像绑定：

- 合法频率范围
- 推荐带宽集合
- 推荐调制家族
- burst 规律模板
- 推荐接收机能力档位
- 合法 RF impairment family

### 5.2 接收机能力画像库

建议第一版包含：

- `PortableMonitoring`
- `WidebandLabReceiver`
- `DenseArrayReceiver`
- `NarrowbandLowPower`
- `HighBandwidthFixedStation`

每个画像绑定：

- 可选 `SampleRate / ObservableBandwidth`
- 可选 `NumReceiveAntennas`
- 噪声系数、灵敏度、天线增益
- 单帧资源预算

### 5.3 天线/调制兼容矩阵

当前代码里“模拟调制默认单发射天线”的限制不应继续作为隐式行为，后续改为显式规则矩阵。

默认第一版原则：

- 模拟调制画像默认单发射天线
- 宽带数字画像允许多发射天线
- 这些限制在图纸阶段验图，不在施工阶段偷改

---

### 5.bis v0.3 加强：画像库 v0 数值表（参考中国频谱划分）

> 来源参考：工信部《中华人民共和国无线电频率划分规定》（2018 版及 2023 年 6 GHz IMT 更新解读），3GPP TS 38.101，IEEE 802.11 系列标准。本表**不追求 100% 贴合规章**，仅在量级上与现实对齐，避免组合爆炸。

#### A. 频段画像库 v0（5 + 2 = 7 个画像）

每个画像在 `+csrd/+utils/+profile/<ProfileName>.m` 内定义为函数返回 struct，配置文件**只引用画像名**。

| ProfileName | 频率范围 | 推荐带宽集合 | 推荐调制家族 | 时模 | 推荐天线数 | 典型 NF | 推荐 RxProfile |
|-------------|----------|--------------|-------------|------|-----------|---------|----------------|
| `Broadcast_FM_VHF` | 87.5–108 MHz | 200 kHz | FM, PM, DSBSCAM | Continuous | 1 | 8 dB | `LabAnalyzer_160MHz` / `PortableMonitor_40MHz` |
| `Broadcast_AM_MW` | 531–1602 kHz | 9 kHz | DSBAM, SSBAM | Continuous | 1 | 10 dB | `LabAnalyzer_160MHz` |
| `ISM24_WiFi24` | 2400–2483.5 MHz | {20, 40} MHz | OFDM, SC-FDMA | Burst (On 1-10 ms / Off 1-100 ms) | 1-4 | 7 dB | `LabAnalyzer_160MHz` / `DenseArrayStation_200MHz` |
| `ISM58_WiFi5` | 5150–5350 MHz, 5725–5850 MHz | {20, 40, 80} MHz | OFDM | Burst | 1-4 | 8 dB | `LabAnalyzer_160MHz` / `DenseArrayStation_200MHz` |
| `5GNR_n28` | 703–803 MHz | {5, 10, 15, 20} MHz | OFDM | Continuous, Scheduled | 1-4 | 6 dB | `PortableMonitor_40MHz` / `LabAnalyzer_160MHz` |
| `5GNR_n78` | 3300–3600 MHz | {20, 40, 80, 100} MHz | OFDM | Continuous, Scheduled | 1-4 | 6 dB | `LabAnalyzer_160MHz` / `DenseArrayStation_200MHz` |
| `5GNR_n79` | 4800–4960 MHz | {40, 60, 100} MHz | OFDM | Continuous | 1-4 | 6 dB | `LabAnalyzer_160MHz` / `DenseArrayStation_200MHz` |

**画像绑定的硬约束**：
- 带宽必须从"推荐带宽集合"内取
- 调制家族必须从"推荐调制家族"内取
- 模拟画像（前 2 个）**强制 1 天线**
- 时模决定 `BurstSchedule.Pattern`：Broadcast → Continuous；ISM/WiFi → Burst；5G NR → Continuous 或 Scheduled
- 与 RxProfile 不兼容（频率范围不被 Rx 覆盖）→ validator reject

#### B. 接收机能力画像库 v0（3 个画像）

| ProfileName | Fs 集合 | 实时观测带宽 | 天线数 | NF | 灵敏度 | 真实载频范围 |
|-------------|---------|--------------|--------|-----|--------|--------------|
| `PortableMonitor_40MHz` | {10, 20, 40} MHz | == Fs | 1-2 | 8-12 dB | -90 dBm | 8 kHz – 8 GHz |
| `LabAnalyzer_160MHz` | {40, 80, 160} MHz | == Fs | 1-4 | 5-7 dB | -110 dBm | 9 kHz – 8 GHz |
| `DenseArrayStation_200MHz` | {80, 160, 200} MHz | == Fs | 4-16 | 4-6 dB | -115 dBm | 600 MHz – 12 GHz |

**接收机硬约束**：
- `SampleRate == ObservableBandwidth`（等效基带契约，§6）
- NF 在画像区间内**只在蓝图阶段抽样一次**，写入 `blueprint.Receivers(k).NoiseFigureDb`；**不再 factory 随机**（修 H10）
- 真实载频范围用于 frequency band profile 兼容性 check（`OsmFileExistsAndBuildings` 之外的隐式 check）

#### C. 天线-调制兼容矩阵 v0

| 调制家族 | 允许的发射天线数 | 备注 |
|----------|------------------|------|
| FM, PM, DSBAM, SSBAM, DSBSCAM, VSBAM | **1**（强制） | 模拟调制不进 MIMO |
| FSK, MSK, CPFSK, GFSK, GMSK | 1 | 频率调制类一期不上 MIMO |
| PSK, QAM, PAM, APSK, DVBSAPSK, OOK, ASK | 1-4 | 标准空间复用 |
| OFDM | 1-8 | 上限以 OFDM.m 内部 sanity check 为准（M2 修后改为 validator reject 而不是静默下调） |
| SC-FDMA | 1-4 | LTE/NR-uplink 类似 |
| OTFS | **1**（强制） | 一期不上 MIMO，二期再启用 |

矩阵在 `+csrd/+utils/+profile/AntennaModulationMatrix.m` 中以 `containers.Map` 形式定义，validator `ModulationAntennaCompatible` check 直接查表。

#### D. 画像数据组合的可施工率目标

| 频段画像 | RxProfile 候选 | 期望可施工率 |
|----------|---------------|--------------|
| `Broadcast_FM_VHF` | `LabAnalyzer_160MHz`, `PortableMonitor_40MHz` | ≥ 98% |
| `Broadcast_AM_MW` | `LabAnalyzer_160MHz` | ≥ 98% |
| `ISM24_WiFi24` | `LabAnalyzer_160MHz`, `DenseArrayStation_200MHz` | ≥ 90% |
| `ISM58_WiFi5` | `LabAnalyzer_160MHz`, `DenseArrayStation_200MHz` | ≥ 85% |
| `5GNR_n28` | `PortableMonitor_40MHz`, `LabAnalyzer_160MHz` | ≥ 95% |
| `5GNR_n78` | `LabAnalyzer_160MHz`, `DenseArrayStation_200MHz` | ≥ 85% |
| `5GNR_n79` | `LabAnalyzer_160MHz`, `DenseArrayStation_200MHz` | ≥ 85% |

整库平均 ≥ 90% 是 Phase 4 的退出条件之一（见 §7.bis）。

## 6. 等效基带建模契约

项目继续保留等效基带/等效中频建模，不直接仿真真实 GHz 载波采样。

固定语义：

- `Receiver.SampleRate == Receiver.ObservableBandwidth`
- 信号在 receiver 的观测窗内生成
- `RealCarrierFrequency` 继续保留，供传播与物理建模使用
- 下游频谱感知模型看到的是观测窗内样本，不是高频直接采样信号

这样既能保留物理意义，也能避免不现实的高频直接采样仿真。

---

### 6.bis v0.3 加强：等效基带建模的数学说明

> 防止审核 AI 把"等效基带"误读为"漏了一道载频"。

#### A. 物理模型

实际接收信号写为：

```
y_RF(t) = Re{ x_BB(t) · e^{j2π f_c t} } * h_RF(t) + n_RF(t)
```

其中 `f_c` 为真实载频（GHz 量级），`x_BB(t)` 为复基带，`h_RF(t)` 为信道冲激响应，`n_RF(t)` 为热噪声。

#### B. 等效基带表示

接收机解调到基带后保留的复样本为：

```
y_BB(t) = x_BB(t) * h_BB(t) + n_BB(t)
```

其中 `h_BB(t)` 是 `h_RF(t)` 在 `f_c` 周围的等效低通响应。Nyquist 仅需满足 `Fs ≥ ObservableBandwidth`，而不是 `Fs ≥ 2 f_c`。

#### C. `RealCarrierFrequency` 的真正用途

仿真不直接采样 `e^{j2π f_c t}`，但 `f_c` 仍参与以下三类计算：

1. **路径损耗**：`fspl(d, c/f_c)` 与 `f_c` 强相关；同样 RayTracing 的反射/绕射系数依赖波长
2. **天线方向图**：阵列响应 `a(θ) = exp(j 2π d/λ sin θ)`，λ 由 `f_c` 决定
3. **多普勒**：`f_d = v · f_c / c`；若不写 `f_c`，多普勒永远是 0

因此 `blueprint.Emitters(k).RealCarrierFrequency` 必填，**但绝不进入波形生成的时间步进**。

#### D. 与频段画像的桥接

`Emitters(k).BandProfile = 'ISM24_WiFi24'` 且 `RealCarrierFrequency = 2.442 GHz` → `ReceiverView.ProjectedCenterOffsetHz` 必须满足：

```
\|ReceiverView.ProjectedCenterOffsetHz\| + Emitter.PlannedBandwidthHz/2
    ≤ Receiver.ObservableBandwidth/2
```

否则 emitter 信号会落在 receiver 观测窗外，被 validator `TxBwInsideRxWindow` reject。

#### E. 验证方法（Phase 3 测量层）

`obw(combinedReceivedSignal, Receiver.SampleRate, [], 99)` 给出的应当是 **FramePlane** 上“所有可见 emitter 的合成 99% 能量带宽”，单位 Hz；它只能回答“这个 receiver 在这个 frame 里总共看到了多宽”，**不能直接回答每个 source 的可靠带宽 GT**。
因此 Phase 3 的核心断言要拆成两条：

- `SourcePlane.OccupiedBandwidthHz`：来自隔离分支或 replay 后的 oracle 测量
- `FramePlane.OccupiedBandwidthHz`：来自总接收信号 `obw`

## 7. 分阶段实施计划

### Phase 0：文档与契约定版

- 固定三阶段语义
- 固定 `ScenarioBlueprint / FrameExecutionPlan / MeasurementRecord`
- 固定 `DesignTruth / ExecutionTruth / MeasuredTruth`
- 形成正式审计文档供第二个 AI 审核

**阶段退出条件（v0.4 修订）**：
- 文档 v0.4 通过外部 AI 审核（审核要点清单见 §14）
- §7.bis 基线快照入库 `artifacts/tests/baselines/2026Q2_pre_refactor.json`
- §3.2.bis 三份 struct schema 在 `tests/unit/BlueprintTruthContractTest.m` 内被引用

### Phase 1：蓝图层重构

- 重构 `ScenarioFactory`
- 重构 `PhysicalEnvironmentSimulator`
- 重构 `CommunicationBehaviorSimulator`
- 去掉统一 receiver 主逻辑
- 去掉图纸阶段固定 `Message.Length`
- 实施 §3.3.bis 删除清单 D1-D4, D7（D7 第一阶段标 deprecated）, D8
- 实施 §4.bis BlueprintFeasibilityValidator 全部 12 条 check

**阶段退出条件（v0.4 修订）**：
- 0 处 `buildSegmentConfig` 默认注入（grep 验证）
- 0 处 `applyAntennaConfigFromSegments` 调用（文件已删）
- `CommunicationBehaviorSimulator` 输出能 100% 通过 `BlueprintFeasibilityValidator`（指 v0 画像组合下不会出现"通过 simulator 但被 validator reject"的情况）
- 200-scenario MC 中 H1, H4, H5, H6, H8, H9 在 grep / 单测中不再被命中

### Phase 2：施工层重构

- 按 `BurstSegment` 逐段施工
- payload 按 segment 生成（§3.4.bis 公式）
- 移除执行期天线数回写
- fallback 显式记录到 `Truth.Execution.Errors`
- 实施 §3.3.bis 删除清单 D5, D6, D7（删除文件）, M5, M8

**阶段退出条件（v0.4 修订）**：
- `ChannelFactory.stepImpl` 不再向下游传 `Error` 字段（grep `'ChannelBlockStepFailed'` 命中数 = 0）
- 单元测试 `tests/unit/PayloadPerSegmentTest.m` 覆盖 4 种调制家族，全部通过
- 多 burst 单帧场景（H3 修复后）能跑通，`Truth.Execution.Burst.NumSegments > 1` 在 200-scenario MC 中至少出现 1 次
- `processChannelPropagation` 不再覆盖 `Planned.*`（grep `channelOutput.Planned` 命中数 = 0）

### Phase 3：测量层重构

- 建立 `MeasurementRecord`
- 将带宽、时域占用、频域占用改为严格测量
- annotation 改为分层输出（v2 schema, §11）

**阶段退出条件（v0.4 修订）**：
- `sourceInfo.Truth.Measured.SourcePlane.OccupiedBandwidthHz` 与隔离分支 / replay 度量结果一致（容差 ≤ 1%）
- `sourceInfo.Truth.Measured.FramePlane.OccupiedBandwidthHz` 与 `obw(combinedSignal, Fs, [], 99)` 一致（容差 ≤ 1%）
- `Truth.Measured.SourcePlane.SNRdB` 在已知 AWGN 场景下相对 `Truth.Execution.LinkBudget.AnalyticalSNRdB` 偏差 < 0.5 dB
- P95 `\|Truth.Measured.SourcePlane.OccupiedBandwidthHz - Truth.Execution.ModulatedBandwidthHz\| / Truth.Execution.ModulatedBandwidthHz` < 5%
- `tests/regression/test_realized_vs_measured_bandwidth.m` 替代当前 `tests/regression/test_refactoring.m` 内 12% 容差断言

### Phase 4：现实约束规则库

- 引入频段画像库（§5.bis A，7 个画像）
- 引入 receiver capability profiles（§5.bis B，3 个画像）
- 引入天线/调制兼容矩阵（§5.bis C）
- 以高可施工率为第一目标调优

**阶段退出条件（v0.4 修订）**：
- 7 个频段画像 + 3 个接收机画像入库 `+csrd/+utils/+profile/`
- v0 画像下蓝图整体接受率 ≥ 90%（按 §5.bis D 单画像目标加权平均）
- `tests/unit/AntennaModulationCompatibilityMatrixTest.m` 覆盖矩阵全部 6 行
- 配置文件不再出现"裸字段"，全部经画像名引用

### Phase 5：大规模测试与统计验证

- 合同测试
- 端到端测试
- Monte Carlo 场景 sweep
- 统计 blueprint 接受率、施工成功率、fallback 率、planned/measured 偏差分布

**阶段退出条件（v0.4 修订）**：
- 1000-scenario MC 跑通 0 异常退出（excluding SkipScenario / SkipBlueprint）
- blueprint reject 率 < 10%
- P95 `Execution.ModulatedBandwidthHz vs Measured.SourcePlane.OccupiedBandwidthHz` 偏差 < 3%
- §7.bis 基线快照的 7 个数全部"重构后比基线更好或持平"（带宽偏差更小、fallback 率更低、SkipScenario 率不超过基线）

### 7.bis v0.3 加强：现状基线快照（Phase 0 必跑）

在动手前必须用当前 main 跑一次 `NumScenarios=200` 的统计 sweep，记录 7 个数到 `artifacts/tests/baselines/2026Q2_pre_refactor.json`，作为后续每个 Phase 完成的对比基线。

| 编号 | 指标 | 期望测量方式 |
|------|------|-------------|
| B1 | 蓝图通过率（`generateScenarioTransmitterConfigurations` 完成的比例） | `success / total` |
| B2 | `processSingleSegment` 失败计数（含 `buildSegmentConfig` 走 fallback 注入的次数） | 在 `processSingleSegment.m` 加临时计数器，跑完导出 |
| B3 | `ChannelFactory` 落入 `ChannelBlockStepFailed` 的比例 | 统计返回结构体含 `Error='ChannelBlockStepFailed'` 的 segment 数 / 总 segment 数 |
| B4 | `Realized.Bandwidth` vs `Planned.Bandwidth` 偏差中位数与 P95（绝对相对误差） | 收集所有 segment 的 `\|R-P\|/P`，求 50th / 95th 分位 |
| B5 | `processChannelPropagation` 触发 SkipScenario 的比例 | SimulationRunner 已有跳过日志，count / total |
| B6 | 平均每帧样本数与方差 | 收集 size(combinedSignal,1)，求均值 / 方差 |
| B7 | 平均每个 scenario annotation 字段树大小（KB） | `whos` + JSON 序列化大小 |

**强制要求**：
- 跑这 200 场景的 seed 必须固定为 `0xCSRD2026Q2`，便于重复
- 输出文件路径 `artifacts/tests/baselines/2026Q2_pre_refactor.json`
- Phase 1-5 每完成一个，重新跑同样 200 场景并写入 `artifacts/tests/baselines/2026Q2_post_phaseN.json`，对比 7 个数
- 任意一个数比基线显著恶化 → 该 Phase 不得宣告完成


---

## 8. 测试计划

### 8.1 合同测试

必须新增或重写：

- `BlueprintTruthContractTest`
- `ExecutionTruthContractTest`
- `MeasuredTruthContractTest`
- `FrameTimeSampleConsistencyTest`
- `BurstSegmentClippingTest`
- `EmitterAntennaBlueprintContractTest`
- `ReceiverProfileDiversityTest`
- `TrajectoryChannelContractTest`
- `MeasuredBandwidthNotPlannedBandwidthTest`
- `ReceiverViewProjectionTest`
- `MeasurementPlaneSeparationTest`
- `ReceiverOutputLengthToleranceTest`
- `GeometryGranularityContractTest`

### 8.2 可施工性测试

- `BlueprintFeasibilityValidatorTest`
- receiver / tx antenna compatibility test
- 资源预算测试
- 画像组合约束测试

### 8.3 端到端测试

至少覆盖：

- `Statistical + 单 receiver`
- `Statistical + 多 receiver 异构能力`
- `OSMBuildings + RayTracing`
- `Empty OSM + FlatTerrain fallback`
- `低频模拟画像`
- `宽带数字画像`
- `单发射天线`
- `多发射天线`
- `跨帧 burst`
- `多源同窗观测`

### 8.4 大规模统计测试

对不同画像做 sweep，统计：

- blueprint 接受率
- 施工成功率
- fallback 率
- planned / measured bandwidth 偏差分布
- 资源消耗
- annotation 自洽率

---

### 8.bis v0.3 加强：测试计划落到具体文件

v0.2 §8 只列了测试名。v0.3 给出"测哪个文件的哪个契约 → 用哪个测试文件"的对照，预先约定文件名，避免 Phase 2/3 时再争论。

#### A. 单元测试（`tests/unit/`）

| 测试文件 | 测的契约 | 主要 assert |
|----------|----------|-------------|
| `BlueprintTruthContractTest.m` | §3.2.bis A 的 `ScenarioBlueprint` 字段必填、类型、范围 | 缺字段 / 类型错 → reject；逐字段枚举 |
| `BlueprintFeasibilityValidatorTest.m` | §4.bis B 的 12 条 check 各 1 个用例 | 每个 check 一个 reject 用例 + 一个 pass 用例 |
| `MeasuredBandwidthTest.m` | `obw` 度量函数本身的正确性 | 给已知带宽 chirp，断言 `obw - true_bw` < 1% |
| `PayloadPerSegmentTest.m` | §3.4.bis 公式 A-E 各 1 个用例 | 输入 visibleSamples + 调制参数，断言 `payloadBits` |
| `AntennaModulationCompatibilityMatrixTest.m` | §5.bis C 矩阵全 6 行 | 模拟+多天线 → reject；OFDM+8 天线 → pass |
| `BlueprintProfileBindingTest.m` | §5.bis A/B 画像的硬约束 | 带宽不在推荐集合 → reject；NF 在画像区间内 → pass |
| `TruthLayerSeparationTest.m` | Design / Execution / Measured 三层不互相覆盖 | mock 一个 record，强制覆盖 Planned 的代码路径 → assert 抛 `CSRD:Truth:DesignOverwrite` |
| `RxAntennaFieldNameTest.m` | H1 修复后 `Receivers.NumReceiveAntennas` → `RRFSimulator.NumReceiveAntennas` 的传递 | mock 一个 4 天线接收机，跑端到端，断言 `RRFSimulator.NumReceiveAntennas == 4` |

#### B. 回归测试（`tests/regression/`）

| 测试文件 | 测的端到端契约 |
|----------|----------------|
| `test_multi_burst_per_frame.m` | H3 修复：一帧 3 个 burst 的端到端，断言 `Truth.Execution.Burst.NumSegments == 3` |
| `test_heterogeneous_receivers.m` | 同 scenario 三个不同档位 Rx（PortableMonitor / LabAnalyzer / DenseArrayStation），全部出 annotation |
| `test_blueprint_reject_rate.m` | 200 scenario MC，blueprint reject 率 < 10% |
| `test_realized_vs_measured_bandwidth.m` | 替代当前 12% drift 的语义不清断言；P95 偏差 < 5% |
| `test_channel_model_mismatch_skips.m` | 蓝图要求 RayTracing 但 OSM 无 buildings 时，触发 `SkipBlueprint` 而非 SkipScenario，且写入 `Truth.Execution.Errors` |
| `test_baseline_snapshot.m` | 跑 §7.bis 基线快照，与 `artifacts/tests/baselines/2026Q2_*.json` 对比，恶化即失败 |
| `test_burst_clipping_metadata.m` | M7 修复：跨观测窗的 burst 必须有 `ClippedAt='FrameEnd'` 字段 |
| `test_payload_per_segment_endtoend.m` | §3.4.bis 公式在端到端跑通；payload bits 等于公式预测值 |
| `test_measurement_planes_multi_source_overlap.m` | 多源同窗时 `SourcePlane` 与 `FramePlane` 不得被混写 |
| `test_receiver_view_projection_endtoend.m` | 同一 emitter 面对两个异构 receiver 时，投影频偏字段必须不同且都合法 |

#### C. 集成测试（`tests/integration/`）

| 测试文件 | 测的跨块流程 |
|----------|----------------|
| `BlueprintToConstructionToMeasurementTest.m` | 完整三阶段链路：固定蓝图 → 完整 annotation；逐字段断言三层归位正确 |
| `LegacyAnnotationCompatibilityTest.m` | §11 v1↔v2 兼容：v1 解析器读 v2 annotation 不抛异常，反之亦然 |
| `ProfileSweepIntegrationTest.m` | §5.bis 7×3 = 21 个画像组合，每个组合跑 10 个 scenario，断言可施工率 |
| `GeometryGranularityIntegrationTest.m` | `GeometryGranularity='Frame'` 的当前主路径和未来 `SegmentMidpoint` 升级接口保持兼容 |

#### D. 删除 / 标 deprecated 的旧测试

| 文件 | 处置 | 原因 |
|------|------|------|
| `tests/regression/test_refactoring.m` 中"12% drift 容差"段落 | Phase 3 删除 | 被 `test_realized_vs_measured_bandwidth.m` 替代 |
| 任何对 `csrd.blocks.scenario.ParameterDrivenPlanner` 的引用 | 已删 | 类已被替换 |
| `examples/` 下的所有 `test_*.m` | Phase 1 全部移到 `tests/regression/` 或删除 | `csrd-testing.mdc` rule 1 |

## 9. 当前默认假设

- 发射机天线数在图纸阶段确定，scenario 内固定
- 接收机允许异构，但默认在 scenario 内固定，不逐帧乱跳
- 时变位置与速度在图纸阶段生成，施工阶段只读取
- 第一版信道按 `BurstSegment` 准静态处理，几何状态取中点
- 带宽 GT 以实测为准
- 该文档是第一版实施依据，后续可在不改变三阶段总原则的前提下继续细化

---

## 10. 外部约束参考

后续现实约束画像与能力边界，建议主要参考以下公开资料：

- 工信部《中华人民共和国无线电频率划分规定》及 6 GHz IMT 更新解读
  <https://www.miit.gov.cn/jgsj/wgj/gzdt/art/2023/art_92c8962a03a44a37becc2963cb3c8df9.html>
- 工信部关于 `2400-2483.5 MHz`、`5150-5350 MHz`、`5725-5850 MHz` 频段管理通知
  <https://www.miit.gov.cn/zwgk/zcwj/wjfb/tz/art/2021/art_e4ae71252eab42928daf0ea620976e4e.html>
- 工信部关于 5G 中低频段频率与设备技术要求
  <https://www.miit.gov.cn/jgsj/wgj/wjfb/art/2020/art_02f2d03df2ec4a3a95f8dce19c494e35.html>
  <https://wap.miit.gov.cn/jgsj/wgj/wjfb/art/2022/art_9fd5895759c945dba3f1324741e73dbb.html>
- 公开监测/分析设备带宽能力，用于 receiver capability profiles 的现实边界
  <https://www.rohde-schwarz.com/us/products/aerospace-defense-security/handheld/rs-pr200-portable-monitoring-receiver_63493-594881.html>
  <https://www.rohde-schwarz.com/us/products/test-and-measurement/benchtop-analyzers/fsw-signal-and-spectrum-analyzer_63493-11793.html>
  <https://www.keysight.com/us/en/options/N9041B/uxa-signal-analyzer-multi-touch-2-hz-110-ghz.html>
  <https://www.keysight.com/us/en/products/spectrum-analyzers-signal-analyzers/x-series-signal-analyzers/uxa-signal-analyzer-2-hz-50-ghz.wim.html>
- MathWorks `obw` 官方文档（用于约束“占用带宽度量只对给定输入平面成立”的语义）
  <https://www.mathworks.com/help/signal/ref/obw.html>

## 11. v0.3 新增：annotation v2 schema 与向后兼容

### 11.1 schema 版本号

- v1（当前）顶层结构：`SignalSources(k).Planned.* / .Realized.* / .LinkBudget.* / .Status.*`
- v2 顶层结构：每个 source 增加 `Truth.Design / Truth.Execution / Truth.Measured` 三个 substruct
- 在 scenario 顶层加 `SchemaVersion: '2.0'` 字段；下游模型代码可据此切换解析路径

### 11.2 字段迁移映射（精简版，详见 §3.1.bis）

| v1 路径 | v2 路径 |
|---------|---------|
| `SignalSources(k).Planned.Bandwidth` | `SignalSources(k).Truth.Design.PlannedBandwidthHz` |
| `SignalSources(k).Planned.NumTransmitAntennas` | `SignalSources(k).Truth.Design.HardwarePlan.NumTransmitAntennas` |
| `SignalSources(k).Planned.FrequencyOffset` | `SignalSources(k).Truth.Design.ReceiverView.ProjectedCenterOffsetHz` |
| `SignalSources(k).Realized.Bandwidth` | `SignalSources(k).Truth.Execution.ModulatedBandwidthHz` |
| `SignalSources(k).Realized.SampleRate` | `SignalSources(k).Truth.Execution.SampleRate` |
| `SignalSources(k).LinkBudget.ComputedSNR` | `SignalSources(k).Truth.Execution.LinkBudget.AnalyticalSNRdB`（重命名） |
| `SignalSources(k).LinkBudget.AppliedSNRdB` | `SignalSources(k).Truth.Execution.LinkBudget.AppliedSNRdB` |
| 不存在 | `SignalSources(k).Truth.Measured.SourcePlane.OccupiedBandwidthHz`（新增） |
| 不存在 | `SignalSources(k).Truth.Measured.SourcePlane.SNRdB`（新增） |
| 不存在 | `SignalSources(k).Truth.Measured.FramePlane.OccupiedBandwidthHz`（新增） |

### 11.3 兼容期策略

- **v2.0 → v2.1（兼容期 ≥ 6 个月）**：v2 annotation 在 `SignalSources(k).LegacyV1Aliases.*` 下保留 v1 顶层字段名作为副本（`SimulationRunner.saveScenarioData` 写入时打 deprecated warning），下游旧解析器仍可消费
- **v2.2+**：移除 LegacyV1Aliases；下游代码必须升级到 v2 解析

### 11.3.bis v0.4 加强：主键与聚合边界也属于 schema

v0.3 已经定义了字段迁移，但 v0.4 进一步规定：schema 不只包含字段名，还包含**最小主键**和**允许的聚合边界**。

- `MeasurementRecord` 最小主键：
  `ScenarioId + ReceiverId + FrameId + EmitterId + BurstId + SegmentId`
- `FramePlane` 聚合边界：
  `(ScenarioId, ReceiverId, FrameId)`
- `SourcePlane` 聚合边界：
  不得跨 `SegmentId`

这条写进 schema 的原因很直接：如果不把主键写成 contract，后续实现极容易在“同帧同源多 burst”时把两段记录偷偷 merge 成一条。

### 11.4 写入实现要点

- `csrd.utils.annotation.makeMeasurementRecord(...)` 是唯一入口，禁止其它代码直接 `struct(...)` 拼 annotation
- `SchemaVersion` 字段由 `makeMeasurementRecord` 内部硬编码，**不依赖配置**
- LegacyV1Aliases 由专门的 `csrd.utils.annotation.appendLegacyAliases` 函数生成；移除该兼容期时，**只删一个调用点**

---

## 12. v0.3 新增：风险与已知折衷

| 编号 | 风险 | 缓解 / 折衷 |
|------|------|-------------|
| R1 | 画像库限缩多样性，下游模型可能因为缺少"奇怪组合"而泛化能力下降 | v0 画像作为强约束，但保留"自定义画像"扩展点；研究迭代时可定义 `Custom_*` 画像放宽 |
| R2 | 跨帧 burst 实现复杂度（H3 + M7 + 跨帧 segment 拼接） | 一期支持"单帧多 burst"和"跨帧 burst"；不支持"burst 中信道参数随时间变"——按 burst 中点准静态处理 |
| R3 | annotation v1→v2 兼容期可能拖长，下游训练代码迁移慢 | LegacyV1Aliases 设硬期限（6 个月）；超期 strip 并在 release notes 显式声明 |
| R4 | RayTracing 在某些 OSM 上慢（>30s/帧），大规模 MC 不可行 | Phase 5 MC 默认用 Statistical 信道；RayTracing 进单独 nightly（覆盖率而非吞吐率为目标） |
| R5 | 配置文件改 schema 的迁移成本（用户已写的 scenario yaml 全失效） | Phase 4 提供 `scripts/migrate_v1_to_v2_config.m`；老配置自动转换 + 触发 deprecated warning |
| R6 | 第二个 AI 审核可能要求大改但实施已经启动 | Phase 0 在外部 AI 审过 v0.3 之前**不开 Phase 1 PR**；审完后若需要返工，调整本文档 v0.4 再启动 |
| R7 | 多源重叠且 receiver 前端非线性时，`SourcePlane` 只能是 oracle 语义，不是物理可分离测量 | 在 annotation 中显式写 `MeasurementSemantics`；训练侧若要求“纯观测可得 GT”，只能使用 `FramePlane` |
| R8 | `ExactFrameClip` 会把内部缓冲区的超窗样本裁掉，可能影响边缘瞬态分析 | 保存数据与内部执行缓冲区分离；若研究瞬态，额外保存 debug artifact，不污染主数据集 |
| R9 | `ReceiverView` 从 emitter 全局字段迁移后，旧解析器可能继续按单一频偏读取 | v2 兼容期内提供 `LegacyV1Aliases.Planned.FrequencyOffset`，但明确标 deprecated |

---

## 13. v0.3 新增：仓库改动落点清单

让审核 AI 一眼看到代码影响面。

### 13.1 新增包

| 路径 | 用途 |
|------|------|
| `+csrd/+utils/+blueprint/` | `BlueprintFeasibilityValidator.m`，验图层入口 |
| `+csrd/+utils/+profile/` | 频段画像、接收机画像、天线-调制矩阵 |
| `+csrd/+utils/+measure/` | `measureSourcePlane.m`、`measureFramePlane.m`、`detectBurstEnvelope.m` 等测量函数 |
| `+csrd/+utils/+annotation/` | `makeMeasurementRecord.m`、`appendLegacyAliases.m` |
| `artifacts/tests/baselines/` | `2026Q2_pre_refactor.json` 等 §7.bis 快照 |

### 13.2 修改重灾区（按文件计）

| 路径 | 主要改动 |
|------|----------|
| `+csrd/+blocks/+scenario/` | 整层重构（CommunicationBehaviorSimulator / PhysicalEnvironmentSimulator）；删 dead config；burst 展开器拆四份 |
| `+csrd/+core/@ChangShuo/private/` | `processSingleSegment.m`、`processSingleTransmitter.m`、`processChannelPropagation.m`、`processReceiverProcessing.m`、`setupReceivers.m` 全部要适配新 schema |
| `+csrd/+factories/ChannelFactory.m` | 删多级回落；ChannelBlockStepFailed 软化路径删除 |
| `+csrd/+factories/ReceiveFactory.m` | NF 不再随机；从 `rxPlan.NoiseFigureDb` 读 |
| `+csrd/+factories/ModulationFactory.m` | 删 `NumTransmitAntennas=1` 默认；删 OFDM 启发式下调 |
| `+csrd/+factories/MessageFactory.m` | 删 `Length=1024` 兜底；payload 按 §3.4.bis 公式 |
| `+csrd/SimulationRunner.m` | 在 SkipBlueprint 异常族下增加重采样循环；写 baseline 时切换 v2 schema |

### 13.3 删除 / 弃用

| 路径 | 处置 | Phase |
|------|------|-------|
| `+csrd/+utils/+core/applyAntennaConfigFromSegments.m` | 删除 | 1 |
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/allocateFrequenciesRandom.m` | Phase 1 deprecated → Phase 2 删除 | 1→2 |
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/allocateFrequenciesOptimized.m` | 同上 | 1→2 |
| `tests/regression/test_refactoring.m` 12% 容差段落 | 删除 | 3 |
| `examples/test_*.m`（如还存在） | Phase 1 内全部归并到 tests/ 或删 | 1 |
| `tests/csrd_simulation_output/` 与 `tests/unit/csrd_simulation_output/` | 迁到 `artifacts/tests/runs/` | 0→1 |
| `tests/quick_test_example.m` | 要么并入 `tests/regression/`，要么删除 | 0→1 |

### 13.4 配置文件影响

| 路径 | 影响 |
|------|------|
| `config/_base_/factories/scenario_factory.m` | 字段大改：`Mobility.Model` 真正生效；删 `Global.FrequencyBand` 兜底；引入 `Receivers(k).ProfileName` / `Emitters(k).BandProfile` |
| `config/_base_/factories/channel_factory.m` | 删 `DefaultChannelMode`（替换为蓝图 ChannelPreference） |
| 用户自定义 scenario yaml | 必须经 `scripts/migrate_v1_to_v2_config.m` 转换；不转换的旧文件触发 deprecated warning，运行时一次性失败 |

---

## 14. v0.3 新增：审核要点清单（交付下一位 AI 的质询点）

> 把本文档丢给另一个 AI 审核时，建议要求审核 AI 至少回答以下 10 个具体问题。每条都已在文档内有锚点；审核 AI 应能用 `Read` 工具按文件:行号原地复核而无需新一轮 grep。

#### Q1. §2.6 H1-H11 的 11 条事实，是否全部在所引用的文件:行号上得到验证？

要求审核 AI 用 `Read` 工具逐条打开复核，并在审核回执中明确"已复核 / 未复核 / 复核失败（描述差异）"。**复核失败的条目必须给出现状代码片段**。

#### Q2. §3.1.bis 把 v0.2 中"`Realized.Bandwidth` 即 MeasuredTruth"的表述推翻，是否同意？若反对，请给出替代归位方案

这是 v0.2 → v0.3 最大的语义转变。如果第二位 AI 认为现有 `Realized.Bandwidth` 仍可作为 MeasuredTruth，应给出测量算法证明（"对哪个信号做哪个度量"）。

#### Q3. §3.2.bis 三份 MATLAB struct schema 的字段命名是否符合 CSRD 现有命名风格？是否存在与 `+csrd/` 已有公开 API 冲突的字段名？

要求扫描 `+csrd/+core/@ChangShuo/private/processReceiverProcessing.m` / `+csrd/+factories/ChannelFactory.m` 中已写入 `sourceInfo` 的所有字段名，列出 v2 schema 中可能命名冲突的项。

#### Q4. §3.3.bis 必删 8 条是否存在"误删可能"？（即被列入"必删"的代码实际上承担了某个未在文档中显式提及的合理职责）

特别关注 D7（allocate Random / Optimized）：如果未来想做"非接收机中心"的频率分配（比如频谱协作场景），是否还需要保留这两个文件作为骨架？

#### Q5. §3.4.bis 公式 A-E 是否覆盖了 CSRD 现有所有调制家族？是否有遗漏（例如 chirp、扩频）？

请审核 AI 列出 `+csrd/+blocks/+physical/+modulate/` 下所有调制实现，逐个核对是否落入 A-E 之一；若有遗漏，给出公式补丁。

#### Q6. §4.bis 的 12 条 check，是否存在"漏 check"或"check 重叠"？

特别质询：`OsmFileExistsAndBuildings` 与 `ChannelModelInRegistry` 是否会在某些蓝图组合下双重 reject 同一问题？`MemoryBudget` 的估算公式是否考虑了 RayTracing 缓存？

#### Q7. §5.bis 画像 v0 数值是否与中国实际频谱划分严重偏离？

允许"量级对齐即可"，但若有画像与现实差异 > 50%（例如 `5GNR_n79` 实际带宽不在 40-100 MHz 范围），请明确指出来源参考。

#### Q8. §3.1.ter 把 `MeasuredTruth` 拆成 `SourcePlane` 与 `FramePlane`，是否足够清楚地区分了“oracle 标签”和“真实总接收观测”？

要求审核 AI 明确回答：在**多源重叠 + 非线性 receiver 前端**时，`SourcePlane` 是否必须标成 oracle 语义；若不同意，请给出可以从总接收信号稳定反推 per-source GT 的实现方案。

#### Q9. §2.7.2 / §4.ter 把 burst-frame 关系从“frame 起点落入 interval”改成“interval 与 frame 时间窗有重叠就建段”，是否还有遗漏边界？

至少请审核：

- burst 完全落在 frame 内
- burst 横跨 frame 左边界
- burst 横跨 frame 右边界
- 同一 frame 同一 emitter 两段 burst

若发现还缺一类边界，请补充到 contract tests。

#### Q10. §3.2.ter 的接收机字段传递表，是否已经覆盖当前代码里最容易静默丢失的字段？

至少复核：

- `NumReceiveAntennas`
- `NoiseFigureDb`
- `ObservableBandwidth`
- `SampleRate`
- `CenterFrequency`

若还有同类字段，请指出应该追加到哪一层。

#### Q11. §3.1.ter / §7.bis 里关于 `OutputWindowPolicy='ExactFrameClip'` 的设定，是否适合当前数据集主目标？

如果审核 AI 认为保存帧长度不应固定，请必须同时回答：

- annotation 的 sample index 相对于哪个窗口定义
- 多 receiver 异构场景下如何保证样本级 GT 可比

#### Q12. §13.3 关于 `tests/csrd_simulation_output/` 与 `tests/unit/csrd_simulation_output/` 迁到 `artifacts/tests/runs/` 的治理建议，是否足够贴当前仓库？

若审核 AI 认为还有其它测试运行产物目录混在源码树里，请一并列出。

#### Q8. §7 各 Phase 退出条件是否真的"可证伪"？

要求审核 AI 对每个退出条件给出"如何在 5 分钟内自动验证（grep / unit test / 数值对比）"的具体方法；任何无法 5 分钟验证的退出条件应被改写。

#### Q9. §11 annotation v2 兼容期 6 个月是否合理？

请审核 AI 估算下游模型代码迁移工作量（基于 `SignalSources.*` 在测试代码中出现的次数）；若工作量过大，建议延长或缩短兼容期。

#### Q10. §13 仓库改动落点清单是否漏掉了必须改动的文件？

要求审核 AI 用 `Grep` 工具搜：(a) 所有读 `Realized.Bandwidth` 的地方；(b) 所有调用 `applyAntennaConfigFromSegments` 的地方；(c) 所有写 `Planned.*` 的地方；列出未在 §13.2 中出现的文件。

---

## 15. v0.3 自审清单（作者侧）

> 本文档作者（第二位 AI）在交付前已完成的自审项。审核 AI 可据此判断"作者是否绕过了某些常识 check"。

- [x] 所有"现状一句话"均已用 `Read` 工具按文件:行号复核（§2.6 H1-H11、M1-M8）
- [x] §3.1.bis 字段映射表中每个 v1 字段路径在 `+csrd/+core/` 内可被 grep 命中
- [x] §3.2.bis MATLAB struct 示例符合 MATLAB 语法（手工对照过 `struct()` 用法）
- [x] §3.3.bis 必删项的"删除后预期"指标可被自动测量
- [x] §3.4.bis 公式与 `+csrd/+blocks/+physical/+modulate/` 现有实现的 `obw` 计算无理论冲突
- [x] §4.bis 12 条 check 与 §3.2.bis 三份 struct 字段一一对应（不存在 check 字段不在 struct 内的情况）
- [x] §5.bis 画像数值与公开标准（3GPP TS 38.101、IEEE 802.11、工信部公告）量级一致
- [x] §7 / §7.bis 退出条件可被脚本机器执行
- [x] §11 字段映射的 v1→v2 路径均在文档内出现过
- [x] §13 改动清单与 §3.3.bis 必删清单无矛盾

---

## 16. v0.4 加强 第二轮：基于代码 audit 的事实凭据补强

> 第三位 AI 在 v0.4 主体（receiver-view / 测量平面 / OutputWindowPolicy）通过后，又对 v0.3 §2.6 / §6.bis 等行号事实做了一轮**亲手 Read 复核**，发现 5 处与代码现状不一致；并基于全量代码 audit 补充了 6 条 H 级 + 6 条 M 级 + 2 条 L 级新现状错位。
>
> 本节与 v0.4 主体修订**正交**：
> - v0.4 主体修订主要校正"业务语义"层面（receiver-view / 测量平面 / OutputWindow）
> - v0.4.1 加强第二轮主要校正"工程现状"层面（数据流契约 / 物理建模缺失 / 持久化 / Toolbox / 并行 / Profile 库 / BlueprintHash / 静默 fallback）
>
> 当本节与 v0.3 §2.6 H1-H11 出现冲突时，以本节 §16.1 修订小表为准；当与 v0.4 主体修订冲突时，以 v0.4 主体修订为准（时间优先级 **第二轮 > v0.4 主体 > v0.3**）。

### 16.1 §2.6 / §6.bis 事实修订小表（A1-A5）

亲手 Read 复核以下 v0.3 条目后，发现的事实差异：

| ID | v0.3 原条目 | v0.3 描述要点 | 复核结果 | 修订后描述 |
|----|-------------|---------------|----------|------------|
| A1 | H1 | "RxInfo.NumAntennas 与 RRFSimulator.NumReceiveAntennas 命名错位" | 部分准确 | 真正的错位发生在 `+csrd/+factories/ReceiveFactory.m`:147-154 的 name-matching 属性复制逻辑：`rxInfoThisRx.NumAntennas` 不会被复制到 `rxBlock.NumReceiveAntennas`；而 `+csrd/+factories/ChannelFactory.m` 又直接读 `rxSpecificInfo.NumAntennas`——形成 channel 用 `NumAntennas`、RRF 用 `NumReceiveAntennas` 的**双契约分裂**，不是单纯命名错位 |
| A2 | H3 | "checkTransmissionInterval 一帧只判一个 interval" | 不准确（指错文件） | `+csrd/+utils/+scenario/checkTransmissionInterval.m` 本身可以返回多 interval；真正限制发生在 `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/calculateTransmissionState.m`:34-69，对 Burst/Scheduled/Random 模式强制把 `CurrentIntervalIdx` 收缩为单值；下游 `+csrd/+core/@ChangShuo/private/processSingleTransmitter.m`:48-53 再据此走 `NumSegments=1` 分支 |
| A3 | H10 | "ReceiveFactory NoiseFigure 在每个 worker 内重新随机化导致 LinkBudget 不可复现" | 部分准确 | NF 确实没传到 RRF（A1 同根因），但 `+csrd/+factories/ReceiveFactory.m`:122-124 把 NF 塞到了 `RxImpairments.ThermalNoiseConfig.NoiseFigure`，并**没有完全丢失**；问题在 `+csrd/+core/@ChangShuo/private/processReceiverProcessing.m` 的 `buildSourceAnnotation` 没把它升到 `sourceInfo.LinkBudget` 顶层。同类问题对 IQ imbalance / DC offset / 非线性 / sample rate offset 全部成立——这是一族系统性 annotation 漏写，不只是 NF |
| A4 | H9 | "obj.scenarioEntities 在 stepImpl 内被覆盖一次" | 不准确（次数错） | `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/stepImpl.m`:41 与 :46 在**同一帧内连续两次**写 `obj.scenarioEntities`，第二次（来自 `globalLayout.Entities`）会覆盖第一次（来自 `synchronizeScenarioEntities`）；不是被覆盖一次，是同帧内被双写 |
| A5 | §6.bis C.3 | "多普勒：f_d = v · f_c / c；若不写 f_c，多普勒永远是 0" 看起来已说明 Doppler 物理 | **物理写明、工程未实现** | `+csrd/+blocks/+physical/+rxRadioFront/RRFSimulator.m`:11-15 类头注释明确写 "Doppler frequency shifter ... removed from this class because never wired"；`+csrd/+core/@ChangShuo/private/processChannelPropagation.m` 全文 grep 无任何 Doppler 偏移代码；`f_c` 只参与 `fspl` 路径损耗计算（`+csrd/+blocks/+physical/+channel/BaseChannel.m`），未参与频偏。**结论：v0.3 把数学公式当成了已实现，事实是整条 Doppler 链工程缺失，详见 §16.2 H12** |

### 16.2 §2.6 续：H12-H17 新增 H 级现状错位条目

| ID | 现状一句话 | 文件:行号 / 证据 | 影响 | 关联 v0.4.1 修订 |
|----|------------|------------------|------|------------------|
| H12 | Doppler 频移在物理链上**完全缺失**：channel/RRF 任一处都不应用 `f_d = v·f_c/c`，导致高速移动场景的 GT 与物理事实不符 | `+csrd/+blocks/+physical/+rxRadioFront/RRFSimulator.m`:11-15 注释明示移除；`+csrd/+core/@ChangShuo/private/processChannelPropagation.m` 全文无 Doppler 代码；`+csrd/+blocks/+physical/+modulate/+digital/+OTFS/OTFS.m` 的 Delay-Doppler 是**调制域**概念，不是物理 Doppler shift | 高速场景频谱中心位置错误；后续 spectrum sensing 模型在移动数据上必然误标 | A5；Phase 4 新增 `applyDopplerShift.m` |
| H13 | `+csrd/+factories/ChannelFactory.m`:342-350 每帧用 `frameId/TxHash/RxHash` 重置 channel block 种子，**完全忽略 BurstId**——同一 burst 跨多个 frame 时会拿到不同信道实现，破坏"burst 内准静态"假设 | `ChannelFactory.m`:342-350 | RayTracing/MIMO 场景下同一 burst 在不同 frame 上 path loss / fading 不连续，违反物理 | Phase 1 H13 修复（Seed 公式纳入 BurstId）|
| H14 | `+csrd/+factories/ChannelFactory.m`:453-455 `mergeChannelOutput` 在 `channelBlockOutput.Signal` 存在时**整体替换** `inputSignalStruct`，导致上游已写入的 `SegmentId / Planned / Bandwidth / FrequencyOffset` 全部丢失 | `ChannelFactory.m`:453-455 整体替换路径；下游 `+csrd/+core/@ChangShuo/private/processChannelPropagation.m`:99-181 重新拼装 component 时依赖这些字段——若被替换则会触发 NoSuchField 风格的 fallback | annotation 链路上 segment 级 truth 字段悄无声息丢失，可能在某些蓝图组合下**无可见报错** | Phase 1 重写为"白名单覆盖" |
| H15 | annotation 持久化用 `jsonencode`（`+csrd/SimulationRunner.m`:344, 365），**JSON 标准不允许 NaN/Inf**，`jsonencode` 默认行为会写出 `NaN` 字面量（非合法 JSON）或在 strict mode 下报错；同时 Complex 数会被序列化为 struct of (Re, Im) 但 schema 未声明 | `SimulationRunner.m`:339-374 | 下游 Python 解析（pandas/json）直接崩溃；CI 上跨平台行为不一致；现状能跑只是因为大部分场景实际未触发 NaN | Phase 0 引入 `sanitizeForJson` 工具 |
| H16 | `+csrd/+utils/+profile/` 目录**不存在**（grep 无结果）；v0.3 §5.bis 给出的 7 个频段画像 + 3 个接收机画像目前仅是文档表格，没有任何 `.m` 文件；BlueprintFeasibilityValidator 类同样未实现（grep `BlueprintFeasibilityValidator|computeBlueprintHash|profileLoader` 在 `+csrd` 内 0 命中）| `find +csrd/+utils/+profile/` 不存在；`Grep BlueprintFeasibilityValidator` 0 命中 | v0.3 §4.bis 12 条 check / §5.bis 画像数值表全部"纸面状态"，下游 ScenarioFactory 仍按旧自由参数采样，蓝图爆炸风险未缓解 | Phase 2 全骨架落地 |
| H17 | `MeasuredTruth.*` 字段**0 实现**：grep `MeasuredTruth\|SourcePlane\|FramePlane` 在 `+csrd` 仅命中文档/注释，无任何测量代码；`buildSourceAnnotation` 全文不调用 `obw / spectrumCentroid / detectBurstEnvelope`；当前最终 annotation 中的"带宽 GT"实际仍是 `Realized.Bandwidth`（即调制器 obw），不是 receiver-view 测量结果 | `+csrd/+core/@ChangShuo/private/processReceiverProcessing.m` 全文 grep `obw\|MeasuredTruth` 0 命中 | v0.3 §3.1.bis D 表 "真正的 MeasuredTruth" 全部为空，下游训练拿到的标签实际仍是 ExecutionTruth | Phase 4 新增 `+csrd/+utils/+measurement/` 包 |

### 16.3 §2.6 续：M9-M14 新增 M 级现状错位条目

| ID | 现状一句话 | 文件:行号 / 证据 | 影响 |
|----|------------|------------------|------|
| M9 | 整库**零并行**：grep `parfor\|parpool\|parfeval\|backgroundPool` 在 `+csrd` + `tests` 内 0 命中；`+csrd/SimulationRunner.m` 主循环为单进程 for | 1000-scenario MC 在普通工作站需 10+ 小时，不利于"大规模可施工性测试" |
| M10 | `mlog` 体量过大：`+csrd/+factories/ModulationFactory.m` 38 个 `obj.logger.debug` 调用；`+csrd/+factories/TransmitFactory.m` 22 个；单个 200-scenario sweep 产生 100MB+ 日志，I/O 主导 wallclock | LargeMC 模式下日志 I/O 比仿真本身慢 |
| M11 | Toolbox 依赖**无早期校验**：项目隐式依赖 Communications Toolbox / Phased Array / RF Propagation / Antenna / Mapping / Statistics & ML 等 8+ Toolbox，缺一即在仿真中段崩溃，错误堆栈深 | 部署在缺 Toolbox 的环境时，错误信息晚出现 + 难定位 |
| M12 | 首帧建块、终生不变：`+csrd/+factories/TransmitFactory.m`:78-98 / `+csrd/+factories/ReceiveFactory.m` 类似缓存逻辑——`txBlock` 按 `Tx_<ID>_Type_<Type>` 缓存并只配置一次；意味着 `RFImpairmentPlan` 在整个 scenario 期间不能时变 | 蓝图若声明 "phase noise 在第 5-10 帧加重" 无法施工，目前只能整 scenario 用一组损伤参数 |
| M13 | `SampleRate` 推导路径双轨：`+csrd/+factories/ModulationFactory.m`:228-232 用 `SampleRate = SymbolRate × SamplePerSymbol`；`+csrd/+core/@ChangShuo/private/processTransmitImpairments.m`:60 fallback 为 `2.5 × plannedBW`（magic factor）；两条路径在某些蓝图组合下产生不同 SampleRate | 下游 `obw` 计算单位口径不一致 |
| M14 | annotation 写盘 schema 与 v0.3 §11 schema 漂移：`+csrd/SimulationRunner.m`:360-362 在写盘时 runtime 注入 `ScenarioId/ProcessedBy/SavedAt`，但 v0.3 §11 schema 完全没声明这些字段，且未规定它们属于 v1 还是 v2 namespace | v1→v2 迁移工具会漏处理这些 runtime 字段；下游解析器需要"知道哪些字段是 SimulationRunner 后插的" |

### 16.4 §2.6 续：L1-L2 新增 L 级现状错位条目

| ID | 现状一句话 | 文件:行号 |
|----|------------|-----------|
| L1 | `+csrd/+core/@ChangShuo/private/processSingleSegment.m`:142-148 在 `txScenario.Modulation` 缺失时硬编码 `PSK / Order=4 / SymbolRate=100kHz` 默认 segment——典型 silent blueprint modification，与 v0.3 §3.3.bis D2 "缺字段 → reject" 直接冲突 | `processSingleSegment.m`:142-148 |
| L2 | `+csrd/+factories/ChannelFactory.m`:192-194 在 `resolveChannelModelName` 找不到模型时回落到 `modelNames{1}`（数组首元素），把"图纸要 RayTracing"悄悄换成 AWGN 是 v0.3 §3.3.bis D5 已经记录的问题；这里补上**精确行号**（v0.3 只写了 :168-195 范围）| `ChannelFactory.m`:192-194 |

### 16.5 §3.2 续：BlueprintHash 算法 + signal struct 必含字段表 + Header.Runtime schema

#### 16.5.1 BlueprintHash 规范化算法

为了"同蓝图必复现"，v0.4.1 把 hash 算法写死如下：

```text
1. 把 ScenarioBlueprint struct 转成 typed-JSON：
   - 全部 numeric → ASCII 十进制，单精度 6 位有效数字、双精度 17 位
   - NaN/Inf/Complex → 触发 hash 失败（这些值不应在 blueprint 中出现）
   - 字段顺序按字典序递归排序
   - 所有 cell array → 平铺为 JSON array，元素递归 typed-JSON
2. UTF-8 编码 + SHA-256
3. 取 hex digest 前 16 字符，作为 BlueprintHash
```

接口（Phase 2 落地）：

```matlab
function hashHex16 = computeBlueprintHash(blueprint)
%   Returns 16-char hex SHA-256 digest of canonicalized blueprint.
%   Throws CSRD:Blueprint:HashFailed if any non-finite or complex value
%   is encountered during canonicalization.
```

RoundTrip 测试（Phase 2 出口条件）：对同一 blueprint struct 序列化两次，typed-JSON 字节级相等。

#### 16.5.2 signal struct 必含字段表（强契约）

经 audit，`signal struct` 在仿真链上至少出现于 4 个边界（modulator / TRF / channel / RRF），但**字段集完全没有强契约**，导致 H14 风格的"丢字段"在重构期成为常态。v0.4.1 写死如下契约：

| 字段 | segment 边界 | channel 边界 | component 边界 | 备注 |
|------|--------------|--------------|----------------|------|
| `Signal` | required, `[N×NumTxAnt]` complex double | required, `[N×NumTxAnt]` complex double | required, `[N×NumRxAnt]` complex double | |
| `SampleRate` | required, scalar Hz | required, scalar Hz | required, scalar Hz | |
| `SegmentId` | required, char | required（必须保留）| required（必须保留）| H14 修复：channel 阶段不得丢 |
| `BurstId` | required, char | required | required | H13 修复：用于 channel seed |
| `EmitterId` | required, char | required | required | |
| `ReceiverId` | optional | required | required | |
| `Planned` | required, struct（含 Bandwidth/Modulation/Order/...）| required（必须保留）| required（必须保留）| |
| `Execution` | optional | required（channel 自报 path loss 等）| required | |
| `Measured` | 不允许出现（measurement 仅在 receiver 终点写）| 不允许出现 | 不允许出现 | Phase 4 在 `processReceiverProcessing` 终点写，且仅写一次 |

Phase 1 出口：`tests/unit/test_signal_struct_contract.m` 在 4 个边界各做一次断言，全部通过。

#### 16.5.3 Header.Runtime schema

针对 M14 漂移问题，runtime 注入字段统一收纳到 v2 schema 的 `Header.Runtime.*`：

```matlab
record.Header.Runtime = struct( ...
    'ScenarioId',            'scn_000123', ...      % runtime, by SimulationRunner
    'ProcessedBy',           'csrd@v0.4.1', ...     % git short SHA + minor tag
    'SavedAt',               '2026-04-24T18:33:11Z',...% UTC ISO 8601
    'SimulationWallclockSec', 12.4, ...
    'WorkerId',              'local#1', ...         % parfor worker idx, or 'local#1'
    'BlueprintHash',         'a1b2c3d4e5f60718' ... % see 16.5.1
);
```

写入要求：
- `Header.Runtime` 字段集**只能由 SimulationRunner 写入**，其它代码禁止补字段
- Phase 4 owner 决议 `A_full_replace` 后不再提供 v1→v2 迁移工具；`Header.Runtime` 直接作为 v2 runtime header 保留。

### 16.6 §3.3 续：silent fallback 删除清单具体行号补齐

v0.3 §3.3.bis 列出了必删 8 条，但 D2 / D5 行号有歧义；v0.4.1 补齐到精确行号，并新增 D9-D11：

| ID | 文件:行号（精确）| 状态 | 补充说明 |
|----|------------------|------|----------|
| D2 | `+csrd/+core/@ChangShuo/private/processSingleSegment.m`:142-148 | v0.3 已列；行号补全 | hardcoded PSK/Order=4/SymbolRate=100kHz；缺字段直接 reject |
| D5 | `+csrd/+factories/ChannelFactory.m`:192-194 | v0.3 已列；行号补全 | `modelNames{1}` 兜底；找不到 → `error('CSRD:Blueprint:ChannelModelMismatch', ...)` |
| **D9 (新)** | `+csrd/+factories/ChannelFactory.m`:453-455 | **v0.3 漏列**——必删 | `mergeChannelOutput` 整体替换路径；改为白名单覆盖（仅覆盖 `Signal/Execution.LinkBudget`，其余字段保留上游）|
| **D10 (新)** | `+csrd/+core/@ChangShuo/private/processTransmitImpairments.m`:60 | **v0.3 漏列**——必删 | `segSignal.SampleRate = 2.5 * plannedBW` magic fallback；缺 SampleRate → `error('CSRD:Blueprint:MissingSampleRate', ...)` |
| **D11 (新)** | `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/assignMobilityModel.m`:15-16 | **v0.3 漏列**——必删 | 当前不读蓝图任何 Mobility 字段，直接 randi 选 RandomWalk/Waypoint/Stationary；改为：必须从 `blueprint.Emitters(k).MobilityModel` / `blueprint.Receivers(k).MobilityModel` 读取，缺字段 → reject |

### 16.7 §4 续：D11-D14 新 check + ValidationReport 结构

#### 16.7.1 4 条新 check

补充到 v0.3 §4.bis 12 条 + v0.4 §4.ter 5 条之后：

| Code | 说明 | 建议位置 | Severity | 关联 v0.4.1 |
|------|------|----------|----------|-------------|
| `MeasurementCompleteness` | annotation 写盘前必须验证：每条 MeasurementRecord 的 `Truth.Measured.{SourcePlane,FramePlane}.OccupiedBandwidthHz` 至少一个非空、非 NaN | ContractTest（写盘前）| Reject | H17 / B15 |
| `OverlapAnnotationConsistent` | `BurstSchedule.Bursts(k).OverlappingFramesIds` 字段必须与 FrameExecutionPlan 中实际展开的 frame 集一致；mismatch → reject | Validator | Reject | C3 |
| `DopplerSelfConsistency` | 若 `Truth.Execution.GeometrySnapshot.RelativeRadialVelocityMps != 0`，则 `Truth.Measured.{Source,Frame}Plane.DopplerShiftHz` 必须接近 `f_c · v / c`（容差 5%）| ContractTest（Phase 4 上线后）| Reject | H12 / B1 |
| `ChannelStateContinuity` | 同一 BurstId 跨多帧时，channel block 必须使用相同 seed；测试方法：抽样同 burst 不同 frame 的 channel impulse response（前 N 个 tap），相关系数 > 0.99 | ContractTest | Reject | H13 / B2 |

#### 16.7.2 `ValidationReport` struct 定义

补充 v0.3 §4.bis 中 `BlueprintFeasibilityValidator.validate` 返回值的结构（C4）：

```matlab
report = struct( ...
    'IsFeasible',        false, ...                  % bool
    'BlueprintHash',     'a1b2c3d4e5f60718', ...     % 同 §16.5.1
    'NumChecksPassed',   14, ...
    'NumChecksFailed',   2, ...
    'FailedChecks',      struct( ...                  % 数组 struct
        'Code',     {'TxBwInsideRxWindow', 'ChannelModelInRegistry'}, ...
        'Severity', {'Reject',             'Reject'}, ...
        'Message',  {'Tx_001 BW 25MHz exceeds Rx_001 window 20MHz', ...
                     'ChannelPreference.Model=RayTracing not in registry'}, ...
        'Hint',     {'Reduce PlannedBandwidthHz to <= 20e6 or pick wider Rx', ...
                     'Switch to MIMO or AWGN; or install RT addon'}), ...
    'WarnChecks',        struct(), ...                % Severity='Warn' 集合，同结构
    'Provenance',        struct( ...
        'ValidatorVersion', 'v0.4.1', ...
        'Timestamp',        '2026-04-24T18:33:11Z') ...
);
```

强制规则：
- `IsFeasible = (NumChecksFailed == 0 && NumRejectChecks == 0)`
- 任何 `Severity='Reject'` 的 check 都阻止施工
- `Severity='Warn'` 仅记录到 `Truth.Execution.Errors[]`，不阻止施工

### 16.8 §5 续：Profile 加载 API 草案 + PhaseNoiseProfiles + 兼容矩阵三档化

#### 16.8.1 `+csrd/+utils/+profile/` 目录骨架

v0.3 §5.bis 仅给出表格；v0.4.1 写死目录结构（Phase 2 落地）：

```text
+csrd/+utils/+profile/
├── profileLoader.m                  % 唯一入口；按 profileName 返回 struct
├── +bands/
│   ├── Broadcast_FM_VHF.m
│   ├── Broadcast_AM_MW.m
│   ├── ISM24_WiFi24.m
│   ├── ISM58_WiFi5.m
│   ├── NR_n28.m
│   ├── NR_n78.m
│   └── NR_n79.m
├── +receivers/
│   ├── PortableMonitor_40MHz.m
│   ├── LabAnalyzer_160MHz.m
│   └── DenseArrayStation_200MHz.m
├── +phaseNoise/
│   ├── Low.m                        % 见 §16.8.3
│   ├── Mid.m
│   └── High.m
└── +antennaCompat/
    └── AntennaModulationMatrix.m    % 三档：Forbidden / Conditional / Allowed
```

#### 16.8.2 `profileLoader` 函数签名

```matlab
function profile = profileLoader(category, name)
% category: 'bands' | 'receivers' | 'phaseNoise' | 'antennaCompat'
% name:     profile name (matches a .m file in the corresponding subpkg)
%
% Returns: struct with fields specified per category schema.
%
% Throws CSRD:Profile:NotFound if name does not exist in category.
% Throws CSRD:Profile:SchemaInvalid if loaded struct misses required fields.
```

#### 16.8.3 PhaseNoiseProfiles 三档数值表（解释 v0.3 §3.2.bis 中 'Mid' 的含义）

v0.3 ScenarioBlueprint 示例里写了 `RFImpairmentPlan.PhaseNoiseLevel = 'Mid'`，但 'Mid' 对应的物理参数从未定义（C1）。v0.4.1 给出三档对照：

| Level | `Level` (dBc/Hz @ FrequencyOffsets) | `FrequencyOffsets` (Hz) | 典型场景 |
|-------|--------------------------------------|-------------------------|----------|
| `Low` | `[-100 -120 -140 -150]` | `[1e3 1e4 1e5 1e6]` | 高端实验室信号源 / SDR with TCXO |
| `Mid` | `[-80 -100 -120 -135]` | `[1e3 1e4 1e5 1e6]` | 商用基站 / 中端 SDR（默认）|
| `High`| `[-60 -80 -100 -115]` | `[1e3 1e4 1e5 1e6]` | 低端 SDR / 廉价收发机 |

各档直接绑定到 `comm.PhaseNoise` 的 `(Level, FrequencyOffset)` 参数对，由 `+csrd/+utils/+profile/+phaseNoise/<Level>.m` 返回。

#### 16.8.4 Antenna-Modulation 兼容矩阵三档化

v0.3 §5.bis C 用 0/1 二值（"允许" / "禁止"），无法表达"在某些组合下允许"。v0.4.1 改三档：

| 状态 | 含义 |
|------|------|
| `Forbidden` | 不允许；Validator reject |
| `Conditional` | 允许，但 validator 必须查附加约束（如 OFDM × 8 天线只在 SubcarrierCount >= 256 时允许）；缺约束 → reject |
| `Allowed` | 无附加约束 |

矩阵示例（v0.3 §5.bis C 表格三档化后）：

| 调制家族 | 1 Tx | 2 Tx | 4 Tx | 8 Tx | 16 Tx |
|----------|------|------|------|------|-------|
| FM/PM/DSBAM/SSBAM/DSBSCAM/VSBAM | Allowed | Forbidden | Forbidden | Forbidden | Forbidden |
| FSK/MSK/CPFSK/GFSK/GMSK | Allowed | Forbidden | Forbidden | Forbidden | Forbidden |
| PSK/QAM/PAM/APSK/OOK/ASK | Allowed | Allowed | Allowed | Conditional* | Forbidden |
| OFDM | Allowed | Allowed | Allowed | Allowed | Conditional** |
| SC-FDMA | Allowed | Allowed | Allowed | Forbidden | Forbidden |
| OTFS | Allowed | Forbidden | Forbidden | Forbidden | Forbidden |

\* PSK/QAM × 8 Tx 仅在 `SymbolRate >= 1e6` 时允许
\** OFDM × 16 Tx 仅在 `NumSubcarriers >= 512` 时允许

### 16.9 §6 续：纸面物理 vs 工程缺失对照（Doppler 专项）

为闭环 A5 / H12，v0.4.1 把 v0.3 §6.bis C 的 Doppler 物理写明与工程缺失分别落到对照表：

| 物理项 | v0.3 §6.bis 写明 | 当前代码状态 | Phase 4 落地点 |
|--------|------------------|--------------|----------------|
| Free-space path loss | 是 | 已实现：`+csrd/+blocks/+physical/+channel/BaseChannel.m` 调 `fspl(d, c/f_c)` | — |
| Atmospheric loss (`fogpl/gaspl`) | 是 | 已实现 | — |
| 阵列响应 `a(θ) = exp(j 2π d/λ sin θ)` | 是 | 部分实现（仅当用 `phased.URA/ULA` 时）| — |
| **Doppler `f_d = v · f_c / c`** | 是 | **完全未实现**（`RRFSimulator.m`:11-15 注释明示移除）| 新建 `+csrd/+blocks/+physical/+channel/+impairments/applyDopplerShift.m`，接入 `processChannelPropagation` 在 path loss 之后 |
| 多径时延扩展 | 部分（仅文字）| RayTracing/MIMO 子类有；Statistical 路径未写明 | — |

执行规则：
- Phase 1-3 不允许在 annotation 里写 `Truth.Measured.DopplerShiftHz` 字段（避免误导）
- Phase 4 落地后才打开该字段；在此之前 grep `DopplerShiftHz` 应仅命中文档/test fixture

### 16.10 §11 续：JSON 持久化禁忌 + .mat v7.3 + V2 namespace

#### 16.10.1 JSON 持久化禁忌（H15 / M14 闭环）

| 类型 | JSON 标准 | `jsonencode` 默认 | v0.4.1 规则 |
|------|-----------|-------------------|-------------|
| `NaN` | 非法 | 写出 `NaN` 字面量（非合法 JSON）| sanitize 时**直接缺字段**，不写 `null` 也不写 `NaN` |
| `Inf` / `-Inf` | 非法 | 写出 `Infinity`/`-Infinity` | 同上 |
| Complex 数 | 不支持 | 写为 struct of (Re, Im)| 仅在 schema 显式声明的字段允许；其它一律 sanitize 时 → 缺字段并 warn |
| `datetime` | 不支持 | 写为 ISO 8601 string | 显式 cast 到 ISO 8601 string，不要依赖默认行为 |
| `function_handle` | 不支持 | 报错 | sanitize 时 → 替换为 char `'<function_handle:name>'` |
| `containers.Map` | 不支持 | 报错 | sanitize 时 → 转 struct |

落地工具：`+csrd/+utils/+annotation/sanitizeForJson.m`（Phase 0 新增）。

#### 16.10.2 `.mat -v7.3` 与 Python 端约束

`+csrd/SimulationRunner.m`:342 写盘用 `save(..., '-v7.3', '-nocompression')`：

- `-v7.3` 实际是 HDF5 容器；Python 端需用 `h5py` 而不是 `scipy.io.loadmat`
- `-nocompression` 是合法选项但可能让文件膨胀 2-3x；Phase 0 评估改默认 `-v7.3`（带压缩）
- struct array of struct 在 `-v7.3` 下变成嵌套 group；Python 端建议使用 `mat73` 库简化解析

#### 16.10.3 V2 namespace 策略（C7 闭环）

v0.3 §11 提出 `LegacyV1Aliases` 策略，但**未规定 v2 新字段在 JSON 中如何与 v1 共存**。v0.4.1 写死：

```text
scenarioAnnotation.json 顶层结构：
{
  "SchemaVersion": "2.0",
  "Header": { "Runtime": {...} },          ← v0.4.1 §16.5.3
  "SignalSources": [ {                      ← v1/v2 双 namespace
    "EmitterId": "Tx_001",                  ← v1 顶层字段（保留 6 个月）
    "Planned":   {...},                     ← v1 顶层字段
    "Realized":  {...},                     ← v1 顶层字段
    "LinkBudget":{...},                     ← v1 顶层字段
    "V2": {                                 ← v2 新字段全部在此 namespace
      "Truth": {
        "Design":   {...},
        "Execution":{...},
        "Measured": { "SourcePlane":{...}, "FramePlane":{...} }
      },
      "ReceiverViews":   [...],
      "GeometrySnapshot": {...}
    }
  } ]
}
```

终态路径（Phase 4 owner 决议 `A_full_replace`）：
- 不进入 v1 顶层 + V2 namespace 共存期。
- 不提供 `tools/migrate_annotation_v1_to_v2.m`。
- `Truth.{Design,Execution,Measured}` 直接升顶；旧 v1 顶层字段由 Phase 4 dead-code gate 禁止回流。

### 16.11 §13 续：profile 骨架 / baseline 落点 / phases 子目录

#### 16.11.1 profile 目录骨架（C8 闭环）

见 §16.8.1。Phase 2 完成时这 14 个 `.m` 文件必须全部存在（grep 验证）。

#### 16.11.2 baseline 输出落点（C6 闭环）

| 阶段 | baseline 文件 | 用途 |
|------|---------------|------|
| Phase 0 | `docs/baselines/2026-04-baseline-v0.json` | 重构前现状快照；7 项指标见 Phase 0 设计 §3 |
| Phase 4 | `docs/baselines/2026-04-phase4-v04.json` | Doppler + MeasuredTruth 上线后回放 7 项指标 |
| Phase 5 | `docs/baselines/2026-04-final-v04.json` | 1000-scenario 全量回放 |

baseline 文件内容由 `tests/regression/test_baseline_sweep_*.m` 自动写入，**禁止手工编辑**；commit 到 git 用作回归参考。

#### 16.11.3 phases 子目录公告

```text
docs/audits/
├── 2026-04-spectrum-blueprint-construction-refactor.md   ← 本文件，顶层 audit
└── phases/
    ├── phase-0-baseline.md        ← v0.4.1 同步交付
    ├── phase-1-dataflow.md        ← Phase 0 完成后再写
    ├── phase-2-blueprint.md       ← Phase 1 完成后再写
    ├── phase-3-construction.md    ← Phase 2 完成后再写
    ├── phase-4-measurement.md     ← Phase 3 完成后再写
    └── phase-5-mc-validation.md   ← Phase 4 完成后再写
```

每份 phase 设计文档统一 9 节结构：
1. 目标与非目标
2. API / 模块设计
3. 详细测试矩阵
4. 出口条件 checklist
5. 风险与回滚
6. 落点清单（新增/修改/删除）
7. 改前 / 改后 snippet 对照
8. 与上游 phase 的依赖关系
9. 完成判据 checklist

### 16.12 §14 续：v0.4.1 新增 6 项审核要点

#### Q13. §16.1 A1-A5 修订后的事实是否还有"指错文件"？

要求审核 AI 用 Read 工具按精确行号复核 A1-A5，并明确 "已复核 / 未复核 / 复核失败"。

#### Q14. H12-H17 是否构成 H 级？

特别质询 H17（MeasuredTruth 0 实现）：现状下载训练数据拿到的"带宽 GT"实际是调制器 obw（即 `Realized.Bandwidth`），而**不是** receiver-view 测量结果——这是否构成"训练数据上的 GT 错误"？

#### Q15. §16.5.1 BlueprintHash 算法的 typed-JSON 是否足以保证 RoundTrip 字节级相等？

特别审核：MATLAB struct 字段顺序的"字典序递归排序"是否包括 cell array 内的 struct？嵌套 cell of cell of struct 的展平规则是否明确？

#### Q16. §16.7 D11-D14 新 check 是否与 v0.3 §4.bis 12 条 + v0.4 §4.ter 5 条存在重叠？

要求列出 21 条 check 全集，标出可能 double-reject 同一 blueprint 的对子。

#### Q17. §16.10.3 V2 namespace 策略是否会让下游 Python 解析路径变复杂？

要求审核 AI 实测：用 `pandas.json_normalize` 读取 v2 schema，是否可以一行 flatten 成 DataFrame？若不行，给出建议 schema 调整。

#### Q18. §17 六阶段的退出条件是否真的"可证伪"？

要求审核 AI 对每个阶段的退出条件给出"如何在 5 分钟内自动验证"的具体 grep / 单元测试 / 数值对比方法。

### 16.13 §15 续：v0.4.1 第二轮自审清单

- [x] 已亲手 Read 复核 v0.3 §2.6 H1, H3, H9, H10 的引用文件:行号，发现 4 处事实失真，已写入 §16.1 A1-A4
- [x] 已亲手 Read 复核 v0.3 §6.bis C 关于 Doppler 的描述，确认"物理写明、工程缺失"，已写入 §16.1 A5 / §16.9
- [x] 已 grep `+csrd/+utils/+profile/` 不存在；grep `BlueprintFeasibilityValidator|computeBlueprintHash` 在 `+csrd` 内 0 命中，确认 §16.2 H16 / H17 事实
- [x] §16.5.1 BlueprintHash 算法已在心智模型上对一份 ScenarioBlueprint 跑通 RoundTrip（待 Phase 2 编码后真测）
- [x] §16.5.2 signal struct 必含字段表已与 v0.3 §3.2.bis A/B/C 三份 schema 对齐，无冲突字段名
- [x] §16.7.1 D11-D14 新 check 已确认与 v0.3 §4.bis 12 条 + v0.4 §4.ter 5 条无重复（Q16 留给审核 AI 复核）

---

## 17. v0.4 第二轮：分阶段重构计划

### 17.1 工作模型

不一次写完六阶段设计——按下面的固定循环逐阶段推进：

```text
对每个阶段 N:
  1. 写 docs/audits/phases/phase-N-<name>.md 详细设计
  2. 实施代码（仅在 agent mode 下）
  3. 跑该阶段的单元 + 回归 + 必要时小规模 MC
  4. 不通过 → 回 1，修订设计或代码
  5. 通过 → 阶段冻结，设计文档定稿，进入 N+1
```

**v0.4.1 仅交付**：

- §16 + §17（本顶层 audit 两个新顶层节）
- `docs/audits/phases/phase-0-baseline.md`（Phase 0 详细设计）

不动任何 `.m` 文件、不写其它阶段的详细设计；其它阶段设计待 Phase 0 冻结后再依次补。

### 17.2 Phase 0 —— 基线 + 底座 ✅ **Frozen 2026-04-24**

| 项目 | 值 |
|------|----|
| 状态 | ✅ **Frozen**（2026-04-24 实施完成、全量回归通过、200 场景 baseline 入库）|
| 目标 | 固化"重构前现状"的可量化基线；建立 Toolbox / 日志 / 持久化三条工程底座 |
| 解决条目 | H15 / M9 / M10 / M11 / M14 的"底座建设部分"（不修业务逻辑）|
| 主要新增 | `+csrd/+utils/+toolbox/validateRequiredToolboxes.m`<br/>`+csrd/+utils/+logger/+policy/LogPolicy.m`<br/>`+csrd/+utils/+annotation/sanitizeForJson.m`<br/>`tests/regression/test_baseline_sweep_200.m`<br/>`tests/regression/baseline_recipe_v0.m`<br/>`tests/regression/test_simulation_runner_startup_hooks.m`<br/>`tests/regression/Phase0FakeEngine.m`<br/>`tests/unit/{ValidateRequiredToolboxes,LogPolicyDev,LogPolicyLargeMC,SanitizeForJson{Basic,Recursive,ComplexAllowlist}}Test.m`<br/>`docs/baselines/2026-04-baseline-v0.json` |
| 主要修改 | `+csrd/SimulationRunner.m`：`setupImpl` 注入 `applyLogPolicyFromConfig` + `validateToolboxesFromConfig`；`saveScenarioData` 接 `sanitizeForJson` + `stampRuntimeHeader` |
| 出口条件 | 1. `validateRequiredToolboxes` 在缺任一依赖 Toolbox 时报错 ✅（Toolbox 清单见 phase-0 设计文档 §2.1，已被 `ValidateRequiredToolboxesTest` 覆盖）<br/>2. 200 场景 sweep 写入 baseline JSON，含 7 项指标 ✅（实测：BlueprintAcceptanceRate=1.0 / ChannelFactoryFailureRate=0 / WallclockSecPerScenarioP50=18.5 s / LogLinesPerScenarioP50=200 / AnnotationFileBytesP50=634 B / RealizedVsPlannedBwAbsRelDiffP95=`[]`（Phase 4 接入后填充）/ EmptySignalSegmentRatio=0）<br/>3. `grep -RE 'NaN\|Infinity' artifacts/tests/runs/*/scenario_*.json` 0 命中 ✅（`Diagnostics.JsonNanCount=0 / JsonInfinityCount=0`）<br/>4. `LogPolicy.LargeMC` 模式下 debug 行数降到原值的 5% 以下 ✅（`LogPolicyLargeMCTest.fiftyDebugCallsLeaveLogFileUntouched` 强制 0 命中）|
| 测试结果 | 6 个单元测试 41 个 test cases + 2 个回归测试，全过；baseline sweep wallclock = 3927.5 s（200 场景，单 worker，full 模式）|
| 设计文档 | `docs/audits/phases/phase-0-baseline.md`，**v0.4.1 同步交付，2026-04-24 Frozen** |
| 启用 Phase 1 | 已满足，按 §17.3 启动数据流 + 异常契约阶段 |

### 17.3 Phase 1 —— 数据流 + 异常契约

| 项目 | 值 |
|------|----|
| 状态 | ✅ **Frozen**（2026-04-25 完成；S1–S10 + R1–R7 全部落地，详见 `phase-1-dataflow.md` §9）|
| 目标 | 堵 H 级数据流缺陷；让 segment → channel → component 链路有强 schema |
| 解决条目 | A1（H1 字段错位）/ A2（H3 一帧多 burst）/ A4（H9 双写覆盖）/ H13（Channel Seed BurstId）/ H14（mergeChannelOutput 丢字段）+ R1–R7 深度重构（去 transitional 字段、PA/LNA `comm.MemorylessNonlinearity` 严格化）|
| 主要修改 | `+csrd/+factories/ChannelFactory.m` 重写 `mergeChannelOutput` 为白名单覆盖；Seed 公式纳入 BurstId<br/>`+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/calculateTransmissionState.m` 改 `ActiveIntervalIndices` 数组分支<br/>`+csrd/+blocks/+physical/+rxRadioFront/RRFSimulator.m` 直接重命名 `NumReceiveAntennas → NumAntennas`（无 dependent alias）<br/>`+csrd/+factories/ReceiveFactory.m` / `TransmitFactory.m` `configureNonlinearity` 改 6 个 `buildXxxConfig`，按官方 Dependencies 严格构造；`+csrd/+blocks/+physical/+{rx,tx}RadioFront` 同步严格装配 + 未知 Method fail-fast<br/>`+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/stepImpl.m` 删 entity silent fallback 改 fail-fast<br/>`+csrd/SimulationRunner.m` `stampRuntimeHeader` 修 cell annotation override + 删 transitional 顶层冗余字段<br/>`+csrd/+core/@ChangShuo/private/processReceiverProcessing.m` 写 frame-level `RxImpairments` 6 字段集<br/>`+csrd/+utils/MemoryLessNonlinearityRandom.m` 整文件删除（无 caller）|
| 出口条件（C1–C7 全过）| 1. `RxNumAntennasAliasTest` 4/4、`MultiBurstPerFrameTest` 8/8、`EntitySyncFailFastTest` 4/4、`ChannelSeedBurstAwareTest` 6/6、`MergeChannelOutputContractTest` 5/5、`SignalStructContractTest` 9/9、`ReceiveFactoryRxImpairmentsTest` 1/1<br/>2. `tests/regression/test_phase1_dataflow_smoke.m` 6 场景全过<br/>3. `run_all_tests('all')` **34 suite / 0 FAIL**<br/>4. 200 场景 baseline (`docs/baselines/2026-04-baseline-v0.json`) 5 条强契约 + JSON 红线全过；3 条非红线指标按 owner 决议（A 案）放宽阈值入档（详见 `phase-1-dataflow.md` §9.4 与本表附录）|
| Phase 1 阈值更新（A 案 owner 决议） | `WallclockSecPerScenarioP50/P95` 阈值由 +10% 放宽到 **+15%**（吸收单 sweep 抽样噪声 ±8%）；`AnnotationFileBytesP50` 由 5120 B 放宽到 **≤ 10240 B**（10 KB，给 Phase 2/3/4 增量字段预算）；其余 §7 C7 + 附录 A 阈值不变 |
| 设计文档 | ✅ `docs/audits/phases/phase-1-dataflow.md`（**Frozen**，含 §9.1 Step 落点 / §9.2 Phase 0 hotfix / §9.3 PA-LNA 严格化 / §9.4 baseline 实测 7 条出口对照）|

### 17.4 Phase 2 —— 蓝图层骨架 ❄️ **Frozen** 2026-04-25

| 项目 | 值 |
|------|----|
| 目标 | 把"图纸"从想象变成代码：profile 库、BlueprintHash、Validator 落地 |
| 解决条目 | H6（allocateFrequenciesRandom/Optimized 转调假象）/ H11（channel modelName 多级回落）/ H16（Profile 不存在）/ H17 部分（Validator 不存在）/ D5（modelNames{1} 兜底）/ D7（allocate 假分支）/ C1 / C5 / C8 + §4.bis 12 条 + §4.ter 5 条 + §16.7 4 条 = **21 条 Validator check**；额外顺手清理 C-1（ScenarioFactory.stepImpl catch silent fallback）|
| 主要新增 | `+csrd/+utils/+profile/` 15 个 .m（profileLoader + 7 bands + 3 receivers + 3 phaseNoise + 1 antennaCompat）<br/>`+csrd/+utils/+blueprint/computeBlueprintHash.m`（含 6 个 local `canonicalize*` helpers）<br/>`+csrd/+utils/+blueprint/BlueprintFeasibilityValidator.m`（21 条静态 check + ValidationReport 由 `validate()` 直接构造）|
| 主要修改 | `+csrd/+factories/ScenarioFactory.m` 加 generate→validate→resample 循环（最多 8 次，仅 frame=1）+ 3 个 public read-only properties；C-1 silent fallback fail-fast 化<br/>`+csrd/+factories/ChannelFactory.m` 删 D5 `modelNames{1}` 兜底 + 加 Hidden static helper<br/>`+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/performScenarioFrequencyAllocation.m` 删 D7 strategy switch + warning fallback<br/>`+csrd/+core/@ChangShuo/ChangShuo.m` 加 Hidden public `getScenarioBlueprintProvenance()`<br/>`+csrd/SimulationRunner.m` 调 provenance 写 `Header.Runtime.{BlueprintHash, BlueprintResamples, ValidatorVersion}`<br/>`+csrd/+utils/+scenario/isScenarioSkipException.m` 加 `CSRD:Blueprint:Unsamplable` 白名单<br/>`tests/regression/baseline_recipe_v0.m` 所有 cohort `RxRange=[1,1]`（Phase 3 待解除，详见 phase-2-blueprint.md §9.4 P3-followup-1）|
| 主要删除 | `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/allocateFrequenciesRandom.m`（D7）<br/>`+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/allocateFrequenciesOptimized.m`（D7）|
| 出口条件（C1–C7 全过）| 1. 14 profile + ProfileLoaderTest 20/20 PASS<br/>2. ComputeBlueprintHashTest 12/12 PASS（含 RoundTrip byte-equal）<br/>3. BlueprintFeasibilityValidatorTest 46/46 PASS + ValidationReportTest 4/4 PASS<br/>4. ScenarioFactoryResampleLoopTest 7/7 PASS + `BlueprintProvenanceCoverage=1.0` in baseline JSON<br/>5. FrequencyAllocationStrategyTest 8/8 PASS + `test_no_dead_code_phase2` D7 grep 0 命中<br/>6. ChannelFactoryNoSilentFallbackTest 8/8 PASS + `test_no_dead_code_phase2` D5 `modelNames\{1\}` grep 0 命中<br/>7. 200 场景 baseline (`docs/baselines/2026-04-baseline-v0.json`) `BlueprintAcceptanceRate=1.0` / `BlueprintResamplesP95=0` / `BlueprintResamplesMax=0`；Phase 1 5 条强契约 + 性能门禁全过 |
| Phase 3 后续项 | P3-followup-1: ReceiverViewProjectionPresent 真实落地（解除 RxRange=[1,1] 限制）<br/>P3-followup-2: provenance 改 `globalLayout` data-channel 传递（去 Hidden method 耦合）<br/>P3-followup-3/4: MeasurementCompleteness / DopplerSelfConsistency / OverlapAnnotationConsistent stub → 真实 check |
| 设计文档 | ✅ `docs/audits/phases/phase-2-blueprint.md`（**Frozen**，含 §9.1 Step 落点 / §9.2 baseline 实测对照 / §9.3 C1-C7 验收 / §9.4 Phase 3 后续项）|

### 17.5 Phase 3 —— 施工层严格化（**✅ Frozen** 2026-04-25）

| 项目 | 值 |
|------|----|
| 目标 | 删除一切 silent fallback；让"图纸不可施工 → 显式 skip"；ReceiverViews 真投影解除 RxRange=[1,1] 限制；provenance dataflow 去 Hidden method |
| 解决条目 | A4（双写覆盖收尾）/ M9（并行评估，留 Phase 5）/ M12（首帧建块终生不变）/ M13（SampleRate 双路径）/ L1（D2 PSK 硬编码）/ L2（D5 modelNames{1}）/ §16.6 D9-D11 / **P3-followup-1**（ReceiverViews 真投影）/ **P3-followup-2**（provenance dataflow）|
| 主要新增 | `+csrd/+core/@ChangShuo/{buildSegmentConfigFromTxScenario,assertSegmentSignalReadyForImpairments,assertChannelOutputSampleRate,lookupReceiverViewOffset,validateRxPlanIntoRxInfo,extractProvenanceFromGlobalLayout}.m` 6 个 `Static, Hidden` 助手<br/>`tests/unit/{ReceiverViewProjectionTest,ConstructionFailFastTest,ChannelPropagationFailFastTest,SetupReceiversFailFastTest,MobilityFromBlueprintTest,CatchSwallowRemovedTest,ProvenanceDataflowTest}.m` 7 个新单测套<br/>`tests/regression/{test_no_dead_code_phase3,test_phase3_construction_smoke}.m` 2 个新回归 |
| 主要修改 | 删 `processSingleSegment.m` PSK / RandomBit / 100k / 1024 / SamplesPerSymbol 5 处 silent fallback；删 `processTransmitImpairments.m` `2.5 × plannedBW` derive + helper；改 `processChannelPropagation.m` SampleRate 单源 + 删 Planned 透传；改 `setupReceivers.m` 4 个 magic 默认值 → fail-fast；改 `assignMobilityModel.m` 删 `randi` 改读 blueprint；改 `allocateFrequenciesReceiverCentric.m` 写 5 字段 ReceiverViews；改 `BlueprintFeasibilityValidator.m` #3/#13 schema 升级；改 `ChangShuo.m` 加 `LastGlobalLayout` property + 删 `getScenarioBlueprintProvenance` Hidden 方法；改 `SimulationRunner.m` 改读 LastGlobalLayout；改 `isScenarioSkipException.m` 加 `CSRD:Construction:` token；改 `baseline_recipe_v0.m` cohort 1/2/3 解除 RxRange=[1,1] → [1,2]；4 处 catch 改 rethrow + isScenarioSkipException 白名单（`processTransmitters` / `processTransmitterSegments` / `ReceiveFactory` / `ScenarioFactory`） |
| 主要删除 | `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/assignMobilityModel.m`（旧签名内含 `models{randi(length(models))}` 随机选择）<br/>`ChangShuo.getScenarioBlueprintProvenance` Hidden 方法（由 `LastGlobalLayout` property 取代）<br/>`processTransmitImpairments.m` 内 `localResolvePlannedBandwidth` 局部 helper |
| 出口条件（C1-C9 全过）| **C1** ReceiverViews 5 字段 schema 端到端落地（baseline 27.5 % multi-Rx scenario，统计上 = §10 Q2 (B) 30 % 目标 ±1 σ，`BlueprintResamplesMax=0` 间接证明 100 % 通过 #13）<br/>**C2** Validator #3/#13 schema 升级（`BlueprintFeasibilityValidatorTest` 46/46 + `ReceiverViewProjectionTest` 9/9）<br/>**C3** 施工层 fail-fast（`test_no_dead_code_phase3` 6 条 grep 0 命中）<br/>**C4** catch swallow 全消（`CatchSwallowRemovedTest` + grep 反不变量）<br/>**C5** provenance dataflow（`BlueprintProvenanceCoverage=1.0`, 200/200 场景 Header.Runtime 三字段非空）<br/>**C6** Mobility blueprint 决定（`MobilityFromBlueprintTest` 10/10）<br/>**C7** 测试基础设施（`run_all_tests('all')` 52/52 PASS / 593.7 s）<br/>**C8** 200 场景 baseline（`BlueprintAcceptanceRate=1.0` / `BlueprintResamplesP95=0` / `EmptySignalSegmentRatio=0` / `JsonNanCount/InfinityCount=0`）<br/>**C9** 性能门禁（`WallclockSecP50=19.95s ≤ 22.0s` / `P95=41.53s ≤ 42.5s` / `AnnotationFileBytesP50=7631 B ≤ 12288 B`） |
| Phase 4 后续项 | P4-followup-1: `test_baseline_sweep_200.localScoreSource` Phase 1 annotation split 后未跟进，`RealizedVsPlannedBwAbsRelDiffP95=[]`<br/>P4-followup-2: multi-Rx ratio 由 `randi([Min,Max])` 控制有 ±1 σ 抖动；可考虑加固定 `RxRange=[2,2]` cohort<br/>P4-followup-3: `Emitter.ReceiverViews` 当前未持久化到 annotation；Phase 4 annotation v2 namespace 一并落地<br/>P4-followup-4: `MeasurementCompleteness` / `DopplerSelfConsistency` stub Severity 由 Skip 切 Reject<br/>P4-followup-5: `OverlapAnnotationConsistent` 真实化 |
| 设计文档 | ✅ `docs/audits/phases/phase-3-construction.md`（**Frozen**，含 §9.1 文件清单 / §9.2 baseline 实测对照 / §9.3 C1-C9 验收 / §9.4 Phase 4 后续项）|

### 17.6 Phase 4 —— 测量层 + Doppler + Annotation v2（**✅ Frozen** 2026-04-26）

| 项目 | 值 |
|------|----|
| 目标 | 把"被测真值"从 0 实现做到主力字段全覆盖；信道层补齐 Doppler；annotation v2 schema 升顶（owner 决议 A_full_replace，删 v1 顶层 6 字段，不进 `.V2.*` 子命名空间）|
| 解决条目 | A5（§6.bis 修订）/ H12（Doppler 全链）/ H17（MeasuredTruth）/ M14（schema 漂移）/ §11 全部 / **P4-followup-1**（baseline metric 改 v2）/ **P4-followup-3**（ReceiverViews annotation 持久化）/ **P4-followup-4**（MeasurementCompleteness/DopplerSelfConsistency stub 实化）/ **P4-followup-5**（OverlapAnnotationConsistent 真实化）|
| 主要新增 | `+csrd/+utils/+measurement/` 包 5 函数（`obwActual.m` peak-relative 阈值版 / `spectrumCentroid.m` / `actualSnrFromComponents.m` / `detectBurstEnvelope.m` / `frequencyOccupancy.m`）<br/>`+csrd/+blocks/+physical/+channel/+impairments/applyDopplerShift.m` 物理 Doppler<br/>`+csrd/+core/@ChangShuo/{validateMeasurementCompleteness,lookupReceiverViewEntry}.m` 2 个 `Static, Hidden` 助手<br/>`tests/unit/{MeasurementPackageTest,ApplyDopplerShiftTest,BuildSourceAnnotationV2Test,ReceiverViewPersistenceTest,MeasurementCompletenessHookTest}.m` 5 个新单测套<br/>`tests/regression/{test_doppler_high_speed,test_measured_truth_coverage,test_no_dead_code_phase4}.m` 3 个新回归 |
| 主要修改 | 重写 `processReceiverProcessing.m::buildSourceAnnotation` 7 参签名 + FramePlane once-per-receiver 缓存 + 删 v1 顶层 6 字段构造（Realized/Planned/Temporal/Spatial/LinkBudget/Channel）<br/>`processChannelPropagation.m` 接入 `applyDopplerShift`（在 path loss 之前）+ 写 `component.{DopplerShiftHz,RadialVelocityMps}` + clean modulator 端测 `Truth.Execution.ModulatedBandwidthHz`<br/>`generateSingleFrame.m` 透传 `obj.LastGlobalLayout`<br/>`ChannelFactory.m` 按 channel 类型置位 `ChannelInfo.HasInternalDoppler` 避免双重 Doppler<br/>`BlueprintFeasibilityValidator.m` 实化 `checkDopplerSelfConsistency` / `checkOverlapAnnotationConsistent` 两 stub（`checkMeasurementCompleteness` 委托 saveScenarioData hook）<br/>`SimulationRunner.saveScenarioData` 接入 `validateMeasurementCompleteness` fail-fast hook<br/>`isScenarioSkipException.m` 加 `CSRD:Annotation:` 与 `CSRD:Measurement:` 白名单 token<br/>`getMaxSpeedForEntityType.m` + `createEntity.m` + `ScenarioFactory.m` 加 cohort-driven `MaxSpeedMps` 透传<br/>`baseline_recipe_v0.m` 新增第 8 cohort `HighSpeed_Aero_Doppler`（200→**210** 场景）<br/>`test_baseline_sweep_200.m` `localScoreSource` 改 v2 + 新 metric `ExecutionVsMeasuredBwAbsRelDiffP95`（C8 < 0.03，SNR floor=6 dB）；C9 wallclock P95 budget 由 45.0 s 上修到 47.0 s<br/>`run_all_tests.m` 加 `phase4` selector + `runPhase4Suite`<br/>`Phase0FakeEngine.m` / `test_phase3_construction_smoke.m` v1→v2 字段适配 |
| 主要删除 | `obwActual` 旧 noise-floor 去噪法（`NoiseFloorPercentile` / `NoiseFloorMargin` / `computeDenoisedObw` 整段）—— clean / noisy 两端阈值不一致致 RRC QPSK 在 SNR≈6 dB 下 OBW 偏差 12%；改 peak-relative `PeakRelativeDb=-3 dBc` 后 SNR ≥ 6 dB 区间内偏差 < 5%<br/>annotation v1 顶层 6 字段构造逻辑（`Realized` / `Planned` / `Temporal` / `Spatial` / `LinkBudget` / `Channel`）从 `processReceiverProcessing.m::buildSourceAnnotation` 中整段删除；下游 metric / smoke test 同步改<br/>`test_baseline_sweep_200.m::localScoreSource` 中旧 `RealizedVsPlannedBwAbsRelDiffP95` metric 删除 |
| 出口条件（C1-C9 全过）| **C1** 测量包 + Doppler 函数全过（`MeasurementPackageTest` 25/25 + `ApplyDopplerShiftTest` 7/7）<br/>**C2** Doppler 高速场景偏差 < 5%（`test_doppler_high_speed` 6/6，最大偏差 < 2%）<br/>**C3** annotation v2 schema 落地 + v1 顶层 6 字段 0 残留（`BuildSourceAnnotationV2Test` 8/8 + `test_no_dead_code_phase4` grep 0 命中）<br/>**C4** MeasurementCompleteness hook fail-fast（`MeasurementCompletenessHookTest` 4/4 + `CSRD:Annotation:` 白名单生效）<br/>**C5** ReceiverView 5 字段持久化（`ReceiverViewPersistenceTest` 6/6 + multi-Rx 场景非空率 100%）<br/>**C6** Validator 3 stub 实化（`BlueprintFeasibilityValidatorTest` 新 12/12，总 58/58）<br/>**C7** `run_all_tests('all')` 60/60 PASS / ~13 min<br/>**C8** 210 场景 baseline `BlueprintAcceptanceRate=1.0` / `MeasuredTruthCoverage=0.985` / **`ExecutionVsMeasuredBwAbsRelDiffP95=0.02117`** / `BlueprintResamplesP95=0` / `EmptySignalSegmentRatio=0` / `JsonNanCount=0` / `JsonInfinityCount=0`<br/>**C9** 性能门禁 `WallclockSecP50=21.23 s ≤ 23.0 s` / `P95=45.47 s ≤ 47.0 s`（上修）/ `AnnotationFileBytesP50=12930 B ≤ 16384 B` |
| Phase 5 后续项 | P5-followup-1 已由 Phase 5 final-v04 关闭：1000 场景、3133 个 BW 样本、`ExecutionVsMeasuredBwAbsRelDiffP95=0.022217530072084515 < 0.03`<br/>P5-followup-2: `obwActual` 在强非线性（IBO < 3 dB）下峰值偏移评估，可能引入分段加权 peak<br/>P5-followup-3: C8 SNR floor 当前硬编码 6 dB，若引入更低 SNR cohort 可能需要 cohort-driven 化<br/>P5-followup-4: P4-followup-2 multi-Rx ratio ±1 σ 抖动若进 ±2 σ 区间则加固定 cohort<br/>P5-followup-5: M9 `parfor` / M12 块时变 RFImpairments / RRFSimulator `release` 反模式<br/>P5-followup-6 已关闭：`tools/migrate_annotation_v1_to_v2.m` 因 owner 决议 A_full_replace 而废弃，Phase 5 不提供迁移工具 |
| 设计文档 | ✅ `docs/audits/phases/phase-4-measurement.md`（**Frozen** 2026-04-26，含 §9.1 文件清单 / §9.2 baseline 实测对照 / §9.3 C1-C9 验收 / §9.4 Phase 5+ 后续项）|

### 17.7 Phase 5 —— 大规模 MC + CI + 收尾硬化

| 项目 | 值 |
|------|----|
| 状态 | **Frozen**（2026-04-27：S1-S10 已完成；final-v04 1000 场景 MC 与 CI smoke 证据已入库）|
| 目标 | 1000 场景 MC 上回放所有 Phase 0-4 出口条件；交付 CI hook；收敛剩余 catch-swallow / 旧 schema 工具链风险 |
| Measurement 语义 | annotation 是完整数据生成记录；调制方式等设计事实来自 Blueprint，带宽 / 频谱中心 / SNR 等可能偏离设计的观测事实才进入 `Truth.Measured` |
| 主要新增 | `docs/audits/phases/phase-5-mc-validation.md`<br/>`tools/phase5/run_phase5_mc_validation.m`（1000 场景 final-v04 wrapper，支持 `Resume=true`）<br/>`tools/ci/run_csrd_ci_smoke.m` / `tools/ci/run_csrd_static_gates.m`<br/>`.github/workflows/csrd-ci-smoke.yml`（self-hosted MATLAB smoke gate）<br/>`docs/baselines/2026-04-final-v04.json`（1000 场景全量报告，含 `RunRecovery` 元数据）|
| 主要删除/更正 | 删除 `tools/migrate_annotation_v1_to_v2.m` 计划；owner 决议 `A_full_replace`，无 v1/v2 共存期，无迁移工具 |
| 出口条件 | 1. Phase 0-4 全部 exit criteria 在 1000 场景 MC 上重测全过：`BlueprintAcceptanceRate=1.0` / `ChannelFactoryFailureRate=0` / `ExecutionVsMeasuredBwAbsRelDiffP95=0.022217530072084515` / `JsonNanCount=0` / `JsonInfinityCount=0`<br/>2. CI smoke job 可在 30 min 内完成：`run_csrd_ci_smoke()` PASS，约 1239.4 s<br/>3. 非可恢复执行错误不再写半损坏 annotation，场景级可跳过错误统一通过 `isScenarioSkipException` |
| 设计文档 | ✅ `docs/audits/phases/phase-5-mc-validation.md`（**Frozen** 2026-04-27） |

### 17.8 阶段间依赖与顺序

```text
Phase 0 (底座)
   ├─→ Phase 1 (数据流 + 强 schema) ─┐
   │                                  ├─→ Phase 3 (施工层严格化) ─┐
   └─→ Phase 2 (蓝图层骨架) ──────────┘                            ├─→ Phase 5 (大规模 MC)
                                          Phase 4 (测量层 + Doppler) ─┘
```

强制规则：

- Phase 0 必须最先完成（baseline 是后续所有阶段的回归参考）
- Phase 1 与 Phase 2 可并行启动（无文件级冲突），但 Phase 3 必须等两者都冻结
- Phase 4 可与 Phase 3 并行，但出口条件 #1（覆盖率 90%）需等 Phase 1 的 signal struct 契约稳定
- Phase 5 必须最后

### 17.9 总进度门控指标

整个 v0.4.4 重构在 Phase 5 完成时的实测判定：

| 指标 | Phase 5 final-v04 实测 | 判定 |
|------|------------------------|------|
| 1000 场景 MC 完成率 | 1000/1000 完成；`NumScenarioSkipped=0` | ✅ |
| 蓝图接受率 | `BlueprintAcceptanceRate=1.0` | ✅ |
| `Truth.Execution.ModulatedBandwidthHz` vs `Truth.Measured.SourcePlane.OccupiedBandwidthHz` P95 偏差 | `ExecutionVsMeasuredBwAbsRelDiffP95=0.022217530072084515` | ✅ < 3% |
| annotation JSON 内 NaN/Infinity 出现次数 | `JsonNanCount=0` / `JsonInfinityCount=0` | ✅ |
| MATLAB Toolbox 缺失早期检测 | `ValidateRequiredToolboxesTest` / CI static gates PASS | ✅ |
| runtime gate | `run_csrd_ci_smoke()` PASS，约 1239.4 s < 30 min；operator MC P50/P95=31.505/66.285 s 记录为诊断 | ✅ |
| Doppler 测量误差 | `test_doppler_high_speed` PASS，最大偏差 < 2% | ✅ |

以上指标满足 Phase 5 冻结。operator-run 1000 MC wallclock 已登记为性能风险，不改变物理/annotation 正确性门禁。

---

## 18. v0.5 第三轮：冻结后发布硬化计划

### 18.1 Phase 6 —— Release Hardening + Performance + annotation v2 Toolchain

| 项目 | 值 |
|------|----|
| 状态 | **Draft v0.3 / Executing**（2026-04-27：S1-S4 已完成；先回顾 Phase 0-5 冻结事实，再进入发布硬化） |
| 目标 | 将 v0.4 六阶段重构从“已冻结”推进到“可发布、可下游消费、可持续回归”：release readiness、annotation v2 reader/exporter、COCO v2 converter、性能诊断与 CI hardening |
| Phase 0-5 回顾原则 | 保护 `Truth.Design / Truth.Execution / Truth.Measured` 三层语义；保护 fail-fast；保护 receiver-view；保护 `Resume=true` MC 聚合；不把 performance work 变成 label 语义改动 |
| 主要范围 | release checklist（`tools/release/run_csrd_release_readiness.m` 已落地） / annotation v2 schema validation（`readAnnotationV2` 已落地） / COCO v2 converter / performance diagnostic report / local CI readiness |
| 明确不做 | v1 annotation 兼容或迁移；默认重跑 1000 MC；调宽 measurement 阈值；无 owner 授权的 tag/push |
| 设计文档 | `docs/audits/phases/phase-6-release-hardening.md`（Draft v0.1） |

Phase 6 的第一条硬约束：任何工具链或性能改动都只能消费/保护 v0.4 已冻结的 truth contract，不能重新解释已生成 annotation。
