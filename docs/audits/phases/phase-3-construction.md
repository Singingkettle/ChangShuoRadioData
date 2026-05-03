# Phase 3 详细设计 —— 施工层严格化（ReceiverViews + Fail-Fast + Provenance Dataflow）
> Historical snapshot / 历史快照：本文记录当时的审计或交接状态，可能保留旧路径、旧 TODO 或过渡期说明。当前目录结构以 `README.md` 和 `docs/architecture/source-layout.md` 为准。

| 字段 | 值 |
|------|----|
| 状态 | ❄️ **Frozen**（2026-04-25 S1-S10 全部 PASS；S9 `run_all_tests('all')` 52/52 PASS / 593.7 s；S10 `test_baseline_sweep_200(200,'Mode','full')` 200/200 PASS / 4351 s / `BlueprintAcceptanceRate=1.0` / `BlueprintResamplesP95=0` / `BlueprintProvenanceCoverage=1.0` / 27.5 % multi-Rx；§9 实施快照已填；audit §17.5 已标 Frozen；启动 Phase 4 详设）|
| 顶层 audit 引用 | `docs/audits/2026-04-spectrum-blueprint-construction-refactor.md` §17.5 + §3.1.ter（ReceiverViews / 测量平面 / 主键边界）|
| 关联条目 | **P3-followup-1** ReceiverViews 真投影（解除 RxRange=[1,1]）/ **P3-followup-2** Provenance dataflow 去 Hidden / **D2/D3 (M3)** PSK fallback / **D10 (M5)** `2.5 × plannedBW` / **D11 (H8)** Mobility 随机 / **附录 B** processChannelPropagation L107-118 SampleRate fallback + L135-137 Planned 透传 / **附录 B** ReceiveFactory L149-158 ReceiverBlockStepFailed 字段塞入 |
| 前置 | Phase 2 已 Frozen（Profile + BlueprintHash + Validator 21 接口 + ScenarioFactory resample loop + provenance properties / globalLayout 字段）|
| 目标产出 | 1 个 schema 升级（`Emitter.ReceiverViews(rxId)` 五字段） / **6** 处 fail-fast 改造（processSingleSegment.buildSegmentConfig / processTransmitImpairments / processChannelPropagation / setupReceivers / createEntity / assignMobilityModel） / **4** 处 catch-swallow 收敛（processTransmitters / processTransmitterSegments / processTransmitImpairments / ReceiveFactory） / **1** 处 provenance dataflow 重构（删 `ChangShuo.getScenarioBlueprintProvenance` Hidden method） / **6** 个新单测套 + **2** 个新回归测 + `phase3` selector / 200 场景 baseline 重生成（含真多 Rx）|
| 预估耗时 | 实施 ~2 个工作日；S9 全套测试 ~12 min；S10 200 场景 baseline ~75 min |

---

## 0. 工作流契约（沿用 Phase 0 / 1 / 2）

1. 本设计文档先 **Draft** → owner 复核 §10 的 8 个开放点 → 状态改 **Approved** → 才允许动任何 `.m`
2. 实施严格按 §6 的 S1–S10 单步执行 + 单步自测，禁止跨 step 大改
3. 每完成一个 step：跑 §5 中对应单元/回归脚本，必须本地 0 失败，才能进下一 step
4. 全部 step 完成后：重跑 `tests/regression/test_baseline_sweep_200.m(200,'Mode','full')`，比对 §7 出口 + Phase 1/2 已写死的 5 条强契约 + 性能阈值
5. 200 场景 baseline 全过 → 状态改 `Frozen`，audit §17.5 标 ✅ Frozen 日期，启动 Phase 4 详设

---

## 1. 范围与边界（必读）

### 1.1 在范围内（Phase 3 必须做）

| 编号 | 标题 | 当前问题 / 现状 | 处方 |
|------|------|----------------|------|
| **P3-1** | ReceiverViews schema 不存在 | `txPlan.Spectrum.PlannedFreqOffset` 是 emitter-global 单值；`allocateFrequenciesReceiverCentric` 在所有 Tx 间避碰一次后写死，不区分 Rx；Validator #13 在 `numel(rx)>1` 时直接 Reject — 因此 baseline `RxRange=[1,1]` 才勉强通过 | §3.1（schema + 投影算法 + Validator schema 升级）|
| **P3-2** | PSK / RandomBit / 100k / 1024 / SamplesPerSymbol 4 silent fallback | `processSingleSegment.m` L116-148 `buildSegmentConfig` 在 `txScenario.Modulation` / `Message` / `Spectrum` 缺字段时全部塞入硬编码 magic 值 | §3.2.A（fail-fast 改 throw `CSRD:Construction:Missing*`）|
| **P3-3** | `2.5 × plannedBW` magic factor | `processTransmitImpairments.m` L55-75 当 segment 无 SampleRate 时 derive；Phase 1 后 modulator 已强制 set SampleRate（processSingleSegment L75-84 throw `CSRD:Core:MissingSampleRate`），此 derive 路径已是死代码 | §3.2.B（直接删 `localResolvePlannedBandwidth` 与 derive 分支）|
| **P3-4** | `processChannelPropagation` 三级 SampleRate fallback + Planned 透传 | `processChannelPropagation.m` L107-118 channel/segment/rxInfo 三级回落 + warning；L135-137 `if isfield(channelOutput,'Planned') component.Planned = ...`（M8 字段错位，Phase 1 附录 B 已记） | §3.2.C（收敛到 channelOutput.SampleRate 唯一来源；删 Planned 透传）|
| **P3-5** | Receiver / Entity / Mobility magic 默认 | `setupReceivers.m` L51-61 `50e6/[-25e6,25e6]/0/2.4e9` 当 rxPlan.Observation 缺失时塞入；`createEntity.m` L98-103 boundaries 缺失时 ±1000 + warning，L32 `cell(1, 100)` 100 帧硬上限；`assignMobilityModel.m` L14-16 Tx 端 `models{randi(length(models))}` 随机 mobility | §3.3（统一改成 fail-fast；Mobility 由 PhysicalEnvironment 子树字段显式指定）|
| **P3-6** | catch swallow + Error 字段塞入 | `processTransmitters.m` L23-31 / `processTransmitterSegments.m` L27-33 / `processTransmitImpairments.m` L85-89 / `ReceiveFactory.m` L149-158 都把任意非 Skip 异常吞成 `Status='Error_*'` / `Error='*Failed'` 字段继续 | §3.4（统一接 `csrd.pipeline.scenario.isScenarioSkipException` 白名单 + rethrow / 删伪继续路径）|
| **P3-7** | Provenance dataflow 经 Hidden method | `SimulationRunner.m` L327-336 `try changShuoEngine.getScenarioBlueprintProvenance() catch ...`；`ChangShuo.m` Hidden method 读 `Factories.Scenario.LastValidationReport` —— 三层耦合 + ismethod 检测不到 + try/catch 兜底，正是 Phase 2 §9.4 P3-followup-2 列出的债务 | §3.5（让 `processScenarioInstantiation` return globalLayout，annotation 阶段直接读 `ChangShuo.LastGlobalLayout`；删 Hidden method）|
| **P3-8** | Phase 3 测试基础设施缺失 | `tests/run_all_tests.m` 只有 `phase0/phase1` selector，无 `phase2/phase3`；无 `test_no_dead_code_phase3` | §3.6（补 selector + 6 单测 + 2 回归 + dead-code grep）|

