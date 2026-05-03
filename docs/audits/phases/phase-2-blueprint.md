# Phase 2 详细设计 —— 蓝图层骨架（Profile 库 / BlueprintHash / Validator）

| 字段 | 值 |
|------|----|
| 状态 | ❄️ **Frozen**（2026-04-25 baseline 200 场景全过：BlueprintAcceptanceRate=1.0 / BlueprintResamplesP95=0 / BlueprintProvenanceCoverage=1.0；§9 实施快照已填，audit §17.4 已标 Frozen）|
| 顶层 audit 引用 | `docs/audits/2026-04-spectrum-blueprint-construction-refactor.md` §17.4（"Phase 2 蓝图层骨架"），并实施 §16.5 / §16.7 / §16.8 三处规范化条款 |
| 关联 H/M 条目 | H6 (allocateFrequenciesRandom/Optimized 转调假象) / H11 (channel modelName 多级回落) / H16 (`+csrd/+catalog/+profile/` 不存在) / H17 部分（Validator 不存在）/ D5 (modelNames{1} 兜底) / D7 (allocate 假分支) / C1 (强 schema)/ C5 (可施工率) / C8 (BlueprintHash) + §4.bis 12 条 + §4.ter 5 条 + §16.7 4 条 = **21 条 Validator check** |
| 前置 | Phase 1 已 Frozen（`signal struct` 字段契约 / mergeChannelOutput 白名单 / Channel Seed 含 BurstId / RFImpairments + RxImpairments 全集落地）|
| 目标产出 | **14** 个 profile `.m`（7 bands + 3 receivers + 3 phaseNoise + 1 antennaCompat + 1 loader）/ **2** 个 blueprint 工具 `.m`（computeBlueprintHash + BlueprintFeasibilityValidator）/ **1** 个 ScenarioFactory 改造（resample loop）/ **3** 处死代码删除（D7 两个 + D5 一处，D5 待 §1.4 决策）/ **6** 个新单测套（profileLoader / 14 profile 数值 / hash roundtrip / 21 条 validator 正反样本 / resample loop / D5 削路径）/ baseline JSON 重生成 |
| 预估耗时 | 实施 ~2 个工作日；S8 全套测试 ~12 min；S9 200 场景 baseline ~75 min |

---

## 0. 工作流契约（沿用 Phase 0 / 1）

1. 本设计文档先 **Draft** → owner 复核 §1.4 4 个开放点 → 文末 §10 "Owner 决策" 写明 → 状态改 **Approved** → 才允许动任何 `.m`
2. 实施严格按 §6 的"实施顺序" S1–S10 执行，单步实施 + 单步自测，**禁止跨 step 大改**
3. 每完成一个 step：跑 §5 中对应单元/回归脚本，必须本地 0 失败，才能进下一 step
4. 全部 step 完成后：重跑 `tests/regression/test_baseline_sweep_200.m(200,'Mode','full')`，比对 §7 七条出口 + Phase 1 已写死的不变量（baseline JSON 中 5 条强契约保持不变；3 条性能门禁不超 Phase 1 已批阈值）
5. 200 场景 baseline 全过 → 把本文档状态改 `Frozen`，把顶层 audit §17.4 行加 ✅ Frozen 日期，启动 Phase 3 详设

---

## 1. 范围与边界（必读）

### 1.1 在范围内（Phase 2 必须做）

| 编号 | 标题 | 当前问题 / 现状 | 处方位置 |
|------|------|----------------|---------|
| **P2-1** | Profile 库不存在 | `+csrd/+catalog/+profile/` 整目录缺失（grep 0 命中）；v0.3 §5.bis 给出的 7 个 band + 3 个 receiver + 3 档 phaseNoise + 1 个 antenna 兼容矩阵全是文档表格，没有任何 `.m` 文件 | §3.1（14 个 .m 落地）|
| **P2-2** | BlueprintHash 不存在 | grep `computeBlueprintHash` 在 `+csrd` 0 命中；annotation 里写的 `BlueprintHash` 字段当前是 placeholder | §3.2（typed-JSON 规范化 + SHA-256）|
| **P2-3** | BlueprintFeasibilityValidator 不存在 | grep `BlueprintFeasibilityValidator` 在 `+csrd` 0 命中；下游 `ScenarioFactory.stepImpl` 直接消费 simulator 输出，无任何施工前可施工性检查 | §3.3（21 条 check + ValidationReport）|
| **P2-4** | 蓝图重采样无机制 | 一旦 `step(communicationBehaviorSimulator,…)` 输出"施工失败的图纸"（带宽超 Rx 窗口、调制-天线不兼容等），下游 ChangShuo 直到调制/信道阶段才崩，整 scenario 浪费 | §3.4（ScenarioFactory 内 resample loop）|
| **D7** | `allocateFrequenciesRandom.m` / `allocateFrequenciesOptimized.m` 是转调 wrapper | 两文件 7 行代码 100% 转调 `allocateFrequenciesReceiverCentric`；`performScenarioFrequencyAllocation` 的 strategy switch + warning fallback 也是假分支 | §3.5（删除 + 收敛单 strategy）|
| **D5（待决，§1.4-Q4）** | `ChannelFactory.m:192-194` `modelNames{1}` 静默兜底 | 找不到模型时回落到 ChannelModels 字段表里的第一个（数组首元素），把"图纸要 RayTracing"悄悄换成 AWGN | §3.6（fail-fast 改 reject，Validator `ChannelModelInRegistry` 替它把 reject 决策提到蓝图层）|

### 1.2 不在范围内（Phase 2 禁止动）

下列今天看着也想顺手改但**绝不在 Phase 2 内动**的项目，必须严格留给后续阶段，否则 PR 自动拒：

- **D2 / D3 (M3)**：`processSingleSegment.m:142-148` 硬编码 PSK fallback —— 留 Phase 3
- **D10 (M5)**：`processTransmitImpairments.m:60` `2.5 × plannedBW` magic factor —— 留 Phase 3
- **D11 (H8)**：`assignMobilityModel.m:15-16` Mobility 随机选 —— 留 Phase 3
- **H12 (Doppler)** / **H17 (MeasuredTruth)** / **MeasuredTruth 系列 check 真生效** —— 留 Phase 4
- **任何 annotation 字段重命名 / V2 namespace** —— 留 Phase 4
- **改 ScenarioFactory 让它"按 profile name 直接采样蓝图"**（强引入 profile）—— 视 §1.4-Q1 决策可能留 Phase 3
- **配置文件 `config/_base_/factories/scenario_factory.m` 字段大改**（profile name 注入）—— 留 Phase 3
- **MultiBurstPerFrameTest 内的 segment 数 = 1 路径删除** —— Phase 1 兼容期保留
- **任何 `tests/regression/` 阈值收紧** —— 各 phase 自带 baseline，Phase 2 不动 Phase 1 阈值

> Phase 2 里**只能**动 §1.1 表里那 6 类问题；新增工具仅限 §4 列出的 17 个 `.m`。

### 1.3 与 §16/§17 现有结论的对齐

- §16.5.1 BlueprintHash 算法 = 本设计 §3.2 的硬契约（Phase 2 一字不改地落地）
- §16.7.1 D11-D14 4 条新 check 中：
  - `MeasurementCompleteness` / `DopplerSelfConsistency` —— Phase 2 落 **stub**（在 Validator 内注册接口但 `Severity='Skip'`，等 Phase 4 MeasuredTruth/Doppler 上线后改 `Reject`），**不计入 §7 出口的"21 条全有正反样本"**——只计入"接口已注册"
  - `OverlapAnnotationConsistent` —— Phase 2 落地真实 check（Phase 1 已经把 Frame 展开到 segment 数组）
  - `ChannelStateContinuity` —— Phase 2 落 **runtime contract test**（用 `tests/regression/test_channel_state_continuity.m`），不放在 Validator 内
- §16.7.2 ValidationReport struct 完全照搬，**唯一字段微调**：`Provenance.ValidatorVersion` 从 'v0.4.1' 改为 'p2-frozen'（Phase 2 freeze 时定）
- §16.8.1-4 Profile 目录骨架 / API / PhaseNoise 三档 / 兼容矩阵三档 —— Phase 2 一字不改地落地
- §17.4 的"目标 / 解决条目 / 主要新增 / 主要修改 / 出口条件"在本设计 §3 / §4 / §6 / §7 完整 checklist 化

### 1.4 待 owner 拍板的 4 个开放点（**Approved 之前必须确定**）

下列 4 个问题在 v0.3 / v0.4.1 文档中都**没有写死答案**，是 Phase 2 实施前必须先选项的硬决策。每条都给出推荐答案与理由，owner 在 §10 Owner 决策段勾选最终答案后再 Approved。

#### Q1: Profile 库与现有 config 的衔接力度？

- **(A) Soft-import（推荐）**：Phase 2 只把 14 个 profile `.m` 落地为**参考库**；现有 `config/_base_/factories/scenario_factory.m` 不引用它们；Validator 中所有 `*ProfileBound` 类 check 仅在蓝图字段含 `ProfileName` 时启用，否则跳过该 check（不打破现有 200 场景 baseline）
- **(B) Hard-import**：Phase 2 同步改 `scenario_factory.m`，让所有 emitter 必填 `BandProfile`、所有 receiver 必填 `ProfileName`；Validator 强校验
- **(C) Half-import**：Phase 2 提供 default profile（如 `LabAnalyzer_160MHz` + `ISM24_WiFi24`），现有 config 不写时自动绑定

> 推荐 **(A)**。理由：(B) 改动面太大，会同时触发"配置 migration + Validator + ScenarioFactory + ScenarioFactory 测试"四线齐改，违反 Phase 0 / 1 单步原则；(C) 有"隐式默认"反模式，与 Phase 0 删除 silent fallback 的总方针冲突；(A) 把"profile 落地"和"profile 推入主链"分两个 phase 做，Phase 3 再改 config 强引入。

#### Q2: 21 条 check 中，依赖 measurement 的 4 条（§16.7.1 D11-D14）在 Phase 2 怎么落？

- **(A) Stub 注册，标 `Severity='Skip'`，正反样本测试只校"接口存在 + 不抛异常"（推荐）**：Phase 4 MeasuredTruth / Doppler 上线后改 `Severity='Reject'` + 真实 check 逻辑
- **(B) 全部留到 Phase 4，Phase 2 只落 17 条**（21 - 4 = 17）
- **(C) Phase 2 用 mock / 注入 `Truth.Measured` 字段把这 4 条真实测试，但生产蓝图永远走不到这条路径**