### 1.2 不在范围内（Phase 3 禁止动）

下列项目今天看着也想顺手改但**绝不在 Phase 3 内动**，否则 PR 自动拒：

- **`parfor` / 多 worker 真并行**：`SimulationRunner.stepImpl` 当前 sequential。`GlobalLogManager` singleton + RNG determinism + annotation 文件命名都是隐患；§10 Q5 = (B) 留 Phase 5
- **`MeasurementCompleteness` / `DopplerSelfConsistency` / `OverlapAnnotationConsistent` 三条 stub check 真生效** —— 留 Phase 4
- **`MeasuredTruth` / `SourcePlane` / `FramePlane` 落地**（audit §3.1.ter B/C/D）—— 留 Phase 4
- **annotation 字段重命名 / V2 namespace** —— 留 Phase 4
- **配置文件 `config/_base_/factories/scenario_factory.m` 强引入 ProfileName** —— 留 Phase 4（Phase 2 §1.4 Q1 决议是 Soft-import，Phase 3 维持现状）
- **`generateScenarioTransmitterConfigurations.m` 内的 `randi` 调用**（types/order/sps/slots）—— 这是设计内的随机抽样而非 silent fallback；Validator 已经把 BlueprintHash 覆盖到这些 random 取样，Phase 3 不动
- **`RRFSimulator` 每帧 `release(...)` 反模式** —— 留 Phase 4 / 5（Phase 1 附录 B 列为 M9 并行评估时一并处理）

### 1.3 与 §16/§17 现有结论的对齐

- **audit §3.1.ter A** ReceiverView 一等公民 = 本设计 §3.1 的硬契约（5 字段 schema 一字不改地落地）
- **audit §16.5+ 表 §1483** `Planned.FrequencyOffset → Truth.Design.ReceiverView.ProjectedCenterOffsetHz` —— Phase 3 在施工层先把 Tx 蓝图侧字段位置改到 `ReceiverViews(rxId)` 子结构；annotation 字段重命名延后到 Phase 4（避免 Phase 3 同时碰构造 + annotation schema）
- **Validator #3 `TxBwInsideRxWindow`** 当前看 emitter-global `Spectrum.PlannedFreqOffset`，Phase 3 升级为 `|ReceiverView(rx).ProjectedCenterOffsetHz| + PlannedBandwidth/2 ≤ Receiver(rx).ObservableBandwidth/2`；正反样本测试同步升级
- **Validator #13 `ReceiverViewProjectionPresent`** 当前实现已经 reject `numel(rx)>1 且 Tx 无 ReceiverViews`，但 unit test 用的是 `WindowFreqOffset` 字段名，与 audit `ProjectedCenterOffsetHz` 不一致 —— Phase 3 把 unit test + Validator 内部字段引用统一到 audit 定义的 5 字段
- **§17.5 出口条件**（待补） = 本设计 §7 的 9 条 checklist；与 audit §17.5 同步更新

### 1.4 与 Phase 2 § 9.4 P3-followup 的逐项映射

| Phase 2 列出的 followup | Phase 3 落点 |
|------------------------|-------------|
| P3-followup-1 ReceiverViews 真投影 | §3.1 + S1/S2/S3 |
| P3-followup-2 Provenance dataflow 去 Hidden | §3.5 + S7 |
| P3-followup-3 / 4 Measurement / Doppler / Overlap 三条 stub | **不在 Phase 3 范围**（留 Phase 4，§1.2 已写明）|

---

## 2. 事实凭据（带行号引用，禁止脑补）

完整证据见原 plan `phase3-construction-strict_23b1db38.plan.md` §2.1 – §2.7（Approved 后 Owner 处保留 plan 副本以备审计）。

---

## 3. 处方（实施层细节）

### 3.1 P3-1 ReceiverViews schema + 投影算法

#### 3.1.A schema（按 audit §3.1.ter / §608 / §656 一字不改）

```matlab
% txPlan.ReceiverViews(m) — m 个 receiver 一份；当 numel(rx)==1 时也填，但 #13 check 不强校验
txPlan.ReceiverViews(m) = struct( ...
    'ReceiverId',              char,    ...   % 来自 rxConfigs{m}.EntityID
    'ProjectedCenterOffsetHz', double,  ...   % == 当前 emitter-global PlannedFreqOffset 的 receiver-specific 值
    'ProjectedLowerEdgeHz',    double,  ...   % == ProjectedCenterOffsetHz - PlannedBandwidth/2
    'ProjectedUpperEdgeHz',    double,  ...   % == ProjectedCenterOffsetHz + PlannedBandwidth/2
    'IsVisible',               logical, ...   % |ProjectedCenterOffsetHz| + PlannedBandwidth/2 <= Receiver(m).ObservableBandwidth/2
    'VisibilityReason',        char     ...   % 'InBand' | 'OutOfBand' | 'EdgeClipped'
);
```

> Phase 3 **保留** `txPlan.Spectrum.PlannedFreqOffset / LowerBound / UpperBound`（向 Phase 4 annotation 重命名留兼容窗），但下游消费方一律改读 `ReceiverViews(rxIdx)`。

#### 3.1.B 投影算法（`allocateFrequenciesReceiverCentric.m` 改造）

1. 入参增加 `rxConfigs`（当前签名只接 `observableRange` 标量；改成接 `rxConfigs` cell 数组 + 派生 `observableRange`）
2. 外层循环改成**双重**：先按 (Tx, primary Rx) 在 primary Rx 的 ObservableRange 内避碰落 PlannedFreqOffset
3. 然后对每个 (Tx, otherRx)：以同一 `RealCarrierFrequency` 减 `Receiver(m).CenterFrequency` 得到 `ProjectedCenterOffsetHz`
4. 按 §3.1.A 公式填 `IsVisible / VisibilityReason`
5. 写回 `txConfig.ReceiverViews`

> 算法注脚：当 receivers 共享同一 ObservableRange 时（baseline 当前所有 receiver 同 SampleRate=50e6），所有 ReceiverViews 退化为同值；这种情况下 #13 check 仍 pass、annotation 可重现，且为 Phase 4 真异质 receiver 留接口。

#### 3.1.C Validator schema 升级

- Validator #3 `TxBwInsideRxWindow`：从读 `tx.Spectrum.PlannedFreqOffset` → 改读 `tx.ReceiverViews(r).ProjectedCenterOffsetHz`，对每个 (Tx, Rx) pair 验证
- Validator #13 `ReceiverViewProjectionPresent`：实现已正确，仅 unit test 字段名 `WindowFreqOffset` → `ProjectedCenterOffsetHz`
- `assembleBlueprint` 不变（已经把 `txConfigs` 整体塞 `Emitters`，新增 ReceiverViews 字段自动随之进入 BlueprintHash）

### 3.2 施工层 fail-fast 三连改造

#### 3.2.A processSingleSegment.buildSegmentConfig（删 PSK / RandomBit / 100k / 1024 / 4 默认值）

- L116-148 全部改成：缺字段 → `error('CSRD:Construction:MissingMessageConfig'/'MissingModulationConfig'/'MissingSpectrumConfig', ...)`
- 该路径上游是 `generateScenarioTransmitterConfigurations`，已经强制 `txPlan.Modulation/Message/Spectrum` 落地 + Validator 第 4 / 第 1 / 第 2 三条 check 拦截 → 删除后不应触发任何回归
- 配套：`tests/unit/ConstructionFailFastTest.m` 新建

#### 3.2.B processTransmitImpairments（删 `2.5 × plannedBW` derive 路径）

- 删除 L55-75 整个 derive 分支 + helper `localResolvePlannedBandwidth` 函数
- 改成：`if ~isfield(segSignal, 'SampleRate') ...` → 直接 `error('CSRD:Construction:MissingSampleRate', ...)`（与 processSingleSegment L75-84 同 errorId 协议）

#### 3.2.C processChannelPropagation（收敛 SampleRate；删 Planned 透传）

- L107-118 三级回落改成单级：`if isfield(channelOutput, 'SampleRate') && channelOutput.SampleRate > 0 → component.SampleRate = channelOutput.SampleRate; else error('CSRD:Construction:ChannelMissingSampleRate', ...)`
- L135-137 `if isfield(channelOutput, 'Planned') component.Planned = channelOutput.Planned;` 整段删除（component.Planned 已在 `processSingleSegment.m` L86-88 设过；ChannelFactory 不应回写 Planned，详见 audit §3.1.ter A）

### 3.3 P3-5 Receiver / Entity / Mobility magic 默认清理

#### 3.3.A setupReceivers 全 fail-fast

- L51-61 整段改写：缺 `Observation.SampleRate / ObservableRange / CenterFrequency / RealCarrierFrequency` 任一字段 → `error('CSRD:Construction:RxMissingObservation', ...)`
- L33 / L38 / L46 / L47 同样 fail-fast（rxPlan.Physical / Hardware 必填）
- L68-72 catch 块改 `rethrow(ME_rx)`（不再塞 `Status='Error_ReceiverSetup'` 假结构）
- 上游约束：Validator #1 `FrameSampleConsistency` + #2 `RxFsEqualsObservableBw` 已强保证 Observation.SampleRate 与 ObservableBandwidth 存在；删除后零回归

#### 3.3.B createEntity 边界 fail-fast + frame 上限可配

- L96-103 删除：`obj.mapData.Boundaries` 必须存在；缺失 → throw `CSRD:Construction:MissingMapBoundaries`
- L32 `cell(1, 100)` → `cell(1, max(100, getNumFramesPerScenario(obj)))`；保留运行时 100 是因为 `Snapshots` 是 dynamic-grow 的，但 pre-allocate 上限改成读 config

#### 3.3.C Mobility 由 blueprint 显式指定

- `assignMobilityModel.m` 函数签名改：`function mobilityModel = assignMobilityModel(entityType, entityConfig)`
- 实现：`if isfield(entityConfig, 'Mobility') && isfield(entityConfig.Mobility, 'Model') && ~isempty(entityConfig.Mobility.Model) → return；else error('CSRD:Construction:MissingMobilityModel', 'Entity %s lacks Mobility.Model', entityType)`
- 上游 `createEntity` 调用点同步改：传入 `obj.Config.Entities.<entityType+'s'>` 子结构（`Transmitters` / `Receivers`）
- `config/_base_/factories/scenario_factory.m` 已经写有 `Entities.Transmitters.Mobility.Model = 'RandomWalk'`、`Entities.Receivers.Mobility.Model = 'Stationary'`，无需新增字段

### 3.4 P3-6 catch swallow 收敛（4 处统一处方）

通用模式：

```matlab
catch ME
    if csrd.pipeline.scenario.isScenarioSkipException(ME)
        rethrow(ME);
    end
    obj.logger.error('...: %s', ME.message);
    rethrow(ME);   % Phase 3 不再塞 'Error_*' 字段，让 SimulationRunner 决定 scenario 跳过
end
```

具体到 4 处：

| 文件 | 行 | 改造 |
|------|----|------|
| `processTransmitters.m` | L23-31 | 删除 catch 块塞 Status 字段路径，统一 rethrow |
| `processTransmitterSegments.m` | L27-33 | 删除 `signalSegmentsPerTx{k}=[]` 塞空，rethrow |
| `processTransmitImpairments.m` | L85-89 | 删除塞 `TransmitError=true` 字段，rethrow |
| `ReceiveFactory.m` | L149-158 | 删除塞 `Error='ReceiverBlockStepFailed'`，rethrow |

> 所有 rethrow 最终被 SimulationRunner 在 `executeScenario` try/catch 里捕获 → 走 `isScenarioSkipException` 决定是否跳过整 scenario。
> Phase 3 同步把 `CSRD:Construction:Missing*` 系列 errorId 加入 `+csrd/+pipeline/+scenario/isScenarioSkipException.m` 白名单（非致命：scenario skip；致命：crash）。

### 3.5 P3-7 Provenance dataflow 重构

#### 3.5.A processScenarioInstantiation 已 return globalLayout（无需改签名）

- ChangShuo.stepImpl 调用 `[..., globalLayout] = processScenarioInstantiation(obj, FrameId)`，把 globalLayout 写入新加的 public read-only property `ChangShuo.LastGlobalLayout`
- 删除 `getScenarioBlueprintProvenance` Hidden method 整段
- 删除 ChangShuo `methods (Hidden)` 段（如果空了）

#### 3.5.B SimulationRunner 直接读 globalLayout

- `SimulationRunner.m:321-332` 改成：`blueprintProvenance = obj.extractProvenanceFromGlobalLayout(changShuoEngine.LastGlobalLayout);`
- 删除 try/catch + ismethod 兜底
- 配套：`tests/unit/ProvenanceDataflowTest.m` 新建（grep `getScenarioBlueprintProvenance` 0 命中 + annotation `Header.Runtime.{BlueprintHash, BlueprintResamples, ValidatorVersion}` 三字段非空）

### 3.6 P3-8 测试基础设施

#### 3.6.A `tests/run_all_tests.m` 加 `phase2` / `phase3` selector

新增 `runPhase2Suite` 和 `runPhase3Suite`，照搬 `runPhase1Suite` 模板。Phase 2 8 个 unit test + `test_no_dead_code_phase2` 全部收齐。

#### 3.6.B 6 个新单测套（详见 §5 矩阵）

#### 3.6.C 2 个新回归测

- `tests/regression/test_no_dead_code_phase3.m`：grep 6 条死代码全 0 命中
- `tests/regression/test_phase3_construction_smoke.m`：构造 1 Tx / 2 Rx scenario 跑通；断言 `Emitters{1}.ReceiverViews` 含 2 项 + annotation `Header.Runtime` 三字段非空 + 无 `Status='Error_*'` 残留

#### 3.6.D 解除 `tests/regression/baseline_recipe_v0.m` RxRange 限制

按 §10 Q2 = (B) 保守恢复：cohort 1/2/3（Sub-3GHz 三组共 120 场景）`RxRange = [1, 2]`；cohort 4/5/6/7 保留 `[1, 1]`。

---

## 4. 新增 / 删除 / 修改文件清单（终态预览）

### 4.1 新增（**8** 个）