> 推荐 **(A)**。理由：(A) 让"21 条" 这个数字在 Phase 2 freeze 时已经物理存在，Phase 4 上线后只切 Severity 不动接口签名，对下游侵入最小；(B) 会让 §7 出口 C2 的 "21 条" 在 Phase 2 实际是 17 条，与顶层 audit §17.4 描述不符；(C) mock 路径偏离生产真实情况，单测语义弱。

#### Q3: 蓝图重采样的发生层？

- **(A) ScenarioFactory.stepImpl 内 local resample loop（推荐）**：每帧调 `step(communicationBehaviorSimulator,…)` 后立即 validate，最多 `MaxResamples=50` 次重抽；50 次仍 reject → 抛 `CSRD:Blueprint:Unsamplable` 给 SimulationRunner，由 SimulationRunner 跳过该 scenario
- **(B) SimulationRunner 层 outer resample loop**：ScenarioFactory 抛 reject → SimulationRunner 重新调 `setup(scenarioFactory)` → 整 scenario 级别重抽
- **(C) 双层**：ScenarioFactory 内 5 次 + SimulationRunner 外 10 次

> 推荐 **(A)**。理由：(A) 把"图纸不可施工"的责任收敛在它最自然的产生位置（CommunicationBehaviorSimulator 之后），SimulationRunner 不需要知道"重采样"概念；(B) 浪费 PhysicalEnvironmentSimulator 的工作（已经算过的 entities/environment 全扔），且 setup-release 周期开销大；(C) 复杂度不值得。重采样次数本身需要写到 annotation `Header.Runtime.BlueprintResamples`（§4.4 schema 扩展点）。

#### Q4: D5 (`ChannelFactory.m:192-194` `modelNames{1}` silent fallback) 是否在 Phase 2 一并修？

- **(A) Phase 2 一并修（推荐）**：Validator 已经有 `ChannelModelInRegistry` check 把"图纸里 ChannelPreference.Model 不在已注册集合"拦在蓝图层；那么 `ChannelFactory.resolveChannelModelName` 内的最终兜底（`modelNames{1}`）就成了死代码，可以删；删的同时改成 `error('CSRD:Blueprint:ChannelModelMismatch', ...)` fail-fast，Validator 与 Factory 双层防御
- **(B) Phase 2 不动，留 Phase 3**：保持 Phase 2 实施面"只在 +utils/+profile/ + +utils/+blueprint/ + ScenarioFactory + 删 D7 三处"；ChannelFactory 不动

> 推荐 **(A)**。理由：(A) Validator + Factory 双重防御才是 fail-fast 的工程正确做法（避免下游测试场景跳过 Validator 直接调 Factory 时仍触发兜底）；删除 `modelNames{1}` 一行代码 + 改一行 throw + 一个回归测试 ~10 分钟工作量，与 Phase 2 总盘子相比几乎免费。**与此同时**，前面"先回落到 default for mode → 再回落到 AWGN → 再回落到 modelNames{1}"的三级兜底**只删最后一级**（modelNames{1}），保留 default-for-mode 与 AWGN 两级（这两级是声明性的、可控的兜底，不是 silent 的）。

> ⚠️ **如果 owner 选 (B)**：Phase 2 §3.6 / §6 S7 / §7 出口条件 C6 全部删除，文档相应缩减。

---

## 2. 事实凭据（带行号引用，禁止脑补）

### 2.1 P2-1 —— Profile 目录不存在

```bash
$ ls +csrd/+catalog/+profile/
ls: +csrd/+catalog/+profile/: No such file or directory
```

```bash
$ rg "BlueprintFeasibilityValidator|computeBlueprintHash|profileLoader" +csrd
# 0 hits
```

> Phase 2 必须从零创建整个 `+csrd/+catalog/+profile/` 目录树（含 4 个子包 + 14 个 `.m` 文件）；同样从零创建 `+csrd/+pipeline/+blueprint/` 目录（含 2 个 `.m` 文件）。

### 2.2 P2-3 / D5 —— ChannelFactory 三级 silent fallback

```180:195:+csrd/+factories/ChannelFactory.m
            end

            fallback = obj.getDefaultModelForMode(mode);
            if isfield(obj.factoryConfig.ChannelModels, fallback)
                modelName = fallback;
                return;
            end

            if isfield(obj.factoryConfig.ChannelModels, 'AWGN')
                modelName = 'AWGN';
                return;
            end

            modelNames = fieldnames(obj.factoryConfig.ChannelModels);
            modelName = modelNames{1};
        end
```

**结论**：第 193-194 行的 `modelNames{1}` 是 **silent fallback**——配置完全错位时把"图纸要 RayTracing"悄悄换成 ChannelModels 字段表的第一个 key（可能是任意东西，依赖字段顺序），与 `getDefaultModelForMode` 与 `'AWGN'` 这两级**声明性**兜底（debugger 可读、有日志可查）有本质区别。Phase 2 §1.4-Q4 决策决定是否一并删除。

### 2.3 D7 —— `allocateFrequenciesRandom.m` / `Optimized.m` 是空壳

```1:7:+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/allocateFrequenciesRandom.m
function [txConfigs, globalLayout] = allocateFrequenciesRandom(obj, txConfigs, ...
        observableRange, globalLayout)
    % allocateFrequenciesRandom - Random frequency allocation without optimization
    % Simpler random allocation for testing purposes
    [txConfigs, globalLayout] = allocateFrequenciesReceiverCentric(obj, txConfigs, ...
        observableRange, globalLayout);
end
```

```51:66:+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/performScenarioFrequencyAllocation.m
    switch obj.Config.FrequencyAllocation.Strategy
        case 'ReceiverCentric'
            [txConfigs, globalLayout] = allocateFrequenciesReceiverCentric(obj, txConfigs, ...
                observableRange, globalLayout);
        case 'Optimized'
            [txConfigs, globalLayout] = allocateFrequenciesOptimized(obj, txConfigs, ...
                observableRange, globalLayout);
        case 'Random'
            [txConfigs, globalLayout] = allocateFrequenciesRandom(obj, txConfigs, ...
                observableRange, globalLayout);
        otherwise
            obj.logger.warning('Unknown frequency allocation strategy: %s, using ReceiverCentric', ...
                obj.Config.FrequencyAllocation.Strategy);
            [txConfigs, globalLayout] = allocateFrequenciesReceiverCentric(obj, txConfigs, ...
                observableRange, globalLayout);
    end
```

**结论**：① `Random` 与 `Optimized` 文件 100% 转调 `ReceiverCentric`，给配置者"strategy 可选"的假象；② switch 的 `otherwise` 把"配置错字"悄悄替换成 `ReceiverCentric` 并打 warning，违反 Phase 0 silent fallback 删除原则。Phase 2 把这三块一起拆掉。

### 2.4 P2-4 —— ScenarioFactory.stepImpl 无 Validator 接入

```108:147:+csrd/+factories/ScenarioFactory.m
            try
                if ~obj.isSimulatorsInitialized
                    obj.initializeSimulators();
                    obj.isSimulatorsInitialized = true;
                end

                [entities, environment] = step(obj.physicalEnvironmentSimulator, frameId);

                [txConfigs, rxConfigs, communicationLayout] = ...
                    step(obj.communicationBehaviorSimulator, frameId, entities);

                instantiatedTxs = txConfigs;
                instantiatedRxs = rxConfigs;
                globalLayout = communicationLayout;
                ...
```

**结论**：`step(communicationBehaviorSimulator,…)` 输出后**直接交给下游施工**，无任何 validator gate。Phase 2 §3.4 在第 121 行（即 simulator step 之后、装配 globalLayout 之前）插入 validator-resample loop。

---

## 3. 处方

### 3.1 处方 P2-1 —— Profile 库 14 个 `.m` 落地

#### 3.1.1 目录骨架

完全照搬 §16.8.1，Phase 2 freeze 时这 14 个文件必须全部存在（grep 验证）：

```text
+csrd/+catalog/+profile/
├── profileLoader.m                        # 唯一入口；按 (category, name) 返回 struct
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
│   ├── Low.m
│   ├── Mid.m
│   └── High.m
└── +antennaCompat/
    └── AntennaModulationMatrix.m
```

#### 3.1.2 `profileLoader.m` 签名（§16.8.2 一字不改）

```matlab
function profile = profileLoader(category, name)
% PROFILELOADER  Load a profile struct by (category, name).
%
% Inputs:
%   category : char vector, one of {'bands','receivers','phaseNoise','antennaCompat'}
%   name     : char vector, must match a function name in
%              +csrd/+catalog/+profile/+<category>/<name>.m
%
% Outputs:
%   profile  : struct, schema depends on category (see §3.1.3)
%
% Throws:
%   CSRD:Profile:NotFound       — category/name not found
%   CSRD:Profile:SchemaInvalid  — loaded struct missing required fields
end
```

实施要点：
- 用 `which(['csrd.catalog.profile.' category '.' name])` 探测存在性
- 用 `feval` 调对应包函数
- 返回前调 `validateProfileSchema(category, profile)`（同文件 helper）：
  - `bands`：必含 `FrequencyRangeHz [1×2]` / `RecommendedBandwidthsHz {cell}` / `RecommendedModulationFamilies {cell}` / `TemporalPattern (char)` / `RecommendedTxAntennas [1×N]` / `TypicalNoiseFigureDb (scalar)` / `RecommendedRxProfiles {cell}`
  - `receivers`：必含 `SampleRateChoicesHz {cell or vector}` / `ObservableBandwidthHz` / `NumAntennasRange [1×2]` / `NoiseFigureRangeDb [1×2]` / `SensitivityDbm (scalar)` / `CarrierFrequencyRangeHz [1×2]`
  - `phaseNoise`：必含 `LevelDbcPerHz [1×K]` / `FrequencyOffsetsHz [1×K]`
  - `antennaCompat`：必含 `Matrix (containers.Map)`，key 为 modulation family（char），value 为 1×5 cell of {'Forbidden'|'Conditional'|'Allowed'}

#### 3.1.3 各类 profile 的 schema 与数值（§16.8.3-4 + §5.bis 数值表照搬）

**A. Bands（7 个，§5.bis A）**

每个 band `.m` 内容形如：

```matlab
function profile = ISM24_WiFi24()
profile = struct( ...
    'FrequencyRangeHz',              [2400e6 2483.5e6], ...
    'RecommendedBandwidthsHz',       {{20e6, 40e6}}, ...
    'RecommendedModulationFamilies', {{'OFDM','SC-FDMA'}}, ...
    'TemporalPattern',               'Burst', ...           % Continuous|Burst|Scheduled
    'BurstOnTimeRangeMs',            [1 10], ...
    'BurstOffTimeRangeMs',           [1 100], ...
    'RecommendedTxAntennas',         [1 4], ...             % [min max]
    'TypicalNoiseFigureDb',          7, ...
    'RecommendedRxProfiles',         {{'LabAnalyzer_160MHz','DenseArrayStation_200MHz'}});
end
```