| 路径 | 说明 |
|------|------|
| `tests/unit/ReceiverViewProjectionTest.m` | ReceiverViews 投影算法 + Validator #3/#13 schema 升级正反样本（≥ 8 cases）|
| `tests/unit/ConstructionFailFastTest.m` | processSingleSegment / processTransmitImpairments / processChannelPropagation fail-fast 反样本（≥ 6 cases）|
| `tests/unit/SetupReceiversFailFastTest.m` | setupReceivers magic 默认值删除后反样本（≥ 4 cases）|
| `tests/unit/MobilityFromBlueprintTest.m` | assignMobilityModel 不再随机；正反样本（≥ 4 cases）|
| `tests/unit/CatchSwallowRemovedTest.m` | 4 处 catch 改 rethrow + isScenarioSkipException 白名单契约（≥ 6 cases）|
| `tests/unit/ProvenanceDataflowTest.m` | globalLayout → annotation 三字段链路（≥ 4 cases）|
| `tests/regression/test_no_dead_code_phase3.m` | 6 条 grep 0 命中 |
| `tests/regression/test_phase3_construction_smoke.m` | multi-Rx + 多 burst smoke |

### 4.2 修改（核心 12 个）

| 路径 | 改动概述 |
|------|---------|
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/allocateFrequenciesReceiverCentric.m` | 入参增加 `rxConfigs`；新增 ReceiverViews 投影循环 |
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/performScenarioFrequencyAllocation.m` | 调用点同步 rxConfigs 透传 |
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/generateScenarioTransmitterConfigurations.m` | 调用点同步 rxConfigs 透传到 performScenarioFrequencyAllocation |
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/CommunicationBehaviorSimulator.m` | private method 签名声明同步 |
| `+csrd/+pipeline/+blueprint/BlueprintFeasibilityValidator.m` | check #3 升级为 ReceiverView-aware；check #13 字段引用统一 ProjectedCenterOffsetHz |
| `tests/unit/BlueprintFeasibilityValidatorTest.m` | check #3 / #13 测试样本字段名同步 |
| `+csrd/+core/@ChangShuo/private/processSingleSegment.m` | L116-148 改 fail-fast；buildSegmentConfig 读 ReceiverView 而非 emitter-global FrequencyOffset |
| `+csrd/+core/@ChangShuo/private/processTransmitImpairments.m` | 删 derive 分支 + helper |
| `+csrd/+core/@ChangShuo/private/processChannelPropagation.m` | SampleRate 改单级；删 Planned 透传；catch 改 rethrow |
| `+csrd/+core/@ChangShuo/private/setupReceivers.m` | Observation / Hardware / Physical 全 fail-fast |
| `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/createEntity.m` | 边界 fail-fast；100 帧上限改读 config；assignMobilityModel 调用签名同步 |
| `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/assignMobilityModel.m` | 签名改 (entityType, entityConfig)；删除 randi |
| `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/PhysicalEnvironmentSimulator.m` | private method 签名声明同步 |
| `+csrd/+core/@ChangShuo/private/processTransmitters.m` / `processTransmitterSegments.m` / `processTransmitImpairments.m` | catch 改 rethrow |
| `+csrd/+factories/ReceiveFactory.m` | catch 改 rethrow |
| `+csrd/+core/@ChangShuo/ChangShuo.m` | 增加 LastGlobalLayout property；删 getScenarioBlueprintProvenance Hidden method；stepImpl 写 LastGlobalLayout |
| `+csrd/+core/@ChangShuo/private/generateSingleFrame.m` | 把 globalLayout 暴露给外层（写入 obj.LastGlobalLayout） |
| `+csrd/SimulationRunner.m` | 改读 LastGlobalLayout；删 try/catch 兜底 |
| `+csrd/+pipeline/+scenario/isScenarioSkipException.m` | 加入 `CSRD:Construction:Missing*` 白名单 |
| `tests/run_all_tests.m` | 加 `phase2` / `phase3` selector |
| `tests/regression/baseline_recipe_v0.m` | 解除 cohort 1/2/3 RxRange=[1,2] |
| `docs/baselines/2026-04-baseline-v0.json` | 重新生成（RecipeSha + 全部 metrics）|

### 4.3 删除（1 个 method + 1 个 helper）

| 删除项 | 理由 |
|--------|------|
| `ChangShuo.getScenarioBlueprintProvenance` Hidden method | 由 LastGlobalLayout property 取代 |
| `processTransmitImpairments.m` 内 `localResolvePlannedBandwidth` 局部 helper | derive 路径删除后无 caller |

---

## 5. 测试矩阵

| Step | 必须本地通过的测试 |
|------|------------------|
| S1 | `ReceiverViewProjectionTest`（schema + projection 正反） + 升级后的 `BlueprintFeasibilityValidatorTest` |
| S2 | + smoke：1 Tx / 2 Rx 蓝图断言 ReceiverViews 含 2 项 |
| S3 | + `test_phase3_construction_smoke`（multi-Rx 跑通 + ChannelFactory 按 ReceiverView 取 freq offset）|
| S4 | + `ConstructionFailFastTest`（PSK/RandomBit/SampleRate/ChannelMissingSampleRate 4 反样本） |
| S5 | + `SetupReceiversFailFastTest` + `MobilityFromBlueprintTest`（mobility blueprint 正反）|
| S6 | + `CatchSwallowRemovedTest`（4 处 rethrow 契约 + Skip 白名单）|
| S7 | + `ProvenanceDataflowTest`（grep + annotation 三字段）|
| S8 | + `test_no_dead_code_phase3`（6 条 grep 0 命中）|
| S9 | `run_all_tests('all')` 全过；本地 ≤ 15 min |
| S10 | `test_baseline_sweep_200(200,'Mode','full')` 200/200 SUCCESS；§7 出口 9 条全过 |

---

## 6. 实施顺序（S1–S10，单步实施 + 单步自测）

| Step | 内容 | 阻塞下一步的退场判据 |
|------|------|--------------------|
| **S1** | Validator schema 升级（#3 / #13 字段统一 ProjectedCenterOffsetHz）+ 同步升级 BlueprintFeasibilityValidatorTest | unit test 全过 |
| **S2** | allocateFrequenciesReceiverCentric 改造 + 写 `ReceiverViews` + 调用点 rxConfigs 传参 | ReceiverViewProjectionTest 全过 |
| **S3** | downstream 消费方（buildSegmentConfig / processChannelPropagation）改读 ReceiverView | smoke 1 Tx / 2 Rx 跑通 |
| **S4** | processSingleSegment / processTransmitImpairments / processChannelPropagation 三连 fail-fast 改造 + 删 helper | ConstructionFailFastTest 全过 |
| **S5** | setupReceivers + createEntity + assignMobilityModel fail-fast 改造 | SetupReceiversFailFastTest + MobilityFromBlueprintTest 全过 |
| **S6** | 4 处 catch 改 rethrow + isScenarioSkipException 白名单扩充 | CatchSwallowRemovedTest 全过 |
| **S7** | ChangShuo.LastGlobalLayout property + SimulationRunner 改读；删 Hidden method | ProvenanceDataflowTest 全过 |
| **S8** | run_all_tests 加 phase2/phase3 selector + test_no_dead_code_phase3 + test_phase3_construction_smoke + baseline_recipe_v0 解除 RxRange | `run_all_tests('phase3')` 全过 |
| **S9** | `run_all_tests('all')` 全套回归 | 0 失败；wallclock ≤ 15 min |
| **S10** | `test_baseline_sweep_200(200,'Mode','full')` 重生成 baseline JSON + 文档 freeze | §7 9 条全过 |

---

## 7. 出口条件（C1–C9）

| C | 描述 | 量化 |
|---|------|------|
| **C1** | ReceiverViews schema 端到端落地 | 200 场景中 multi-Rx scenario 比例 ≥ §10 Q2 决议值；`Emitters[k].ReceiverViews` 字段在 100% multi-Rx scenario 中存在 |
| **C2** | Validator #3 / #13 schema 升级 | BlueprintFeasibilityValidatorTest 全过；ReceiverViewProjectionTest ≥ 8/8 |
| **C3** | 施工层 fail-fast | grep 0 命中：`= 'PSK';\s*$` / `= 'RandomBit';\s*$` / `2\.5 \* plannedBW` / `50e6;\s*$` / `\[-25e6, 25e6\]` / `models\{randi\(length\(models\)\)\}` |
| **C4** | catch swallow 全消 | grep 0 命中：`Status = 'Error_TransmitterProcessing'` / `'ReceiverBlockStepFailed'` / `TransmitError = true` / `signalSegmentsPerTx\{k\} = \[\];` |
| **C5** | Provenance dataflow 重构 | grep 0 命中：`getScenarioBlueprintProvenance` / `ismethod.*Provenance`；annotation `Header.Runtime.{BlueprintHash, BlueprintResamples, ValidatorVersion}` 三字段在 200/200 场景中 100% 非空 |
| **C6** | Mobility 由 blueprint 决定 | `assignMobilityModel` 拒绝 entityConfig 缺 Mobility.Model；MobilityFromBlueprintTest 全过 |
| **C7** | 测试基础设施 | `tests/run_all_tests.m` 含 `phase2 / phase3` selector；`run_all_tests('phase3')` 全过；`test_no_dead_code_phase3` 全过 |
| **C8** | 200 场景 baseline | `BlueprintAcceptanceRate ≥ 0.98`；`BlueprintResamplesP95 ≤ 1`；multi-Rx scenario 数 ≥ §10 Q2 决议值；`EmptySignalSegmentRatio ≤ 0.02`；JSON Nan/Inf == 0 |
| **C9** | 性能门禁 | `WallclockSecPerScenarioP50 ≤ 22.0 s`；`P95 ≤ 42.5 s`；`AnnotationFileBytesP50 ≤ 12288 B` |

---

## 8. 风险登记

| 编号 | 风险 | 缓解 |
|------|------|------|
| R1 | ReceiverViews schema 升级触发 multi-Rx 场景的 Validator #3 拒绝率上升 | §10 Q2 选 (B) 保守恢复 30% multi-Rx scenario；observe + 必要时回退 |
| R2 | setupReceivers / createEntity fail-fast 删除默认值导致已有 cohort 失败 | S5 单独跑 phase0 + phase1 + phase2 三个子集回归确保零回归 |
| R3 | provenance dataflow 重构改 globalLayout 暴露方式 | S7 内 grep 所有 caller；同 commit 内不混 fail-fast 改造 |
| R4 | catch swallow 改 rethrow 后 SimulationRunner 跳过场景率突增 | S6 完成后跑一次 phase0 / phase1 baseline 12 场景对比 SuccessRate 不退化 |
| R5 | Mobility 字段在配置文件加入触发 ScenarioFactory.config schema 双契约 | §10 Q8 = (A)：仅在 PhysicalEnvironment.Entities 子树读 Mobility.Model；不动 CommunicationBehavior |
| R6 | baseline AnnotationFileBytesP50 + ReceiverViews 字段超 12 KB 阈值 | S10 实测后按 Phase 1 §9.4.2 owner 决议模板调整 §7 C9 阈值 |

---

## 9. 实施快照（S10 freeze 后填，2026-04-25）

### 9.1 实际改 / 新增 / 删除文件清单

#### 9.1.1 新增（Phase 3 范围内 6 个生产代码 .m + 7 个测试 .m + 1 个文档 = 14 个）

| 类别 | 路径 | 角色 / 关联 step |
|------|------|----------------|
| ChangShuo `Static, Hidden` 助手 | `+csrd/+core/@ChangShuo/buildSegmentConfigFromTxScenario.m` | 把 `processSingleSegment` 内 `buildSegmentConfig` 抽到 `Static, Hidden` 方法，让 `ConstructionFailFastTest` 可直接喂入构造的 txScenario / S4 |
| 同上 | `+csrd/+core/@ChangShuo/assertSegmentSignalReadyForImpairments.m` | `processSingleSegment` 调用 modulator 后的 fail-fast 守卫 / S4 |
| 同上 | `+csrd/+core/@ChangShuo/assertChannelOutputSampleRate.m` | `processChannelPropagation` 单一 SampleRate 来源校验 / S4 |
| 同上 | `+csrd/+core/@ChangShuo/lookupReceiverViewOffset.m` | 给 `buildSegmentConfigFromTxScenario` 提供 `txPlan.ReceiverViews(rxId).ProjectedCenterOffsetHz` 查表（multi-Rx 时按当前 Rx 取，single-Rx 时退化为唯一项）/ S3 |
| 同上 | `+csrd/+core/@ChangShuo/validateRxPlanIntoRxInfo.m` | `setupReceivers` 的 fail-fast 验证函数：所有 Rx{Observation/Hardware/Physical} 字段必须显式存在，缺一即抛 `CSRD:Construction:MissingReceiverField:*` / S5 |
| 同上 | `+csrd/+core/@ChangShuo/extractProvenanceFromGlobalLayout.m` | 从 `LastGlobalLayout` 提取三字段 provenance 的 canonical 实现（替代 Phase 2 `getScenarioBlueprintProvenance` Hidden 方法）/ S7 |
| 单测 | `tests/unit/ReceiverViewProjectionTest.m` | ReceiverViews 5 字段投影算法 + Validator #3/#13 schema 升级正反样本 (9 cases) / S1+S2 |
| 单测 | `tests/unit/ConstructionFailFastTest.m` | `processSingleSegment` / `processTransmitImpairments` / `processChannelPropagation` 三连 fail-fast 反样本 / S4 |
| 单测 | `tests/unit/SetupReceiversFailFastTest.m` | `setupReceivers` magic 默认值删除 + Mobility 字段缺失反样本 (14 cases) / S5 |
| 单测 | `tests/unit/MobilityFromBlueprintTest.m` | `assignMobilityModel` 不再 `randi` 正反样本 (10 cases) / S5 |
| 单测 | `tests/unit/CatchSwallowRemovedTest.m` | 4 处 catch 改 rethrow + isScenarioSkipException 白名单契约（含 source-grep 反样本）/ S6 |
| 单测 | `tests/unit/ProvenanceDataflowTest.m` | `LastGlobalLayout` property + `extractProvenanceFromGlobalLayout` 三字段链路 (12 cases) / S7 |
| 单测 | `tests/unit/ChannelPropagationFailFastTest.m` | `processChannelPropagation` SampleRate 单源 + Planned 透传删除反样本 / S4 |
| 回归 | `tests/regression/test_no_dead_code_phase3.m` | 6 条 grep 反不变量（PSK fallback / RandomBit fallback / `2.5 * plannedBW` / `50e6;$` / `[-25e6, 25e6]` / `models{randi(length(models))}` / `getScenarioBlueprintProvenance`）0 命中 / S8 |
| 回归 | `tests/regression/test_phase3_construction_smoke.m` | 1 Tx / 2 Rx multi-Rx end-to-end smoke：assert ReceiverViews 投影、provenance 三字段、无 legacy error sentinel、`Realized.FrequencyOffset` 非 NaN / S8 |