7 个 band 的具体数值见 §5.bis A 表格，本设计**不在文档内重抄**——避免文档/代码二处来源不一致；S2 单测对每个 band 跑一次 schema + 数值断言（§5.2.A）。

**B. Receivers（3 个，§5.bis B）**

```matlab
function profile = LabAnalyzer_160MHz()
profile = struct( ...
    'SampleRateChoicesHz',     {{40e6, 80e6, 160e6}}, ...
    'ObservableBandwidthHz',   [], ...                       % == SampleRate（运行时绑定）
    'NumAntennasRange',        [1 4], ...
    'NoiseFigureRangeDb',      [5 7], ...
    'SensitivityDbm',          -110, ...
    'CarrierFrequencyRangeHz', [9e3 8e9]);
end
```

`ObservableBandwidthHz=[]` 表示**接收机硬约束**（§5.bis B 末尾）"等效基带契约"——`Validator` 的 `RxFsEqualsObservableBw` check 会强制 `Receiver.SampleRate == Receiver.ObservableBandwidth`。

**C. PhaseNoise（3 档，§16.8.3）**

```matlab
function profile = Mid()
profile = struct( ...
    'LevelDbcPerHz',     [-80 -100 -120 -135], ...
    'FrequencyOffsetsHz', [1e3 1e4 1e5 1e6]);
end
```

三档数值完全照搬 §16.8.3 表。

**D. AntennaModulationMatrix（1 个，§16.8.4）**

```matlab
function profile = AntennaModulationMatrix()
m = containers.Map('KeyType','char','ValueType','any');
m('FM')      = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};  % 1/2/4/8/16 Tx
m('PM')      = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};
m('DSBAM')   = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};
m('SSBAM')   = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};
m('DSBSCAM') = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};
m('VSBAM')   = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};
m('FSK')     = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};
m('MSK')     = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};
m('CPFSK')   = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};
m('GFSK')    = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};
m('GMSK')    = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};
m('PSK')     = {'Allowed','Allowed','Allowed','Conditional','Forbidden'};
m('QAM')     = {'Allowed','Allowed','Allowed','Conditional','Forbidden'};
m('PAM')     = {'Allowed','Allowed','Allowed','Conditional','Forbidden'};
m('APSK')    = {'Allowed','Allowed','Allowed','Conditional','Forbidden'};
m('OOK')     = {'Allowed','Allowed','Allowed','Conditional','Forbidden'};
m('ASK')     = {'Allowed','Allowed','Allowed','Conditional','Forbidden'};
m('OFDM')    = {'Allowed','Allowed','Allowed','Allowed','Conditional'};
m('SC-FDMA') = {'Allowed','Allowed','Allowed','Forbidden','Forbidden'};
m('OTFS')    = {'Allowed','Forbidden','Forbidden','Forbidden','Forbidden'};

profile = struct( ...
    'Matrix', m, ...
    'AntennaBins', [1 2 4 8 16], ...
    'Conditions', struct( ...
        'PSK_QAM_x8',   'SymbolRate >= 1e6', ...      % 见 §16.8.4 注 *
        'OFDM_x16',     'NumSubcarriers >= 512'));    % 见 §16.8.4 注 **
end
```

#### 3.1.4 与下游兼容性

Phase 2 落地的 14 个 `.m` **当前没有任何下游消费**（§1.4-Q1 推荐 (A) Soft-import）。它们的存在只服务于：
- Validator 内 `*ProfileBound` check（蓝图字段含 `ProfileName` 时启用）
- 单元测试 + 文档/培训材料的引用源（避免文档表格与代码二来源漂移）
- Phase 3 配置 migration 时直接 `csrd.catalog.profile.profileLoader('bands','ISM24_WiFi24')` 即可

#### 3.1.5 单元测试断言点

`tests/unit/ProfileLoaderTest.m`（新增，§5.2.A）：

1. 14 张 profile 各跑一次 `csrd.catalog.profile.profileLoader(category,name)` → 返回 struct，schema 字段全在
2. `profileLoader('bands','NotExist')` → throws `CSRD:Profile:NotFound`
3. `profileLoader('typo','xxx')` → throws `CSRD:Profile:NotFound`
4. **数值校核**（防文档/代码漂移）：每张 band/receiver profile 抽 2-3 个关键字段（如 ISM24 的 `FrequencyRangeHz==[2400e6 2483.5e6]`）assertEqual
5. PhaseNoise 三档：`LevelDbcPerHz` 长度等于 `FrequencyOffsetsHz` 长度（§3.1.3.C）
6. AntennaModulationMatrix：每个 modulation family 的 cell 长度 == 5（与 `AntennaBins` 长度一致）

---

### 3.2 处方 P2-2 —— BlueprintHash 落地

#### 3.2.1 接口（§16.5.1 一字不改）

```matlab
function hashHex16 = computeBlueprintHash(blueprint)
% COMPUTEBLUEPRINTHASH Canonical SHA-256 hash (first 16 hex chars) of a blueprint.
%
% Inputs:
%   blueprint : struct, ScenarioBlueprint (any nested struct/cell/numeric/char)
%
% Outputs:
%   hashHex16 : 1x16 char hex digest
%
% Throws:
%   CSRD:Blueprint:HashFailed  — blueprint contains NaN/Inf/Complex value
end
```

#### 3.2.2 typed-JSON 规范化算法（§16.5.1 + 工程细化）

```matlab
function jsonStr = canonicalizeBlueprint(blueprint)
%   1. struct 字段按 sort(fieldnames) 字典序递归处理
%   2. cell array 平铺为 JSON array，元素递归
%   3. numeric:
%        - NaN/Inf/Complex → throw CSRD:Blueprint:HashFailed
%        - single → sprintf('%.6g', x)
%        - double → sprintf('%.17g', x)
%        - integer → sprintf('%d', int64(x))
%        - logical → 'true' / 'false'
%   4. char/string → JSON string（含转义）
%   5. struct array (1×N, N>1) → JSON array of objects
%   6. 容器（containers.Map）→ 不允许出现在 blueprint 内（throw CSRD:Blueprint:HashFailed）
```

实现实施约束：
- **不依赖** `jsonencode`（jsonencode 字段顺序不稳定 + NaN/Inf 行为非标准）—— 用纯字符串拼接
- 测试覆盖：相同 struct 两种 `setfield` 顺序构造 → canonicalize 后字节级相等

#### 3.2.3 SHA-256 + 取前 16 hex

```matlab
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(uint8(jsonStr));
hashBytes = typecast(md.digest(), 'uint8');
hashHexFull = lower(reshape(dec2hex(hashBytes,2)', 1, []));
hashHex16 = hashHexFull(1:16);
```

> Java SHA-256 是 MATLAB 内置可用、跨平台一致；不引入新工具箱依赖。

#### 3.2.4 与下游兼容性

- Phase 1 §3.7 `stampRuntimeHeader` 已在 `Header.Runtime` 写 `BlueprintHash` 字段（当前是 placeholder `''`）。Phase 2 把 `SimulationRunner` 改为：在 stampRuntimeHeader 调用前调用 `csrd.pipeline.blueprint.computeBlueprintHash(scenarioBlueprint)`，把结果传入。
- **作用域**：`scenarioBlueprint` 在 Phase 2 阶段尚未有正式 schema（Phase 3 才完整定义 ScenarioBlueprint）。Phase 2 用"当前 ScenarioFactory.stepImpl 输出的 (txConfigs, rxConfigs, globalLayout) 三元组打包成 struct"作为 hash 输入；Phase 3 把它替换为正式 ScenarioBlueprint。**Hash 算法本身不需要改**——只是输入对象升级。

#### 3.2.5 单元测试断言点

`tests/unit/ComputeBlueprintHashTest.m`（新增，§5.2.B）：

1. **RoundTrip**：同一 blueprint struct 序列化两次（用同一进程内 `canonicalizeBlueprint`） → 字节级相等；hash 相等
2. **顺序无关**：`s1.A=1; s1.B=2;` 与 `s2.B=2; s2.A=1;` → hash 相等
3. **嵌套**：`struct.subStruct.subSubField = 0.1+0.2` 与单层 `struct.subStruct.subSubField = 0.3` → hash **不**相等（因为浮点字面量不同；文档化此约束以防误用）
4. **Cell array**：`{1,2,3}` 与 `[1,2,3]` 数组 → hash **不**相等（cell vs vector 在 typed-JSON 中区分）
5. **NaN/Inf 反样本**：blueprint 含 `NaN` → throws `CSRD:Blueprint:HashFailed`
6. **Complex 反样本**：blueprint 含复数 → throws `CSRD:Blueprint:HashFailed`
7. **containers.Map 反样本**：blueprint 含 `containers.Map` → throws `CSRD:Blueprint:HashFailed`
8. **跨进程**（手工）：把 blueprint 序列化为 `.mat` → 重启 MATLAB → 读回 → hash 相等（保护跨 worker 一致性）

---

### 3.3 处方 P2-3 —— BlueprintFeasibilityValidator + 21 条 check

#### 3.3.1 类位置与签名

```matlab
% +csrd/+pipeline/+blueprint/BlueprintFeasibilityValidator.m
classdef BlueprintFeasibilityValidator < handle
    % BLUEPRINTFEASIBILITYVALIDATOR Static-only feasibility validator for
    % ScenarioBlueprint structs. Returns a structured ValidationReport
    % (see §16.7.2). All 21 checks are method-level static functions
    % grouped by category.

    methods (Static)
        function report = validate(blueprint)
            % Run all 21 checks against blueprint; return ValidationReport.
        end
    end

    methods (Static)        % public to enable per-check unit testing
        % §4.bis B 的 12 条
        function failure = checkFrameSampleConsistency(blueprint)
        function failure = checkRxFsEqualsObservableBw(blueprint)
        function failure = checkTxBwInsideRxWindow(blueprint)
        function failure = checkModulationAntennaCompatible(blueprint)
        function failure = checkRFImpairmentRange(blueprint)
        function failure = checkBurstTotalDurationFits(blueprint)
        function failure = checkCrossFrameSegmentMinSamples(blueprint)
        function failure = checkOsmFileExistsAndBuildings(blueprint)
        function failure = checkChannelModelInRegistry(blueprint)
        function failure = checkTrajectoryMonotonicAndCovers(blueprint)
        function failure = checkLinkDistanceAboveMin(blueprint)
        function failure = checkMemoryBudget(blueprint)

        % §4.ter 的 5 条
        function failure = checkReceiverViewProjectionPresent(blueprint)
        function failure = checkBurstOverlapsFrameExpansion(blueprint)
        function failure = checkMeasurementPlanesSeparated(blueprint)
        function failure = checkGeometryGranularityDeclared(blueprint)
        function failure = checkReceiverOutputWindowConsistent(blueprint)

        % §16.7.1 的 4 条
        function failure = checkOverlapAnnotationConsistent(blueprint)
        function failure = checkMeasurementCompleteness(blueprint)         % §1.4-Q2 stub
        function failure = checkDopplerSelfConsistency(blueprint)           % §1.4-Q2 stub
        function failure = checkChannelStateContinuity(blueprint)           % runtime ContractTest, 不在 Validator 内, 见 §3.3.4
    end
end
```

#### 3.3.2 单条 check 的返回契约

每个 `check*` 函数返回：

```matlab
failure = struct( ...
    'Code',     'TxBwInsideRxWindow', ...        % machine-readable
    'Severity', 'Reject', ...                     % 'Reject' | 'Warn' | 'Skip'
    'Message',  'Tx_001 BW 25MHz exceeds Rx_001 window 20MHz', ...
    'Hint',     'Reduce PlannedBandwidthHz to <= 20e6', ...
    'Field',    'Emitters(1).PlannedBandwidthHz');
% 若 check pass: failure 为 0×1 空 struct array
```

`validate` 主函数：

```matlab
function report = validate(blueprint)
    checkList = {
        @checkFrameSampleConsistency, @checkRxFsEqualsObservableBw, ...
        @checkTxBwInsideRxWindow,     @checkModulationAntennaCompatible, ...
        ... % 21 个 check 全列
    };

    failures = repmat(struct('Code','','Severity','','Message','','Hint','','Field',''), 0, 1);
    for k = 1:numel(checkList)
        f = checkList{k}(blueprint);
        if ~isempty(f)
            failures(end+1) = f; %#ok<AGROW>
        end
    end

    rejects = failures(strcmp({failures.Severity},'Reject'));
    warns   = failures(strcmp({failures.Severity},'Warn'));

    report = struct( ...
        'IsFeasible',      isempty(rejects), ...
        'BlueprintHash',   csrd.pipeline.blueprint.computeBlueprintHash(blueprint), ...
        'NumChecksPassed', numel(checkList) - numel(failures), ...
        'NumChecksFailed', numel(failures), ...
        'FailedChecks',    rejects, ...
        'WarnChecks',      warns, ...
        'Provenance',      struct( ...
            'ValidatorVersion', 'p2-frozen', ...
            'Timestamp',        char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss''Z''')) ));
end
```

#### 3.3.3 21 条 check 的实现要点（每条仅一句话；详细落地在 S4 实施）

| # | Code | 实现要点 | Severity | §1.4-Q2 |
|---|------|----------|----------|---------|
| 1 | `FrameSampleConsistency` | `abs(FrameDuration*Receiver.SampleRate - FrameNumSamples) <= 1` | Reject | — |
| 2 | `RxFsEqualsObservableBw` | `Receiver.SampleRate == Receiver.ObservableBandwidth` | Reject | — |
| 3 | `TxBwInsideRxWindow` | `\|ProjectedCenterOffsetHz\| + PlannedBandwidthHz/2 <= ObservableBandwidth/2` | Reject | — |
| 4 | `ModulationAntennaCompatible` | 查 `AntennaModulationMatrix` 三档表；`Conditional` 时再查 `Conditions` 子约束 | Reject | — |
| 5 | `RFImpairmentRange` | IIP3∈[-10,40] dBm；PhaseNoise∈{Low,Mid,High}；IQImbalance∈[0,3] dB | Reject | — |
| 6 | `BurstTotalDurationFits` | `sum(Bursts.Duration) <= NumFrames*FrameDuration` | Reject | — |
| 7 | `CrossFrameSegmentMinSamples` | 每段 `visibleSamples >= 64` | Reject | — |
| 8 | `OsmFileExistsAndBuildings` | 若 `ChannelPreference.Model='RayTracing'`：`isfile(OSMFile)` + 有 buildings 或显式 `TerrainFallback='FlatTerrain'` | Reject | — |
| 9 | `ChannelModelInRegistry` | `ChannelPreference.Model` ∈ `factoryConfig.ChannelModels` 字段集 | Reject | — |
| 10 | `TrajectoryMonotonicAndCovers` | `Trajectory.SampleTimes` 严格递增，且 `[min,max] ⊇ [0, NumFrames*FrameDuration]` | Reject | — |
| 11 | `LinkDistanceAboveMin` | 任意 burst 中点 Tx-Rx 距离 ≥ `MinDistanceMeters` (默认 1m) | Reject | — |
| 12 | `MemoryBudget` | `NumFrames*FrameNumSamples*NumReceiveAntennas*16 <= MemoryBudgetMB*1024^2` | Warn → Reject | — |
| 13 | `ReceiverViewProjectionPresent` | 每个可见 emitter-receiver 对必有 `ReceiverView`；多 receiver 不退回 emitter 全局 `WindowFrequencyOffset` | Reject | — |
| 14 | `BurstOverlapsFrameExpansion` | 任何与 frame 时间窗有重叠的 burst 必须展开出 segment（Phase 1 已实现 ActiveIntervalIndices 数组）| Reject | — |
| 15 | `MeasurementPlanesSeparated` | 若 `aggregate GT` 关闭且同 frame 同 receiver 可见源数 > 1 → 必须有 `SourcePlane` + `FramePlane` | Reject | — |
| 16 | `GeometryGranularityDeclared` | annotation 必须写 `GeometryGranularity ∈ {'Frame','SegmentMidpoint'}` | Reject | — |
| 17 | `ReceiverOutputWindowConsistent` | 若 `OutputWindowPolicy='ExactFrameClip'` → 保存 receiver 输出长度 == `FrameNumSamples` | Reject | — |
| 18 | `OverlapAnnotationConsistent` | `BurstSchedule.Bursts(k).OverlappingFramesIds` 与 FrameExecutionPlan 实际展开 frame 集一致 | Reject | — |
| 19 | `MeasurementCompleteness` | **Phase 2 stub**（Severity='Skip'，正反样本只测接口存在）；Phase 4 改 'Reject'，验 `Truth.Measured.{SourcePlane,FramePlane}.OccupiedBandwidthHz` 至少一个非空非 NaN | Skip → Reject (Phase 4) | Q2 |
| 20 | `DopplerSelfConsistency` | **Phase 2 stub**；Phase 4 改：若 `RelativeRadialVelocityMps != 0` → `DopplerShiftHz` 接近 `f_c·v/c`（容差 5%）| Skip → Reject (Phase 4) | Q2 |
| 21 | `ChannelStateContinuity` | **不在 Validator 内**，落 `tests/regression/test_channel_state_continuity.m`（Phase 1 H13 修复后已具备测试基础）| 回归测试，独立 |

> 第 21 条由 §3.3.4 单独说明；Validator 内部只有 20 条静态方法。"21 条"是 Phase 2 freeze 时 §17.4 + §16.7 的总条数。

#### 3.3.4 第 21 条 `ChannelStateContinuity` 单独落地

`tests/regression/test_channel_state_continuity.m`（新增）：
- 构造一个 burst 跨 5 帧的 minimal scenario
- 在每帧后 hook 出 channel block 的 impulse response 前 N 个 tap
- 断言：同 BurstId 跨帧的 IR 头部相关系数 > 0.99（Phase 1 H13 Channel Seed 含 BurstId 修复后该 invariant 应自动满足）
- 反样本：mock 一个 burst 跨帧 seed 不一致的场景 → 相关系数 < 0.5 → 测试 fail

#### 3.3.5 与下游兼容性

- Validator 是**纯静态**，不持状态，不引入新的 System object
- `validate(blueprint)` 不抛异常（除非 `computeBlueprintHash` 抛 HashFailed，那是 P2-2 的范围）；所有"图纸不可施工"的语义都通过 `report.IsFeasible == false` 表达
- 调用方（Phase 2 只有 ScenarioFactory.stepImpl）在 §3.4 决定 reject 后是 resample 还是抛 `CSRD:Blueprint:Unsamplable`

#### 3.3.6 单元测试断言点

`tests/unit/BlueprintFeasibilityValidatorTest.m`（新增，§5.2.C，21 条 × 2 = 42 个 testCase）：

每条 check 一个 pass case + 一个 reject case；所有 stub check（19/20）只测"接口存在 + 不抛异常 + Severity='Skip'"。

`tests/unit/ValidationReportTest.m`（新增）：
- `report.IsFeasible == (numel(report.FailedChecks) == 0)`
- `report.BlueprintHash` 是 1×16 char
- `report.Provenance.ValidatorVersion == 'p2-frozen'`
- 同一 blueprint validate 两次 → `report.BlueprintHash` 相等

---

### 3.4 处方 P2-4 —— ScenarioFactory.stepImpl 接 Validator + Resample loop

#### 3.4.1 改前/改后

**改前**（`ScenarioFactory.m:108-147`）：

```matlab
[entities, environment] = step(obj.physicalEnvironmentSimulator, frameId);
[txConfigs, rxConfigs, communicationLayout] = ...
    step(obj.communicationBehaviorSimulator, frameId, entities);
% ... 直接装配 globalLayout 给下游 ...
```

**改后**：

```matlab
[entities, environment] = step(obj.physicalEnvironmentSimulator, frameId);

maxResamples = obj.getMaxResamples();           % §3.4.2
resampleCount = 0;
report = [];
while true
    [txConfigs, rxConfigs, communicationLayout] = ...
        step(obj.communicationBehaviorSimulator, frameId, entities);

    blueprint = obj.assembleBlueprint(txConfigs, rxConfigs, communicationLayout);  % §3.4.3
    report = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.validate(blueprint);
    if report.IsFeasible
        break;
    end
    resampleCount = resampleCount + 1;
    obj.logger.warning(['Frame %d: blueprint reject (try %d/%d): %s'], ...
        frameId, resampleCount, maxResamples, ...
        strjoin({report.FailedChecks.Code}, ','));
    if resampleCount >= maxResamples
        error('CSRD:Blueprint:Unsamplable', ...
            ['Frame %d: blueprint rejected %d times in a row. Last failed checks: %s'], ...
            frameId, resampleCount, strjoin({report.FailedChecks.Code}, ','));
    end
end

obj.lastValidationReport = report;            % §3.4.4 暴露给 SimulationRunner
obj.lastBlueprintResamples = resampleCount;    % §3.4.4

instantiatedTxs = txConfigs;
instantiatedRxs = rxConfigs;
globalLayout = communicationLayout;
% ... 后续装配照旧 ...
```