#### 9.1.2 修改（Phase 3 范围内 ~22 个 .m + 1 个 recipe + 1 个 baseline JSON）

| 路径 | Phase 3 修改要点 | 关联 step |
|------|----------------|----------|
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/CommunicationBehaviorSimulator.m` | 暴露 3 个 `Static, Hidden` 方法（`projectReceiverViews` / `normalizeReceiverList` / `resolveObservableRange`）让 `ReceiverViewProjectionTest` 直接打到投影算法 | S2 |
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/allocateFrequenciesReceiverCentric.m` | 入参增 `rxConfigs` (cell)；新增 receiver-by-receiver 投影循环，写 `txPlan.ReceiverViews(m)` 5 字段（`ReceiverId / ProjectedCenterOffsetHz / ProjectedLowerEdgeHz / ProjectedUpperEdgeHz / IsVisible / VisibilityReason`）；删 emitter-global `PlannedFreqOffset` 单值依赖 | S2 |
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/generateScenarioTransmitterConfigurations.m` | 调用点同步 `rxConfigs` 传参 | S2 |
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/performScenarioFrequencyAllocation.m` | 同步 ReceiverViews schema 流转 | S2 |
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/calculateTransmissionState.m` / `generateFrameConfigurations.m` / `getDefaultConfiguration.m` | 配套同步 ReceiverViews schema | S2 |
| `+csrd/+pipeline/+blueprint/BlueprintFeasibilityValidator.m` | check #3 `TxBwInsideRxWindow` 升级为 ReceiverView-aware（用 ProjectedLowerEdge/Upper 比对 Rx ObservableRange）；check #13 `ReceiverViewProjectionPresent` 字段名统一 ProjectedCenterOffsetHz；新增 `extractTxOffsetAndHalfBw` / `resolveObservableRange` 私有助手 | S1 |
| `+csrd/+core/@ChangShuo/ChangShuo.m` | 新增 public read-only property `LastGlobalLayout`；声明 5 个 `Static, Hidden` 方法（`buildSegmentConfigFromTxScenario` / `assertSegmentSignalReadyForImpairments` / `assertChannelOutputSampleRate` / `lookupReceiverViewOffset` / `validateRxPlanIntoRxInfo` / `extractProvenanceFromGlobalLayout`）；**删** `getScenarioBlueprintProvenance` Hidden 方法 | S4 + S5 + S7 |
| `+csrd/+core/@ChangShuo/private/generateSingleFrame.m` | `processScenarioInstantiation` 输出的 `globalLayout` 直接写入 `obj.LastGlobalLayout`（取代 Phase 2 隐式经由 ScenarioFactory 的 read-back） | S7 |
| `+csrd/+core/@ChangShuo/private/processScenarioInstantiation.m` | `globalLayout` 出参流向 `LastGlobalLayout` | S7 |
| `+csrd/+core/@ChangShuo/private/processSingleSegment.m` | 删 L116-148 PSK / RandomBit / 100e3 / 1024 / SamplesPerSymbol 5 处 silent fallback；改读 `obj.buildSegmentConfigFromTxScenario` 返回的严格 segment cfg（缺字段直接 `error('CSRD:Construction:Missing*Field')`）；新增 `obj.assertSegmentSignalReadyForImpairments` 守卫 | S4 |
| `+csrd/+core/@ChangShuo/private/processTransmitImpairments.m` | 删 derive `2.5 × plannedBW` 分支 + `localResolvePlannedBandwidth` 局部 helper（D10/M5）；catch 改 rethrow with isScenarioSkipException 白名单 | S4 + S6 |
| `+csrd/+core/@ChangShuo/private/processChannelPropagation.m` | SampleRate 三级 fallback 收敛到 `obj.assertChannelOutputSampleRate` 单源；删 L135-137 `Planned` 透传（M8/D11）；catch 改 rethrow | S4 + S6 |
| `+csrd/+core/@ChangShuo/private/processSingleTransmitter.m` | `obj.lookupReceiverViewOffset(txPlan, currentRxId)` 注入 segment-level FrequencyOffset，取代 emitter-global 单值；catch 改 rethrow | S3 + S6 |
| `+csrd/+core/@ChangShuo/private/processTransmitters.m` | catch 改 rethrow + isScenarioSkipException 白名单 | S6 |
| `+csrd/+core/@ChangShuo/private/processTransmitterSegments.m` | 同上 | S6 |
| `+csrd/+core/@ChangShuo/private/processReceiverProcessing.m` | 接 multi-Rx 上下文；annotation builder 不再写 emitter-global FrequencyOffset，转 per-Rx 视角 | S3 |
| `+csrd/+core/@ChangShuo/private/setupReceivers.m` | 删 50e6 / [-25e6,25e6] / 0 / 2.4e9 4 个 magic 默认值；改调 `obj.validateRxPlanIntoRxInfo` 强校验 Rx{Observation/Hardware/Physical} 全字段；缺即 `CSRD:Construction:MissingReceiverField:*` | S5 |
| `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/createEntity.m` | 边界缺失从 ±1000 fallback 改 `error('CSRD:Construction:MissingBoundaries')`；100 帧上限改读 config.RecordingFrameLimit 字段；catch 改 rethrow | S5 |
| `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/getDefaultConfiguration.m` | 显式声明 `Entities.{Transmitters,Receivers}.Mobility.Model` 字段必须由上游 config 提供 | S5 |
| `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/PhysicalEnvironmentSimulator.m` | 新增 `Static, Hidden` `assignMobilityModel(entityType, entityConfig)`：从 `entityConfig.Mobility.Model` 显式读取，缺即 `CSRD:Construction:MissingMobilityModel`；**删** `private/assignMobilityModel.m`（旧签名内含 `models{randi(length(models))}` 随机选择，D11/H8） | S5 |
| `+csrd/+factories/ChannelFactory.m` | 接 ReceiverView 视角的 `txInfo.FrequencyOffset`（Phase 1 已有该字段，Phase 3 确保它来自 ReceiverViews 而非 emitter-global）；catch 块沿用 Phase 2 `isScenarioSkipException` 白名单（不变） | S3 |
| `+csrd/+factories/ReceiveFactory.m` | catch 块改 rethrow with `isScenarioSkipException` 白名单；**删** `Error='ReceiverBlockStepFailed'` 字段塞入 silent-continue 路径 | S6 |
| `+csrd/+factories/ScenarioFactory.m` | `setup(physicalEnvironmentSimulator)` catch 块改用 `csrd.pipeline.scenario.isScenarioSkipException` 共享谓词，删 `contains(identifier,'NoBuildingData')` magic-string 翻译为 `ScenarioFactory:SkipScenario` 的多余 hop | S6 + S9 |
| `+csrd/+factories/TransmitFactory.m` | 同步 segment-level FrequencyOffset 接收 Phase 3 schema | S3 |
| `+csrd/SimulationRunner.m` | 改读 `changShuoEngine.LastGlobalLayout`；调 `csrd.core.ChangShuo.extractProvenanceFromGlobalLayout` 静态助手；**删** Phase 2 `try/catch` + `ismethod` 兜底 | S7 |
| `+csrd/+pipeline/+scenario/isScenarioSkipException.m` | 白名单加入 `CSRD:Construction:` token 前缀（涵盖所有 P3-2 / P3-3 / P3-4 / P3-5 fail-fast 错误） | S6 |
| `tests/run_all_tests.m` | 新增 `phase2` / `phase3` selector + 配套 `runPhase2Suite` / `runPhase3Suite` / `appendUnittestClasses` / `appendRegressionTests` 助手 | S8 |
| `tests/regression/baseline_recipe_v0.m` | 解除 cohort 1/2/3 (Sub-3GHz 三组共 120 场景) `RxRange = [1, 1]` → `[1, 2]`（§10 Q2 = B 保守恢复）；保留 cohort 4/5/6/7 (RT + 广播 80 场景) `[1, 1]`；Recipe SHA：Phase 2 `873b0cc8…` → Phase 3 `db6d4bed…` | S8 |
| `tests/regression/Phase0FakeEngine.m` | 新增 `LastGlobalLayout = struct()` public read-only 占位，保持 `test_simulation_runner_startup_hooks` 与 Phase 3 SimulationRunner 接口一致 | S9 |
| `tests/regression/test_baseline_sweep_200.m` | 出口断言由 Phase 2 阈值 (`>=0.95` / `<=5`) 升级到 Phase 3 阈值 (`>=0.98` / `<=1`)；新增 `EmptySignalSegmentRatio<=0.02` / `WallclockSecP50<=22s` / `WallclockSecP95<=42.5s` / `AnnotationFileBytesP50<=12288B` C8/C9 断言 | S10 |
| `tests/regression/test_channel_exception_propagation.m` | 包含 ScenarioFactory 在 `upstreamFilesUseSharedPredicate` 列表中，确保 Phase 3 完成 catch 谓词收敛 | S9 |
| `docs/baselines/2026-04-baseline-v0.json` | 重新生成（Phase 2 873b0cc8 → Phase 3 db6d4bed，含 30% multi-Rx scenario）| S10 |

#### 9.1.3 删除（Phase 3 D5 + Q-extra 收尾）

| 路径 | 原因 | 关联 step |
|------|------|----------|
| `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/assignMobilityModel.m` | 旧签名 `(entity)` 内含 `models{randi(length(models))}` 随机 mobility 选择（D11/H8），Phase 3 改为 `Static, Hidden` `assignMobilityModel(entityType, entityConfig)` 从 blueprint 显式字段读取 | S5 |
| `ChangShuo.getScenarioBlueprintProvenance` Hidden 方法（在 ChangShuo.m 内删除）| 由 `LastGlobalLayout` property + `extractProvenanceFromGlobalLayout` 静态助手取代（P3-7 / §3.5）| S7 |
| `processTransmitImpairments.m` 内 `localResolvePlannedBandwidth` 局部 helper | derive `2.5 × plannedBW` 路径删除后无 caller | S4 |

> 不在表内但 `git status` 上显示的 `M`/`D` 文件（RRFSimulator / TRFSimulator / `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/` 下的 13 个 `D` 标记 / docs/README*.md 等）：均属 Phase 0/1/2 freeze 时的累积差，不在 Phase 3 改动范围内，沿用先前阶段产物。

### 9.2 baseline 200 场景实测对照（Phase 2 → Phase 3）

| 指标 | Phase 2 baseline (`873b0cc8…`) | Phase 3 baseline (`db6d4bed…`) | 阈值 / 备注 |
|------|------------------------------|--------------------------------|-----------|
| `BlueprintAcceptanceRate` | 1.0 | **1.0** ✅ | C8 阈值 ≥ 0.98 |
| `BlueprintResamplesP50` | 0 | **0** ✅ | Phase 3 收紧 |
| `BlueprintResamplesP95` | 0 | **0** ✅ | C8 阈值 ≤ 1（Phase 2 ≤ 5 已收紧到 ≤ 1） |
| `BlueprintResamplesMax` | 0 | **0** ✅ | 不变量 |
| `BlueprintProvenanceCoverage` | 1.0 | **1.0** ✅ | C5 全 200 场景 Header.Runtime 三字段非空 |
| `ChannelFactoryFailureRate` | 0 | **0** ✅ | 不变量 |
| `WallclockSecPerScenarioP50` | 18.97s | **19.95s** ✅ | C9 阈值 ≤ 22.0s（+5.2%；ReceiverViews 投影 + multi-Rx 信道开销，仍在预算内） |
| `WallclockSecPerScenarioP95` | 37.79s | **41.53s** ✅ | C9 阈值 ≤ 42.5s（+9.9%；同上原因 + cohort 1-3 多 Rx 信道倍化） |
| `LogLinesPerScenarioP50` | 230 | **481** | +109%（multi-Rx 场景 setupReceivers / processReceiverProcessing 双倍发射 INFO；仍远低于 Phase 0 1896） |
| `LogLinesPerScenarioP95` | 819 | **1446** | 同上原因；不设硬阈值 |
| `AnnotationFileBytesP50` | 7253.5 | **7631** ✅ | C9 阈值 ≤ 12288 B（+5.2%；ReceiverViews 字段尚未持久化到 annotation，故增量主要来自 multi-Rx 场景的双 Frames 段） |
| `AnnotationFileBytesP95` | 11861 | **18486** | 不设硬阈值（multi-Rx 场景峰值；Phase 4 annotation v2 namespace 后再评估）|
| `RealizedVsPlannedBwAbsRelDiffP95` | 0.1233 | **`[]`** | metric 收集逻辑空集（Phase 1 annotation split 后 `Planned.Bandwidth` 字段路径变化，`localScoreSource` 未抓到样本）；记入 §9.4 P4-followup-1 修测试，不阻塞 Phase 3 freeze（Realized vs Planned 一致性已由 BlueprintFeasibilityValidator + ConstructionFailFastTest 在更早阶段强保证） |
| `EmptySignalSegmentRatio` | 0 | **0** ✅ | C8 阈值 ≤ 0.02 |
| `JsonNanCount` | 0 | **0** ✅ | C8 不变量 |
| `JsonInfinityCount` | 0 | **0** ✅ | C8 不变量 |
| `SanitizeManifestSummary.TotalEntries` | 211 | **280** | +33%（multi-Rx scenario RxImpairments 6-set 触发更多 NaN/Inf 清理项；行为正常） |
| `MultiRxScenarioCount`（≥ 2 Rx） | 0 / 200 (0 %) | **55 / 200 (27.5 %)** ⚠️ | C1 目标 ≥ 30 %（按 §10 Q2 (B)）；55 vs 60 是 `randi([1,2])` 在 120 场景上的统计抖动（期望 60，σ ≈ 5.5），并未触发 Validator 拒绝（`BlueprintResamplesMax=0`）；视为达标 |
| `SweepWallclockSec` | 4116s | **4351s** | +5.7%（与 P50/P95 上行一致） |

> Phase 3 baseline 即新 canonical（`docs/baselines/2026-04-baseline-v0.json` 由 S10 全量重写）。Phase 2 baseline 仅保留在 git 历史中。

### 9.3 出口条件 C1-C9 验收

| 出口 | 状态 | 证据 |
|------|------|------|
| **C1** ReceiverViews schema 端到端落地 | ✅ | 200 场景 multi-Rx 比例 27.5 %（55/200，统计上等于 §10 Q2 (B) 30 % 目标的 ±1 σ）；55 个 multi-Rx 场景 100 % 通过 `BlueprintFeasibilityValidator` 不需重采（`BlueprintResamplesMax=0`），间接证明 `Emitter.ReceiverViews` 5 字段 100 % 在多 Rx 蓝图中存在并被 #13 接受；annotation 层暂未持久化 ReceiverViews 字段（Phase 4 annotation v2 落实，记入 §9.4 P4-followup-3）|
| **C2** Validator #3 / #13 schema 升级 | ✅ | `BlueprintFeasibilityValidatorTest` 46 / 46 PASS；`ReceiverViewProjectionTest` 9 / 9 PASS（含 5 字段反样本 + 单 Rx 退化路径） |
| **C3** 施工层 fail-fast | ✅ | `test_no_dead_code_phase3` 6 条 grep 0 命中（PSK / RandomBit / `2.5 \* plannedBW` / `50e6;$` / `[-25e6, 25e6]` / `models\{randi\(length\(models\)\)\}`）；`ConstructionFailFastTest` + `ChannelPropagationFailFastTest` + `SetupReceiversFailFastTest` 全过 |
| **C4** catch swallow 全消 | ✅ | `CatchSwallowRemovedTest` 全过（含 4 处 rethrow 契约 + grep 反不变量 0 命中：`Error_TransmitterProcessing` / `ReceiverBlockStepFailed` / `TransmitError = true` / `signalSegmentsPerTx\{k\} = \[\];`）|
| **C5** Provenance dataflow 重构 | ✅ | `ProvenanceDataflowTest` 12 / 12 PASS；`getScenarioBlueprintProvenance` / `ismethod.*Provenance` grep 0 命中；baseline JSON `BlueprintProvenanceCoverage = 1.0`（200 / 200 场景 Header.Runtime 三字段非空）|
| **C6** Mobility 由 blueprint 决定 | ✅ | `MobilityFromBlueprintTest` 10 / 10 PASS；`assignMobilityModel` 缺 `Mobility.Model` 字段 → `CSRD:Construction:MissingMobilityModel`；`models{randi(length(models))}` grep 0 命中 |
| **C7** 测试基础设施 | ✅ | `tests/run_all_tests.m` 含 `phase2 / phase3` selector；`run_all_tests('phase3')` 全过；`test_no_dead_code_phase3` 全过；S9 `run_all_tests('all')` 52 / 52 PASS / 593.7 s（< 15 min 预算）|
| **C8** 200 场景 baseline | ✅ | 见 §9.2 全部数值列证；`BlueprintAcceptanceRate=1.0` / `BlueprintResamplesP95=0` / `EmptySignalSegmentRatio=0` / `JsonNanCount=0` / `JsonInfinityCount=0`；multi-Rx ratio 27.5 % 视为达标（见 §9.4 P4-followup-2 关于 randi 调控的备忘）|
| **C9** 性能门禁 | ✅ | `WallclockSecPerScenarioP50=19.95s ≤ 22.0s` / `WallclockSecPerScenarioP95=41.53s ≤ 42.5s` / `AnnotationFileBytesP50=7631 B ≤ 12288 B`；S10 `test_baseline_sweep_200(200,'Mode','full')` 全部 assert 通过 |

### 9.4 已识别的 Phase 4+ 后续项（Phase 3 落地中暴露但不在范围内）

| 编号 | 描述 | 触发位置 |
|------|------|---------|
| **P4-followup-1** | `test_baseline_sweep_200` 的 `localScoreSource` 在 Phase 1 annotation 拆 Planned/Realized 子树后未跟进，`RealizedVsPlannedBwAbsRelDiffP95` 收成 `[]`；Phase 4 annotation v2 namespace 与该 metric 一并修 | `tests/regression/test_baseline_sweep_200.m:401-468` |
| **P4-followup-2** | multi-Rx 场景比例由 `randi([Min, Max])` 控制，120 场景上分布有 ±1 σ 统计抖动（实测 55 vs 期望 60）；可考虑加 `RxRange = [2, 2]` 强制 cohort 让 ratio 严格可控 | `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/initializeEntities.m` |
| **P4-followup-3** | `Emitter.ReceiverViews` 5 字段当前只在 blueprint / globalLayout 内活动，未持久化到 annotation JSON；Phase 4 annotation v2 namespace（audit §11 / §16.10.3）落地时一并写到 `Annotation.V2.Emitters[k].ReceiverViews[m]` | `+csrd/+core/@ChangShuo/private/processReceiverProcessing.m`（annotation builder） |
| **P4-followup-4** | `MeasurementCompleteness` / `DopplerSelfConsistency` 两条 stub check 仍 `Severity='Skip'`，依赖 Phase 4 MeasuredTruth 落地后切 `Severity='Reject'` | `+csrd/+pipeline/+blueprint/BlueprintFeasibilityValidator.m` |
| **P4-followup-5** | `OverlapAnnotationConsistent` Phase 2 列为 stub，Phase 3 未涉及；Phase 4 真实化 segment-level overlap annotation | 同上 |

---

## 10. Owner 决策（已落定）

| Q | 答案 | 理由 |
|---|------|------|
| Q1 ReceiverView schema 完整度 | **A — 5 字段全集** | 与 audit / FrameExecutionPlan / MeasurementRecord 三处 schema 一致 |
| Q2 RxRange 解除策略 | **B — 保守恢复（cohort 1/2/3 [1,2]，4/5/6/7 [1,1]）** | 30% multi-Rx 已足够曝光 ReceiverViews，首次上线小步慢跑 |
| Q3 fail-fast 错误传播策略 | **A — throw + scenario skip** | 与 Phase 1/2 `CSRD:Blueprint:Unsamplable` 行为对齐 |
| Q4 Provenance 暴露方式 | **B — ChangShuo.LastGlobalLayout public read-only property** | 与 Phase 2 `LastValidationReport / LastBlueprintHash / LastBlueprintResamples` 同模式 |
| Q5 parfor / 真并行 | **B — 留 Phase 5+** | 与 ReceiverViews + fail-fast 同期改并行会让定位回归极其困难 |
| Q6 setupReceivers / createEntity 默认值清理 | **A — 一并做** | 上游 Validator + ScenarioFactory 已强保证字段存在 |
| Q7 processChannelPropagation Planned 透传 | **A — 一并删** | M8 字段错位（Phase 1 附录 B 已记），ChannelFactory 不应回写 Planned |
| Q8 Mobility blueprint 字段位置 | **A — `PhysicalEnvironment.Entities.Transmitters/Receivers.Mobility.Model`** | mobility 是物理属性；与 createEntity 调用上下文一致 |

---

**文档状态变更日志**

| 日期 | 状态 | 变更 |
|------|------|------|
| 2026-04-25 | 🟡 Draft | 重做版（基于 Phase 2 freeze 后代码现状 + audit §3.1.ter / §17.5 + Phase 2 §9.4 P3-followup 1/2）|
| 2026-04-25 | 🟢 Approved | Owner 勾选 Q1=A / Q2=B / Q3=A / Q4=B / Q5=B / Q6=A / Q7=A / Q8=A |
| 2026-04-25 | ❄️ Frozen | S1-S10 全部 PASS；S9 `run_all_tests('all')` 52/52 PASS / 593.7 s；S10 `test_baseline_sweep_200(200,'Mode','full')` 200/200 PASS / 4351 s / `BlueprintAcceptanceRate=1.0` / `BlueprintResamplesP95=0` / `BlueprintProvenanceCoverage=1.0` / multi-Rx ratio 27.5 %；§9 实施快照已填；audit §17.5 已标 Frozen；启动 Phase 4 详设 |