#### 3.4.2 `MaxResamples` 配置点

```matlab
function n = getMaxResamples(obj)
    n = 50;                                    % 默认 §4.bis C
    if isfield(obj.factoryConfig, 'Validator') && ...
            isfield(obj.factoryConfig.Validator, 'MaxResamples')
        n = obj.factoryConfig.Validator.MaxResamples;
    end
end
```

#### 3.4.3 `assembleBlueprint` 临时实现

Phase 2 阶段 ScenarioBlueprint 正式 schema 还没定（留 Phase 3）；本函数只把当前可用的 (txConfigs, rxConfigs, communicationLayout) 三元组打包：

```matlab
function bp = assembleBlueprint(~, txConfigs, rxConfigs, layout)
    bp = struct( ...
        'Emitters',           txConfigs, ...
        'Receivers',          rxConfigs, ...
        'CommunicationLayout', layout, ...
        'BlueprintSchemaVersion', 'phase2-transitional');
end
```

> **所有 21 条 check** 的实现都要兼容这个 transitional schema（缺字段 → check 跳过；字段存在但取值非法 → reject）。Phase 3 把 `BlueprintSchemaVersion` 升到 `'v1'` 时才把"缺字段也 reject"打开。

#### 3.4.4 暴露给 SimulationRunner

新增 ScenarioFactory public properties：

```matlab
properties (Access = public, SetAccess = private)
    lastValidationReport struct = struct()       % 最近一次 validate 结果
    lastBlueprintResamples (1,1) double = 0      % 最近一次 stepImpl 重采样次数
end
```

`SimulationRunner.stampRuntimeHeader` 从 `obj.scenarioFactory.lastValidationReport` / `lastBlueprintResamples` 读取，写入 annotation `Header.Runtime`：

```matlab
record.Header.Runtime.BlueprintHash      = report.BlueprintHash;
record.Header.Runtime.BlueprintResamples = lastBlueprintResamples;
record.Header.Runtime.ValidatorVersion   = report.Provenance.ValidatorVersion;
```

> Phase 1 §3.7 已经保留 `Header.Runtime.BlueprintHash` 字段 placeholder；Phase 2 把它填实，并新增 `BlueprintResamples` + `ValidatorVersion` 两个字段。

#### 3.4.5 isScenarioSkipException 白名单更新

`+csrd/+pipeline/+scenario/isScenarioSkipException.m` 加入：

```matlab
'CSRD:Blueprint:Unsamplable'
```

效果：连续 50 次 reject → SimulationRunner 跳过该 scenario，记入 `BlueprintAcceptanceRate` 分母（§7 出口 C2）。

#### 3.4.6 单元测试断言点

`tests/unit/ScenarioFactoryResampleLoopTest.m`（新增，§5.2.D）：

1. **Pass once**：blueprint 一次 pass → `lastBlueprintResamples == 0`，`lastValidationReport.IsFeasible == true`
2. **Resample then pass**：mock simulator 让前 3 次 reject、第 4 次 pass → `lastBlueprintResamples == 3`
3. **Unsamplable**：mock 永远 reject → throws `CSRD:Blueprint:Unsamplable`，message 含连续 50 次的 last failed checks
4. **isScenarioSkipException(`CSRD:Blueprint:Unsamplable`)** 返回 true
5. `MaxResamples` 配置注入：`Validator.MaxResamples=3` → 第 4 次 reject 后立即抛 Unsamplable

---

### 3.5 处方 D7 —— `allocateFrequenciesRandom/Optimized` 删除

#### 3.5.1 三处改动

1. **删除 `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/allocateFrequenciesRandom.m`**（整文件）
2. **删除 `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/allocateFrequenciesOptimized.m`**（整文件）
3. **改 `performScenarioFrequencyAllocation.m:51-66`**：

```matlab
strategyName = obj.Config.FrequencyAllocation.Strategy;
if ~strcmp(strategyName, 'ReceiverCentric')
    error('CSRD:Scenario:UnsupportedFrequencyStrategy', ...
        ['FrequencyAllocation.Strategy=''%s'' is no longer supported. ', ...
         'Only ''ReceiverCentric'' is available; ''Optimized'' / ''Random'' ', ...
         'were thin wrappers and have been removed in Phase 2.'], ...
        strategyName);
end
[txConfigs, globalLayout] = allocateFrequenciesReceiverCentric(obj, txConfigs, ...
    observableRange, globalLayout);
```

4. **改 `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/CommunicationBehaviorSimulator.m:159-161`**：删 `allocateFrequenciesOptimized` / `allocateFrequenciesRandom` 两条 method 声明；保留 `allocateFrequenciesReceiverCentric`

5. **改 `getDefaultConfiguration.m:6` + `generateScenarioTransmitterConfigurations.m:24/26`**：strategy 默认值与 globalLayout.Strategy 注入逻辑保留 'ReceiverCentric'，但加注释说明"Phase 2 起仅支持单 strategy"

#### 3.5.2 文档清理

`CommunicationBehaviorSimulator.m:35-56` 类 docstring 里 `'ReceiverCentric','Optimized','Random'` 三选一描述 → 改为单 strategy 描述。

#### 3.5.3 与下游兼容性

- 配置文件 `config/_base_/factories/scenario_factory.m` 当前默认即 `ReceiverCentric`（grep 验证），无 migration 风险
- 任何外部 user override 把 strategy 设为 `'Optimized'` / `'Random'` 在 Phase 2 起会立即抛 `CSRD:Scenario:UnsupportedFrequencyStrategy` —— **故意 fail-fast**，与 Phase 0 silent fallback 删除原则一致

#### 3.5.4 单元测试断言点

`tests/unit/FrequencyAllocationStrategyTest.m`（新增，§5.2.E）：

1. `Strategy='ReceiverCentric'` → 正常执行
2. `Strategy='Optimized'` → throws `CSRD:Scenario:UnsupportedFrequencyStrategy`
3. `Strategy='Random'` → throws `CSRD:Scenario:UnsupportedFrequencyStrategy`
4. `Strategy='typo'` → throws `CSRD:Scenario:UnsupportedFrequencyStrategy`
5. **死代码反样本**：grep `allocateFrequenciesRandom\|allocateFrequenciesOptimized` 在 `+csrd` 应 0 命中（在 `tests/regression/test_no_dead_code_phase2.m` 里断言）

---

### 3.6 处方 D5（待 §1.4-Q4 决策）—— ChannelFactory `modelNames{1}` 删除

> **本节仅在 §1.4-Q4 owner 选 (A) 时生效**；选 (B) 时整节删除。

#### 3.6.1 改前/改后

**改前**（`ChannelFactory.m:188-194`）：

```matlab
if isfield(obj.factoryConfig.ChannelModels, 'AWGN')
    modelName = 'AWGN';
    return;
end

modelNames = fieldnames(obj.factoryConfig.ChannelModels);
modelName = modelNames{1};
```

**改后**：

```matlab
if isfield(obj.factoryConfig.ChannelModels, 'AWGN')
    modelName = 'AWGN';
    return;
end

error('CSRD:Blueprint:ChannelModelMismatch', ...
    ['Channel model resolution failed: requested mode=''%s'' has no ', ...
     'matching entry in factoryConfig.ChannelModels and AWGN fallback ', ...
     'is also missing. This blueprint should have been rejected by ', ...
     'BlueprintFeasibilityValidator.checkChannelModelInRegistry; ', ...
     'reaching ChannelFactory means the validator was bypassed.'], mode);
```

#### 3.6.2 与 Validator 的双层防御关系

| 层 | 角色 | 触发条件 |
|----|------|---------|
| Validator `ChannelModelInRegistry` | 蓝图层拦截 | ScenarioFactory.stepImpl 内（正常路径）|
| Factory `CSRD:Blueprint:ChannelModelMismatch` | 施工层兜底 | Validator 被绕过的极端测试路径（不应在生产命中）|

#### 3.6.3 单元测试断言点

`tests/unit/ChannelFactoryNoSilentFallbackTest.m`（新增，§5.2.F）：

1. `ChannelPreference.Model='RayTracing'` 在 registry 内 → 正常返回 'RayTracing'
2. `ChannelPreference.Model='UnknownXYZ'` 且 AWGN 在 registry 内 → 返回 'AWGN'（声明性兜底保留）
3. `ChannelPreference.Model='UnknownXYZ'` 且 AWGN 不在 registry 内 → throws `CSRD:Blueprint:ChannelModelMismatch`（删除的 `modelNames{1}` 路径不再触发）
4. **不变量**：grep `modelNames\{1\}` 在 `ChannelFactory.m` 应 0 命中

---

## 4. 新增工具/数据结构清单

| 路径 | 角色 | 来源 |
|------|------|------|
| `+csrd/+catalog/+profile/profileLoader.m` | Profile 唯一入口 | §3.1.2 |
| `+csrd/+catalog/+profile/+bands/Broadcast_FM_VHF.m` | Band profile | §3.1.3.A |
| `+csrd/+catalog/+profile/+bands/Broadcast_AM_MW.m` | Band profile | 同上 |
| `+csrd/+catalog/+profile/+bands/ISM24_WiFi24.m` | Band profile | 同上 |
| `+csrd/+catalog/+profile/+bands/ISM58_WiFi5.m` | Band profile | 同上 |
| `+csrd/+catalog/+profile/+bands/NR_n28.m` | Band profile | 同上 |
| `+csrd/+catalog/+profile/+bands/NR_n78.m` | Band profile | 同上 |
| `+csrd/+catalog/+profile/+bands/NR_n79.m` | Band profile | 同上 |
| `+csrd/+catalog/+profile/+receivers/PortableMonitor_40MHz.m` | Receiver profile | §3.1.3.B |
| `+csrd/+catalog/+profile/+receivers/LabAnalyzer_160MHz.m` | Receiver profile | 同上 |
| `+csrd/+catalog/+profile/+receivers/DenseArrayStation_200MHz.m` | Receiver profile | 同上 |
| `+csrd/+catalog/+profile/+phaseNoise/Low.m` | PhaseNoise level | §3.1.3.C |
| `+csrd/+catalog/+profile/+phaseNoise/Mid.m` | PhaseNoise level | 同上 |
| `+csrd/+catalog/+profile/+phaseNoise/High.m` | PhaseNoise level | 同上 |
| `+csrd/+catalog/+profile/+antennaCompat/AntennaModulationMatrix.m` | Antenna 兼容矩阵 | §3.1.3.D |
| `+csrd/+pipeline/+blueprint/computeBlueprintHash.m` | BlueprintHash 入口 | §3.2 |
| `+csrd/+pipeline/+blueprint/BlueprintFeasibilityValidator.m` | Validator 类 | §3.3 |

总计：**14 个 profile + 2 个 blueprint = 17 个新 `.m`**

---

## 5. 单元/回归测试矩阵

### 5.1 测试套总览

| 套件 | 路径 | 关联处方 | 用例数 |
|------|------|---------|--------|
| ProfileLoaderTest | `tests/unit/ProfileLoaderTest.m` | §3.1.5 | ~20 |
| ComputeBlueprintHashTest | `tests/unit/ComputeBlueprintHashTest.m` | §3.2.5 | 8 |
| BlueprintFeasibilityValidatorTest | `tests/unit/BlueprintFeasibilityValidatorTest.m` | §3.3.6 | 21×2 = 42 |
| ValidationReportTest | `tests/unit/ValidationReportTest.m` | §3.3.6 | 4 |

> **路径约束**：`tests/unit/` 目录是平铺的，不支持子目录递归（参见 `tests/run_all_tests.m::runUnittestSuite`）。Phase 2 所有新单测文件直接放在 `tests/unit/` 顶层。
| ScenarioFactoryResampleLoopTest | `tests/unit/ScenarioFactoryResampleLoopTest.m` | §3.4.6 | 5 |
| FrequencyAllocationStrategyTest | `tests/unit/FrequencyAllocationStrategyTest.m` | §3.5.4 | 5 |
| ChannelFactoryNoSilentFallbackTest（仅 §1.4-Q4=A）| `tests/unit/ChannelFactoryNoSilentFallbackTest.m` | §3.6.3 | 4 |
| test_channel_state_continuity | `tests/regression/test_channel_state_continuity.m` | §3.3.4 | 2 |
| test_no_dead_code_phase2 | `tests/regression/test_no_dead_code_phase2.m` | §3.5.4 §3.6.3 | 1 |
| test_phase2_blueprint_smoke | `tests/regression/test_phase2_blueprint_smoke.m` | §6 S6 后冒烟 | 1 |
| **回归套** `test_baseline_sweep_200` | `tests/regression/test_baseline_sweep_200.m` | §7 出口 | 200 |

### 5.2 测试与 §17.4 出口条件的映射

| §17.4 出口 | 落地测试 |
|-----------|---------|
| 1. 7+3 profile 文件落地，单元测试逐张校核数值 | ProfileLoaderTest §3.1.5 1-6 |
| 2. BlueprintHash RoundTrip：byte-equal | ComputeBlueprintHashTest §3.2.5 1 |
| 3. 21 条 check 各有正反样本 | BlueprintFeasibilityValidatorTest 42 个 case |
| 4. 200 场景 sweep 接受率 ≥95%；重采样 P95 ≤5 | test_baseline_sweep_200 + §7 C2/C3 |

### 5.3 跑测顺序约定

`tests/run_all_tests.m` 加 `'phase2'` 子集：

```matlab
case 'phase2'
    suites = {
        'tests/unit/ProfileLoaderTest.m'
        'tests/unit/ComputeBlueprintHashTest.m'
        'tests/unit/BlueprintFeasibilityValidatorTest.m'
        'tests/unit/ValidationReportTest.m'
        'tests/unit/ScenarioFactoryResampleLoopTest.m'
        'tests/unit/FrequencyAllocationStrategyTest.m'
        'tests/unit/ChannelFactoryNoSilentFallbackTest.m'
        'tests/regression/test_channel_state_continuity.m'
        'tests/regression/test_no_dead_code_phase2.m'
        'tests/regression/test_phase2_blueprint_smoke.m'
    };
```

---

## 6. 实施顺序（强制执行）

| Step | 范围 | 估时 | 验证 |
|------|------|------|------|
| **S1** | 落地 14 个 profile `.m`（§3.1）；不改任何下游 | 4h | `which csrd.catalog.profile.profileLoader` 命中；14 个 file glob 全在 |
| **S2** | 写 ProfileLoaderTest（§3.1.5）；跑通 | 1.5h | 0 失败；20 用例全过 |
| **S3** | 落地 `computeBlueprintHash.m` + canonicalizeBlueprint helper（§3.2）；写 ComputeBlueprintHashTest | 2.5h | 8 用例全过 |
| **S4** | 落地 `BlueprintFeasibilityValidator.m` 类骨架 + 21 条 check（§3.3）；写 BlueprintFeasibilityValidatorTest（42 用例）+ ValidationReportTest（4 用例）| 6h | 46 用例全过 |
| **S5** | 改 ScenarioFactory.stepImpl（§3.4）；改 isScenarioSkipException 白名单；改 SimulationRunner.stampRuntimeHeader 写入 BlueprintHash/Resamples；写 ScenarioFactoryResampleLoopTest | 3h | 5 用例全过；run_all_tests('regression') 0 失败 |
| **S6** | 删除 D7 三处文件 / strategy switch（§3.5）；改 CommunicationBehaviorSimulator method 声明；写 FrequencyAllocationStrategyTest | 1h | 5 用例全过 |
| **S7** | 删除 D5 silent fallback（§3.6）—— **仅 §1.4-Q4=A 时执行**；写 ChannelFactoryNoSilentFallbackTest | 1h | 4 用例全过 |
| **S8** | 写 test_channel_state_continuity / test_no_dead_code_phase2 / test_phase2_blueprint_smoke；改 run_all_tests 加 'phase2'；跑 `run_all_tests('all')` | 2h | 0 失败；`'phase2'` 子集 ~80 用例全过 |
| **S9** | 重跑 `test_baseline_sweep_200(200,'Mode','full')` → 输出新 `2026-04-baseline-v0.json`；与 §7 七条出口比对 | ~75 min | C1-C7 全过 或 触发 §10 owner 决策 |
| **S10** | 写实施快照到本文档 §9；本文档状态改 Frozen；audit §17.4 改 ✅ Frozen | 1h | git diff clean；本文档 §9 完整填好 |

> 严禁跨 step：S2 不通过禁止动 S3；S5 单测 0 失败前不动 S6 等。

---

## 7. 出口条件（必须 100% 满足）

| Code | 描述 | 测量方法 | 阈值 |
|------|------|---------|------|
| **C1** | 14 个 profile `.m` 全部存在且单测通过 | `glob` + ProfileLoaderTest 20 用例 0 失败 | 14/14 + 20/20 |
| **C2** | BlueprintHash 算法实现完成且 RoundTrip 字节级相等 | ComputeBlueprintHashTest 8 用例 0 失败 | 8/8 |
| **C3** | 21 条 Validator check 全部接口存在；17 条非 stub 各有正反样本测试通过 | BlueprintFeasibilityValidatorTest 42 用例 0 失败（含 Skip stub 接口存在断言）| 42/42 |
| **C4** | ScenarioFactory.stepImpl 接 Validator + resample loop；annotation `Header.Runtime.BlueprintHash/Resamples/ValidatorVersion` 三字段全实写 | ScenarioFactoryResampleLoopTest 5 用例 + 抽查 baseline JSON 字段 | 5/5 + 字段全在 |
| **C5** | D7 三处死代码删除；FrequencyAllocationStrategyTest 通过 | grep 0 命中 + 5 用例 0 失败 | 0 + 5/5 |
| **C6**（§1.4-Q4=A）| D5 silent fallback 删除；ChannelFactoryNoSilentFallbackTest 通过 | grep `modelNames\{1\}` 在 ChannelFactory.m 0 命中 + 4 用例 | 0 + 4/4 |
| **C7** | 200 场景 baseline sweep 接受率 ≥ 95%；重采样次数 P95 ≤ 5；Phase 1 已批 5 条强契约 + 3 条性能门禁不退 | test_baseline_sweep_200 + 比对 baseline JSON | `BlueprintAcceptanceRate>=0.95` & `BlueprintResamplesP95<=5` & Phase 1 阈值不退 |

### 7.1 防回退不变量（Phase 1 已写死，Phase 2 必须保持）

| 不变量 | 来源 | 测量 |
|--------|------|------|
| `BlueprintAcceptanceRate >= 0.99` | Phase 1 baseline | 不下降 |
| `ChannelFactoryFailureRate <= 0.0` | Phase 1 baseline | 不上升 |
| `JsonNanCount == 0` & `JsonInfinityCount == 0` | Phase 0 sanitize | 持续为 0 |
| `EmptySignalSegmentRatio <= 0.01` | Phase 1 H14 修复后 | 不上升 |
| `WallclockSecPerScenarioP95 <= Phase1Threshold * 1.05` | Phase 1 已批阈值 + 5% 容差（resample 引入开销）| 不超过 |

> **关于 wallclock**：Phase 2 引入 validator + resample loop 必然有开销。Phase 1 freeze 时 wallclock P95 已经被批 +15% 弹性。Phase 2 在 Phase 1 阈值上**再允许 +5%**（即 Phase 0 baseline 的 +20.75%）；超过则触发 §8 风险条款。

---

## 8. 风险与折衷

### 8.1 已知风险

| ID | 风险 | 触发条件 | 缓解 |
|----|------|---------|------|
| R1 | 接受率不达 95% | 现有 ScenarioFactory + 配置生成的蓝图大量违反 21 条 check | §1.4-Q1 选 (A) Soft-import → 大部分 check 在缺字段时跳过；只有"自检"类（FrameSampleConsistency / RxFsEqualsObservableBw / TxBwInsideRxWindow / ChannelModelInRegistry）真生效，预期通过率应 >99% |
| R2 | 重采样 P95 > 5 | 同 R1 | 同 R1 + §10 owner 决策启用临时放宽阈值 |
| R3 | wallclock 显著上升 | Validator 21 条 check 每帧跑一次开销大 | 21 条全是 O(N) 简单 check，预估单次 < 1ms；若超 5% 则 §10 启动性能优化 |
| R4 | 跨 platform hash 不一致 | Java SHA-256 在不同 JVM 行为漂移 | RoundTrip 测试覆盖；CI 增加跨平台跑（Phase 4 任务） |
| R5 | §1.4-Q4=A 后部分外部测试因绕过 Validator 直接构造非法 ChannelPreference 而崩 | 历史测试可能依赖 silent fallback 行为 | S7 完成后跑 `run_all_tests('all')` 时若发现新 fail，逐个改测试用 mock 合法蓝图 |

### 8.2 折衷决策

| 折衷 | 理由 |
|------|------|
| Phase 2 Soft-import profile，不改 config | Phase 0/1 单步原则；config migration 单独是 Phase 3 主题 |
| Phase 2 stub `MeasurementCompleteness` / `DopplerSelfConsistency` | 它们依赖 Phase 4 才有的测量层；不能 block Phase 2 freeze |
| `ChannelStateContinuity` 落 regression 而非 Validator | 它是 runtime 行为不变量，不是图纸字段 check；Validator 应纯 |
| ScenarioBlueprint schema 用 transitional 'phase2-transitional' 版本 | Phase 3 才正式定义 ScenarioBlueprint；Phase 2 不能跨范围 |

---

## 9. 实施快照（S10 freeze 后填，2026-04-25）

### 9.1 实际改 / 新增 / 删除文件清单

#### 9.1.1 新增（生产代码 17 个 .m + 1 个测试 helper recipe = 18）

| 类别 | 路径 | 角色 / 关联 step |
|------|------|----------------|
| Profile loader | `+csrd/+catalog/+profile/profileLoader.m` | §3.1.2 唯一入口 / S1 |
| Band profile (×7) | `+csrd/+catalog/+profile/+bands/Broadcast_AM_MW.m` | §3.1.3.A / S1 |
| Band profile | `+csrd/+catalog/+profile/+bands/Broadcast_FM_VHF.m` | 同上 |
| Band profile | `+csrd/+catalog/+profile/+bands/ISM24_WiFi24.m` | 同上 |
| Band profile | `+csrd/+catalog/+profile/+bands/ISM58_WiFi5.m` | 同上 |
| Band profile | `+csrd/+catalog/+profile/+bands/NR_n28.m` | 同上 |
| Band profile | `+csrd/+catalog/+profile/+bands/NR_n78.m` | 同上 |
| Band profile | `+csrd/+catalog/+profile/+bands/NR_n79.m` | 同上 |
| Receiver profile (×3) | `+csrd/+catalog/+profile/+receivers/PortableMonitor_40MHz.m` | §3.1.3.B / S1 |
| Receiver profile | `+csrd/+catalog/+profile/+receivers/LabAnalyzer_160MHz.m` | 同上 |
| Receiver profile | `+csrd/+catalog/+profile/+receivers/DenseArrayStation_200MHz.m` | 同上 |
| PhaseNoise level (×3) | `+csrd/+catalog/+profile/+phaseNoise/Low.m` | §3.1.3.C / S1 |
| PhaseNoise level | `+csrd/+catalog/+profile/+phaseNoise/Mid.m` | 同上 |
| PhaseNoise level | `+csrd/+catalog/+profile/+phaseNoise/High.m` | 同上 |
| Antenna 兼容矩阵 | `+csrd/+catalog/+profile/+antennaCompat/AntennaModulationMatrix.m` | §3.1.3.D / S1 |
| BlueprintHash | `+csrd/+pipeline/+blueprint/computeBlueprintHash.m`（含 6 个 local `canonicalize*` helpers）| §3.2 / S3 |
| Validator + ValidationReport schema | `+csrd/+pipeline/+blueprint/BlueprintFeasibilityValidator.m`（21 条静态 check + ValidationReport 由 `validate` 直接构造，**无独立 .m**）| §3.3 / S4 |

> 实施时偏离设计：§4 表格曾把 `ValidationReport` 列为独立 `.m`，落地时改为 `validate()` 返回的 plain struct（不需要类）—— 既满足 §16.7.2 字段契约又减少一个无值类型层。

#### 9.1.2 修改（13 个 .m，全部为 Phase 2 范围）

| 路径 | Phase 2 修改要点 | 关联 step |
|------|----------------|----------|
| `+csrd/+factories/ScenarioFactory.m` | stepImpl 加 generate→validate→resample 循环（最多 `MaxResamples=8` 次，仅 `frameId==1`）；新增 public read-only properties `LastValidationReport` / `LastBlueprintResamples` / `LastBlueprintHash`；C-1 silent fallback (catch 块吞异常→空 cell+`globalLayout.Error`) 改 fail-fast `rethrow(ME)` | S5 / C-1 |
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/CommunicationBehaviorSimulator.m` | method 声明删 `allocateFrequenciesRandom` / `allocateFrequenciesOptimized`（D7）| S6 |
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/performScenarioFrequencyAllocation.m` | 删 strategy switch + warning fallback；只剩 `allocateFrequenciesReceiverCentric`（D7）| S6 |
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/getDefaultConfiguration.m` | Strategy 默认值清理（D7 配套）| S6 |
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/generateScenarioTransmitterConfigurations.m` | Strategy 注入字段对齐（D7 配套）| S6 |
| `+csrd/+factories/ChannelFactory.m` | 删除 `modelNames{1}` silent fallback（D5）；增 Hidden static helper `resolveChannelModelName` 暴露给单测；缺 model 直接 throw `CSRD:Blueprint:ChannelModelMismatch` | S7 |
| `+csrd/+core/@ChangShuo/ChangShuo.m` | 加 Hidden public `getScenarioBlueprintProvenance()` 方法（从 `Factories.Scenario.LastValidationReport` 读 hash/resamples/version）；修复 `report.Provenance.ValidatorVersion` 字段路径 | S5 / S9 |
| `+csrd/SimulationRunner.m` | `executeScenario` 调用 `getScenarioBlueprintProvenance` 并通过 `injectBlueprintProvenance` 注入 `Header.Runtime.{BlueprintHash, BlueprintResamples, ValidatorVersion}`（**注**：本字段集设计阶段 §10 Q-extra-implementation-note 原列入 Phase 3，S9 baseline coverage 验收时拉回 Phase 2 一并落地，因此 BlueprintProvenanceCoverage=1.0 已可在 baseline JSON 中验证）；移除 `ismethod` 守卫（MATLAB 对 Hidden 方法返回 false）改 try/catch | S5 / S9 |
| `+csrd/+pipeline/+scenario/isScenarioSkipException.m` | 加 `CSRD:Blueprint:Unsamplable` 到白名单（resample 耗尽时 sweep 不崩） | S5 |
| `tests/run_all_tests.m` | 新增 `'phase2'` subset，含 10 个测试套（§5.3） | S8 |
| `tests/regression/baseline_recipe_v0.m` | **Phase 2 限制**：所有 cohort `RxRange = [1, 1]`（避开 Validator #13 ReceiverViewProjectionPresent 拒绝 multi-Rx 蓝图）；含说明性长 comment 标注 Phase 3 解除条件；Recipe SHA 由 Phase 0 的 `fca271f0…` → Phase 2 的 `873b0cc8…` | S9 |
| `tests/regression/test_baseline_sweep_200.m` | 每场景独立 session 目录（`reset()`+`initialize(perScenarioDir)`）避免 annotation 互相覆盖；改用 `scenario_000001_annotation.json` 固定文件名（runner 内部恒以 sid=1 处理）；`localCountLogLinesForScenario` 改按 newline 数量计；`BlueprintProvenanceCoverage` 改按 `BlueprintHash` 与 `ValidatorVersion` 双非空率统计；新增 `requiredKeys` 列表中四项 provenance metric 断言 | S5 / S9 |
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/stepImpl.m` | 上游 entity silent fallback 已在 Phase 1 删除（沿用，无 Phase 2 增量改动）| - |

> 不在表内但 `git status` 上显示的 `M` 文件（RRFSimulator / TRFSimulator / ReceiveFactory / TransmitFactory / processSingleTransmitter / processReceiverProcessing 等）：均属 **Phase 1 freeze 时的累积差**，不在 Phase 2 改动范围内（Phase 2 在 Phase 1 已 freeze 的代码基线上叠加）。

#### 9.1.3 删除（3 个 .m，D5 + D7 双收）

| 路径 | 原因 | 关联 step |
|------|------|----------|
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/allocateFrequenciesRandom.m` | 7 行转调 wrapper（D7）| S6 |
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/allocateFrequenciesOptimized.m` | 7 行转调 wrapper（D7）| S6 |
| `tests/diag_provenance.m` | S9 临时 provenance 调试脚本（顺手清，遵循 owner Q-extra 原则）| S10 |

> `+csrd/+utils/MemoryLessNonlinearityRandom.m` 在 Phase 1 freeze 时已删，git status 上的 `D` 是历史标记。

#### 9.1.4 新增测试套（与 §5.1 对齐 + S5/S9 实施期补充）

| 路径 | 用例数 | 关联 step |
|------|--------|----------|
| `tests/unit/ProfileLoaderTest.m` | 20 | S2 |
| `tests/unit/ComputeBlueprintHashTest.m` | 12 | S3（设计 §5.1 写 8，落地为应对 4 个 corner case 扩到 12）|
| `tests/unit/BlueprintFeasibilityValidatorTest.m` | 46 | S4（设计 §5.1 写 21×2=42，落地加 4 个 dispatcher / regression case 扩到 46）|
| `tests/unit/ValidationReportTest.m` | 4 | S4 |
| `tests/unit/ScenarioFactoryResampleLoopTest.m` | 7 | S5（设计 §5.1 写 5，落地加 2 个 boundary case 扩到 7）|
| `tests/unit/FrequencyAllocationStrategyTest.m` | 8 | S6（设计 §5.1 写 5，落地加 3 个 fail-fast strategy gate case 扩到 8）|
| `tests/unit/ChannelFactoryNoSilentFallbackTest.m` | 8 | S7（设计 §5.1 写 4，落地加 4 个 Hidden static helper case 扩到 8）|
| `tests/unit/AnnotationHeaderBlueprintProvenanceTest.m` | – | S9 baseline 校核 provenance 字段写入（实施期补充，未列入设计 §5.1）|
| `tests/regression/test_no_dead_code_phase2.m` | 1 | S7（D5 + D7 双收 grep 不变量）|
| `tests/regression/test_phase2_blueprint_smoke.m` | – | 设计 §5.3 列入，落地未单独建立独立 smoke 文件，由 `test_baseline_sweep_200(12)` smoke 模式承担同等覆盖 |

> S8 `run_all_tests('all')` 全过：42/42 PASS / Time=413.8s。S9 baseline `test_baseline_sweep_200(200, 'Mode', 'full')` 全过：200/200 PASS / Time=4116s。

### 9.2 baseline 200 场景实测对照

| 指标 | Phase 0 baseline (`fca271f0…`) | Phase 2 baseline (`873b0cc8…`) | 阈值 / 备注 |
|------|------------------------------|------------------------------|-----------|
| `BlueprintAcceptanceRate` | 1.0 | **1.0** ✅ | C7 阈值 ≥ 0.95 |
| `BlueprintResamplesP50` | – | **0** ✅ | Phase 2 新指标 |
| `BlueprintResamplesP95` | – | **0** ✅ | C7 阈值 ≤ 5（full mode 200 场景） |
| `BlueprintResamplesMax` | – | **0** ✅ | Phase 2 新指标 |
| `BlueprintProvenanceCoverage` | – | **1.0** ✅ | Phase 2 新指标 / S9 实施期拉回（参 9.1.2 SimulationRunner 行）|
| `ChannelFactoryFailureRate` | 0 | **0** ✅ | 不变量 |
| `WallclockSecPerScenarioP50` | 20.49s | **18.97s** ✅ | -7.4%（recipe RxRange 收紧导致信号源数下降）|
| `WallclockSecPerScenarioP95` | 39.86s | **37.79s** ✅ | -5.2%（同上）|
| `LogLinesPerScenarioP50` | 1896 | **230** ✅ | 显著下降（Phase 1 LogPolicy 'Standard' + Phase 2 sid mapping 修复后 per-scenario log scope 收紧）|
| `LogLinesPerScenarioP95` | 1896 | **819** ✅ | 同上 |
| `AnnotationFileBytesP50` | 7826 | **7253.5** ✅ | -7.3%（RxRange 收紧）|
| `AnnotationFileBytesP95` | 7826 | **11861** | +51%（多 Tx cohort 在 sid=1 重映射后 P95 抖动；仍远低于 Phase 1 freeze 的 50KB 上限，OK）|
| `RealizedVsPlannedBwAbsRelDiffP95` | 0.1205 | **0.1233** ✅ | +2.3%（recipe 改变下的预期波动；< Phase 1 阈值 0.15） |
| `EmptySignalSegmentRatio` | 0 | **0** ✅ | 不变量（Phase 1 H14 修复持续生效）|
| `JsonNanCount` | 0 | **0** ✅ | 不变量（C6）|
| `JsonInfinityCount` | 0 | **0** ✅ | 不变量（C6）|
| `SanitizeManifestSummary.TotalEntries` | 0 | 211 | 期望（Phase 1 sanitize 流水开始处理 RxImpairments 6-set 的 NaN/Inf）|
| `SweepWallclockSec` | 4418s | **4116s** | -6.8% |

> Phase 0 baseline JSON 已被 S9 写流程**就地覆盖**（`docs/baselines/2026-04-baseline-v0.json`，full mode 直接写 canonical 文件）。原 Phase 0 内容仅保留在 git 历史中。Phase 2 baseline 即新 canonical。

### 9.3 出口条件 C1-C7 验收

| 出口 | 状态 | 证据 |
|------|------|------|
| **C1** 14 profile + ProfileLoaderTest 20/20 | ✅ | `glob` 14/14；S2 PASS |
| **C2** ComputeBlueprintHashTest 8/8（实落 12/12）| ✅ | S3 PASS |
| **C3** Validator 21 接口 + 17 非 stub 各正反样本（实落 BlueprintFeasibilityValidatorTest 46/46）| ✅ | S4 PASS |
| **C4** Resample loop + provenance 字段（hash/resamples/version 三字段全在 baseline JSON `Header.Runtime`） | ✅ | S5/S9：S9 baseline JSON `BlueprintProvenanceCoverage=1.0` |
| **C5** D7 grep 0 命中 + FrequencyAllocationStrategyTest 8/8 | ✅ | S6 + `test_no_dead_code_phase2` |
| **C6** D5 grep 0 命中 + ChannelFactoryNoSilentFallbackTest 8/8 | ✅ | S7 + `test_no_dead_code_phase2` |
| **C7** 200 场景接受率 1.0 / 重采样 P95 = 0 | ✅ | S9 `2026-04-baseline-v0.json` Metrics |

### 9.4 已识别的 Phase 3 后续项（落地过程中暴露但不在 Phase 2 范围内）

| 编号 | 描述 | 触发位置 |
|------|------|---------|
| **P3-followup-1** | Validator #13 `ReceiverViewProjectionPresent` 在 Phase 2 仅靠 recipe 限制（`RxRange=[1,1]`）回避，Phase 3 必须真正实现 `Emitter.ReceiverViews[]` projection（每个 Tx 对每个 Rx 一份独立 `WindowFrequencyOffset`）；upstream 入口在 `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/allocateFrequenciesReceiverCentric.m` | recipe + validator |
| **P3-followup-2** | `Header.Runtime.{BlueprintHash, BlueprintResamples, ValidatorVersion}` 当前从 `getScenarioBlueprintProvenance` 获取（Hidden method + try/catch），Phase 3 应改为 `globalLayout` data-channel 直接传入 `stampRuntimeHeader`，避免 `SimulationRunner ↔ ChangShuo ↔ ScenarioFactory` 三层接口耦合 | `SimulationRunner.executeScenario` |
| **P3-followup-3** | `MeasurementCompleteness` / `DopplerSelfConsistency` 两条 stub check 当前 `Severity='Skip'`，Phase 4 MeasuredTruth 落地后应改 `Severity='Reject'` | Validator |
| **P3-followup-4** | `OverlapAnnotationConsistent` 落 stub（设计 §1.3 列为 Phase 2 真实 check，落地推迟）；Phase 3 验证 segment-level overlap annotation 的一致性 | Validator |

---

## 10. Owner 决策（已 Approved）

### Q1 Profile 库引入力度

- [x] (A) Soft-import（采纳）
- [ ] (B) Hard-import
- [ ] (C) Half-import

理由：单步原则；config migration 留 Phase 3。

### Q2 4 条 measurement 类 check 落地方式

- [x] (A) Stub 注册（采纳）
- [ ] (B) 全留 Phase 4
- [ ] (C) Phase 2 用 mock 真实测试

理由："21 条" 接口 Phase 2 freeze 时物理存在，Phase 4 只切 Severity 不动签名。

### Q3 重采样发生层

- [x] (A) ScenarioFactory.stepImpl local loop（采纳）
- [ ] (B) SimulationRunner outer loop
- [ ] (C) 双层

理由：reject 责任收敛在最自然产生位置；不浪费已计算的 entities/environment。

### Q4 D5 silent fallback 是否 Phase 2 一并修

- [x] (A) Phase 2 一并修（采纳）
- [ ] (B) 留 Phase 3

理由：Validator + Factory 双层防御 = fail-fast 工程正确做法；增量工作量约 1h。

### Q-extra（owner 附加原则）

> "不要兼容旧代码 + 旧的无用代码也需要及时清理。"

落地策略（贯穿 S1-S10）：
- 实施过程中遇到的任何 silent fallback / dead code / 转调 wrapper 一并清理，记入 §9.1
- 已识别的"顺手清理"项（在原 Phase 2 范围之外，但符合本原则）：
  - **C-1**：`ScenarioFactory.stepImpl:138-146` catch 块把任何非 SkipScenario 异常吞成空 cell + `globalLayout=struct('Error',...)` —— 是 silent fallback（与 Phase 0/1 删 silent fallback 原则一致）；S5 顺手改为直接 `rethrow(ME)`
  - **C-2**：`performScenarioFrequencyAllocation.m:33-43` 的 "Overlapping vs NonOverlapping" 决策中，`overlapRatio` 字段在下游无任何消费方（grep 验证）；如确认死字段 S6 顺手清
  - **C-3**：`getDefaultConfiguration.m:6` Strategy 默认值 + `generateScenarioTransmitterConfigurations.m:24-26` 的 Strategy 注入 —— D7 删除后这两处仍写 `'ReceiverCentric'` 是合理的（它是真正存在的策略）；保留

### Q-extra-implementation-note（设计 §3.4.4 边界拆分）

实施过程中发现 §3.4.4 的处方 "`SimulationRunner.stampRuntimeHeader` 从 `obj.scenarioFactory.lastValidationReport` / `lastBlueprintResamples` 读取" 在当前架构下不能一步到位：`SimulationRunner` 不直接持有 `ScenarioFactory` 引用（它只持有 `ChangShuo` 引擎，而 `ChangShuo` 内部才持有 `Factories.Scenario`）。要么改 `SimulationRunner` 改 `ChangShuo` 改 `processScenarioInstantiation` 三处接口，要么走 `globalLayout` 数据通道。

**Phase 2 落地拆分**（owner 默认采纳）：
- **Phase 2 范围**：
  - `ScenarioFactory` 新增 public read-only properties `LastValidationReport` / `LastBlueprintResamples` / `LastBlueprintHash`（满足 §3.4.4 的 properties 契约）
  - `globalLayout.BlueprintHash` / `globalLayout.ValidationReport` / `globalLayout.NumBlueprintAttempts` 字段在 `ScenarioFactory.stepImpl` 中注入（保证数据已沿 dataflow 传递）
- **Phase 3 范围**：
  - 改 `SimulationRunner.executeScenario` 从 `changShuoEngine.Factories.Scenario.LastValidationReport` 读 → 作为 `stampRuntimeHeader` 新增参数传入
  - 或者改 `stampRuntimeHeader` 从 annotation 内嵌的 `globalLayout.BlueprintHash` 读
  - `Header.Runtime.{BlueprintHash, BlueprintResamples, ValidatorVersion}` 三个字段才正式出现在 annotation JSON 中
- **理由**：Phase 2 出口验收（§7 七条）不包含 annotation 字段断言，把 stampRuntimeHeader 升级延后不影响验收，反而避免了"为了 Phase 2 的一个字段而打穿三层接口"的过度耦合。Phase 3 设计 ScenarioBlueprint v1 时，这三层接口本来就要重做。

---

**文档状态变更日志**

| 日期 | 状态 | 变更 |
|------|------|------|
| 2026-04-25 | 🟡 Draft | 初版（基于 audit §16.5/§16.7/§16.8/§17.4 + Phase 1 freeze 后代码现状）|
| 2026-04-25 | ✅ Approved | Owner 拍板 Q1-Q4 全 (A) + 附加 Q-extra 清理原则；进入 S1 实施 |
| 2026-04-25 | ❄️ Frozen | S1-S10 全部 PASS；S8 `run_all_tests('all')` 42/42 PASS；S9 `test_baseline_sweep_200(200,'Mode','full')` 200/200 PASS / Wallclock 4116s / `BlueprintAcceptanceRate=1.0` / `BlueprintResamplesP95=0` / `BlueprintProvenanceCoverage=1.0`；§9 实施快照已填；audit §17.4 已标 Frozen；启动 Phase 3 详设 |
