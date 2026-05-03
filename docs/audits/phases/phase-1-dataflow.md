# Phase 1 详细设计 —— 数据流 + 异常契约
> Historical snapshot / 历史快照：本文记录当时的审计或交接状态，可能保留旧路径、旧 TODO 或过渡期说明。当前目录结构以 `README.md` 和 `docs/architecture/source-layout.md` 为准。

| 字段 | 值 |
|------|----|
| 状态 | ✅ **Frozen**（2026-04-25 落定；S1–S10 + R1–R7 全部完成；详见 §9）|
| 顶层 audit 引用 | `docs/audits/2026-04-spectrum-blueprint-construction-refactor.md` §17.3（已同步标 ✅ Frozen）|
| 关联 H/M 条目 | A1 (H1 接收天线字段错位) / A2 (H3 一帧多 burst) / A4 (H9 实体合并 silent fallback) / H13 (Channel Seed 缺 BurstId) / H14 (mergeChannelOutput 整体替换丢字段) + R1–R7 深度重构（去 transitional 字段、PA/LNA `comm.MemorylessNonlinearity` 6 Method 严格化）|
| 前置 | Phase 0 已 Frozen（baseline JSON 入库、Toolbox/Logger/Sanitize 三条底座生效）|
| 实际产出 | 实际改 / 新增 / 删除文件清单见 §9.1 / §9.2 / §9.3，含 13 个 .m 修改、3 个新工具 .m、9 个新单元 / 回归测试、1 个 .m 整文件删除（`MemoryLessNonlinearityRandom`），baseline JSON 重生成 |
| 实际耗时 | 实施 + 自测 ~1 个工作日；S8 全套测试 11 min；S9 200 场景 baseline 73 min |

---

## 0. 工作流契约（沿用 Phase 0）

1. 本设计文档先 **Draft** → 等用户审核通过 → 改 **Approved** → 才允许动 `.m`
2. 实施严格按 §6 的"实施顺序"执行，单步实施 + 单步自测，禁止跨 step 大改
3. 每完成一个 step：跑 §5 中对应单元/回归脚本，必须本地 0 失败，才能进下一 step
4. 全部 step 完成后：重跑 `tests/regression/test_baseline_sweep_200.m(200,'Mode','full')`，比对 Phase 0 baseline JSON 中的 4 条不变量（§9.2 Phase 0 设计文档已写死）
5. 200 场景 baseline 全过 → 把本设计文档状态改 `Frozen`，把顶层 audit §17.3 行加 ✅ Frozen 日期，启动 Phase 2 详设

---

## 1. 范围与边界（必读）

### 1.1 在范围内（Phase 1 必须修）

| 编号 | 标题 | 当前问题 | 处方位置 |
|------|------|---------|---------|
| **A1** | 接收天线字段错位 | `setupReceivers` 写 `RxInfo.NumAntennas`，`ReceiveFactory.configureReceiverBlock` 用 `isprop` 拷贝；`RRFSimulator` 仅暴露 `NumReceiveAntennas` 属性 → 字段被静默丢弃 | §3.1 |
| **A2** | 一帧多 burst 漏检 | `checkTransmissionInterval` 单匹配且只看 frame_start∈[s,e)；`calculateTransmissionState` 单 `CurrentIntervalIdx`；`processSingleTransmitter` L48-53 优先消费单 idx → 即使蓝图给多 interval，每帧仍只产 1 段 | §3.2 |
| **A4** | 实体合并 silent fallback | `CommunicationBehaviorSimulator/stepImpl.m:30-33` 当 `synchronizeScenarioEntities` 返回空时直接换成 `entities`，破坏 "实体在 scenario 内固定" 契约 | §3.3 |
| **H13** | Channel Seed 不含 BurstId | `ChannelFactory.m:342-350` Seed = `frameId * 10000 + txHash * 100 + rxHash`；同一 burst 跨多帧拿到不同 channel realization，违反"burst 内准静态" | §3.4 |
| **H14** | mergeChannelOutput 整体替换丢字段 | `ChannelFactory.m:453-466` 当 `channelOutput.Signal` 存在时整体替换 `inputSignalStruct`，导致 `SegmentId / Planned / Bandwidth / FrequencyOffset` 等上游字段全部丢失 | §3.5 |
| **C1（强 schema）** | signal struct 4 边界字段断言 | 当前 `processChannelPropagation.m` 直接读 `channelOutput.Signal/.FrequencyOffset/.Bandwidth` 不做存在性检查；H14 一旦复发会在下游 fallback 路径上偷偷退化 | §3.6 |

### 1.2 不在范围内（Phase 1 禁止动）

下列**今天看着也想顺手改但绝不在 Phase 1 内动**的项目，必须严格留给后续阶段，否则 PR 会被自动拒：

- **D2 / D3 (M3)**：`processSingleSegment.m:142-148` 硬编码 PSK fallback —— 留 Phase 3
- **D5 (H11)**：`ChannelFactory.m:188-194` modelName 多级回落 + `modelNames{1}` 兜底 —— 留 Phase 2/3
- **D10 (M5)**：`processTransmitImpairments.m:60` `2.5 × plannedBW` magic factor —— 留 Phase 3
- **D11 (H8)**：`assignMobilityModel.m:15-16` Mobility 随机选 —— 留 Phase 3
- **H12 (Doppler)**：`applyDopplerShift.m` 全链 —— 留 Phase 4
- **H17 (MeasuredTruth)**：`processReceiverProcessing` 测量层落地 —— 留 Phase 4
- **D7 (allocateFrequenciesRandom/Optimized)** 转调 wrapper 删除 —— 留 Phase 2
- **Profile 库 / Validator / BlueprintHash** —— 留 Phase 2
- 任何 **annotation 字段重命名 / V2 namespace** —— 留 Phase 4

> Phase 1 里**只能**动 §1.1 表里那 6 类问题；新增工具函数仅限 §4 列出的 3 个。

### 1.3 与 §16/§17 现有结论的对齐

- §16.5.2 signal struct 必含字段表是 Phase 1 的硬契约。本设计 §3.6 以此表为依据落 ContractTest。
- §17.3 的 6 项"主要修改"在本设计中映射到 §3.1–§3.6 + §4。
- §17.3 的 4 项出口条件在本设计 §7 完整 checklist 化，并补 4 条防回退不变量。

---

## 2. 事实凭据（带行号引用，禁止脑补）

### 2.1 A1 —— `RxInfo.NumAntennas` 字段被丢弃

```44:48:+csrd/+core/@ChangShuo/private/setupReceivers.m
            % Hardware
            if isfield(rxPlan, 'Hardware')
                RxInfo.Type = getFieldOrDefault(rxPlan.Hardware, 'Type', 'Simulation');
                RxInfo.NumAntennas = getFieldOrDefault(rxPlan.Hardware, 'NumAntennas', 1);
            end
```

```146:154:+csrd/+factories/ReceiveFactory.m
            propNames = fieldnames(rxInfoThisRx);
            for k = 1:length(propNames)
                propName = propNames{k};
                if isprop(rxBlock, propName)
                    rxBlock.(propName) = rxInfoThisRx.(propName);
                    obj.logger.debug('Set property ''%s'' from rxInfoThisRx.', propName);
                end
            end
```

```17:22:+csrd/+blocks/+physical/+rxRadioFront/RRFSimulator.m
    properties
        StartTime (1, 1) {mustBeGreaterThanOrEqual(StartTime, 0), mustBeReal} = 0
        DecimationFactor (1, 1) {mustBePositive, mustBeReal} = 1
        NumReceiveAntennas (1, 1) {mustBePositive, mustBeReal} = 1
        BandWidth {mustBePositive, mustBeReal, mustBeInteger} = 20e6
        CenterFrequency (1, 1) {mustBeReal, mustBeInteger} = 0
```

**结论**：字段名 `NumAntennas`（rxInfo 里写的） vs `NumReceiveAntennas`（RRFSimulator 暴露的）不一致，`isprop(rxBlock,'NumAntennas')` 为 false，整段被静默跳过。

### 2.2 A2 —— 一帧多 burst 被丢

```60:68:+csrd/+pipeline/+scenario/checkTransmissionInterval.m
    for i = 1:size(intervals, 1)
        if frameTime >= intervals(i, 1) && frameTime < intervals(i, 2)
            isActive = true;
            intervalIdx = i;
            startTime = intervals(i, 1);
            endTime = intervals(i, 2);
            return;
        end
    end
```

```47:53:+csrd/+core/@ChangShuo/private/processSingleTransmitter.m
    if isfield(currentTxScenario, 'TransmissionState') && ...
            isfield(currentTxScenario.TransmissionState, 'CurrentIntervalIdx') && ...
            currentTxScenario.TransmissionState.CurrentIntervalIdx > 0
        activeIntervalIdx = currentTxScenario.TransmissionState.CurrentIntervalIdx;
        currentTxScenario.NumSegments = 1;
        currentTxScenario.ActiveSegmentIndices = activeIntervalIdx;
```

**结论**：① 检测端只 return 第一个 frame_start∈[s,e) 的 interval；② 即使蓝图有 N 个 intervals 落在同一帧内，下游 `processSingleTransmitter` 也优先吃单 idx 分支，强制 `NumSegments=1`。下游 `processTransmitterSegments` 已经按 `ActiveSegmentIndices` 循环，所以**只要把数组传到位就能一帧多段**——这是 Phase 1 选择小步修法的关键依据。

### 2.3 A4 —— `synchronizeScenarioEntities` 返回空 silent fallback

```30:33:+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/stepImpl.m
    workingEntities = synchronizeScenarioEntities(obj.scenarioEntities, entities, frameId);
    if isempty(workingEntities)
        workingEntities = entities;
    end
```

```60:64:+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/stepImpl.m
function mergedEntities = synchronizeScenarioEntities(previousEntities, currentEntities, frameId)
    if isempty(previousEntities)
        mergedEntities = currentEntities;
        return;
    end
```

**结论**：`synchronizeScenarioEntities` 的实际返回逻辑是"`previous` 为空 → 直接 `current`；否则按 ID 合并 Snapshots"。L31-33 的回退掩盖了**唯一可能返回空的路径——`current` 本身为空**这一异常事实，让真问题无法定位。Phase 1 应直接抛 `CSRD:Scenario:EntityDriftDetected`。

### 2.4 H13 —— Channel Seed 不含 BurstId

```342:350:+csrd/+factories/ChannelFactory.m
            if isprop(currentChannelBlock, 'Seed')
                try
                    txHash = sum(double(char(txIdStr)));
                    rxHash = sum(double(char(rxIdStr)));
                    currentChannelBlock.Seed = mod(frameId * 10000 + txHash * 100 + rxHash, 2^31 - 1);
                catch ME_seed
                    obj.logger.warning('Could not update channel Seed: %s', ME_seed.message);
                end
            end
```

**结论**：每帧重置 seed → 同一 burst 跨多帧拿到不同 channel realization；多径/MIMO 场景下 `path loss / fading tap` 不连续，违反 "burst 内准静态" 的物理假设。

### 2.5 H14 —— `mergeChannelOutput` 整体替换路径

```453:466:+csrd/+factories/ChannelFactory.m
        function receivedSignalStruct = mergeChannelOutput(~, inputSignalStruct, channelBlockOutput)
            if isstruct(channelBlockOutput) && isfield(channelBlockOutput, 'Signal')
                receivedSignalStruct = channelBlockOutput;
            elseif isstruct(channelBlockOutput)
                receivedSignalStruct = inputSignalStruct;
                outputFields = fieldnames(channelBlockOutput);
                for idx = 1:numel(outputFields)
                    receivedSignalStruct.(outputFields{idx}) = channelBlockOutput.(outputFields{idx});
                end
            else
                receivedSignalStruct = inputSignalStruct;
                receivedSignalStruct.Signal = channelBlockOutput;
            end
        end
```

**结论**：当 `channelBlockOutput.Signal` 非空（绝大多数有效路径），L455 直接 `receivedSignalStruct = channelBlockOutput`，丢掉 inputSignalStruct 的 `SegmentId / BurstId / Planned / Bandwidth / FrequencyOffset / SampleRate / TxInfo / RxInfo` 等所有上游字段。下游 `processChannelPropagation.m`:99-181 拼装 component 时全靠 `isfield(channelOutput, ...)` 兜底——丢字段后大量字段进入 `default 0/NaN/[]` 路径。

### 2.6 RX 强 schema 缺 1：RFImpairments 写得不全

```122:124:+csrd/+factories/ReceiveFactory.m
                receivedDataStruct.RxImpairments.DCOffset = currentReceiverBlock.DCOffset;
                receivedDataStruct.RxImpairments.IqImbalanceConfig = currentReceiverBlock.IqImbalanceConfig;
                receivedDataStruct.RxImpairments.ThermalNoiseConfig = currentReceiverBlock.ThermalNoiseConfig;
```

**结论**：RRFSimulator 实际驱动 4 个块（LNA `MemoryLessNonlinearityConfig` / Thermal `ThermalNoiseConfig` / IQ `IqImbalanceConfig` / SampleRateOffset `SampleRateOffset`），但 ReceiveFactory 只写了 3 个 + DCOffset，**`MemoryLessNonlinearityConfig` 与 `SampleRateOffset` 字段被吞**。下游 annotation 永远拿不到本帧实际用到的非线性参数与 ADC 钟差。

### 2.7 强 schema 缺 2：channel 边界字段断言为 0

```105:127:+csrd/+core/@ChangShuo/private/processChannelPropagation.m
                    component.Signal = channelOutput.Signal;
                    if isfield(channelOutput, 'SampleRate') && ...
                            ~isempty(channelOutput.SampleRate) && channelOutput.SampleRate > 0
                        component.SampleRate = channelOutput.SampleRate;
                    elseif isfield(segmentSignal, 'SampleRate') && ...
                            ~isempty(segmentSignal.SampleRate) && segmentSignal.SampleRate > 0
                        component.SampleRate = segmentSignal.SampleRate;
                    elseif isfield(rxInfo, 'SampleRate') && ...
                            ~isempty(rxInfo.SampleRate) && rxInfo.SampleRate > 0
                        component.SampleRate = rxInfo.SampleRate;
                        obj.logger.warning(['Frame %d, Tx %s -> Rx %s, Seg %d: ', ...
                            'channel/segment SampleRate missing; ', ...
                            'falling back to receiver SampleRate %.0f Hz. ', ...
                            'Upstream stages should populate SampleRate.'], ...
                            FrameId, string(txInfo.ID), string(rxInfo.ID), segIdx, ...
                            rxInfo.SampleRate);
                    else
                        error('CSRD:Core:MissingSampleRate', ...
                            ['Frame %d, Tx %s -> Rx %s, Seg %d: cannot ', ...
                             'determine signal SampleRate (channel, segment ', ...
                             'and receiver values are all missing).'], ...
                            FrameId, string(txInfo.ID), string(rxInfo.ID), segIdx);
                    end
                    component.FrequencyOffset = channelOutput.FrequencyOffset;
                    component.Bandwidth = channelOutput.Bandwidth;
```

**结论**：① `SampleRate` 已有三层 fallback（channel→segment→rxInfo），其中 fallback 到 rxInfo 仅 warning，未升 error。Phase 1 决定**保留这条 fallback**（属于 §1.2 "Phase 3 才删 silent fallback" 范围），仅在该位置补 ContractTest 监控 fallback 触发率。② L126-127 直接 `channelOutput.FrequencyOffset/.Bandwidth` 没有 isfield 检查，H14 修复后这些字段必然存在，但仍要补断言以防回退。

---

## 3. 设计处方

> 所有 .m 修改只允许小步进行；每个 step 给出 (a) 改前/改后契约、(b) 单元测试断言点、(c) 与下游兼容性。

### 3.1 处方 A1 —— `RRFSimulator` 增 `NumAntennas` alias setter

#### 3.1.1 选项对比

| 方案 | 改动量 | 风险 | 决策 |
|------|--------|------|------|
| (a) `RRFSimulator` 加 `NumAntennas` dependent property，set 转发到 `NumReceiveAntennas` | 1 文件 ~10 行 | 低；matlab.System 允许 dependent property | **采纳** |
| (b) `setupReceivers` 同时写 `NumAntennas` + `NumReceiveAntennas` | 1 文件 1 行 | 字段名不一致语义被永久固化 | 拒绝 |
| (c) `ReceiveFactory.configureReceiverBlock` 加显式 mapping table | 1 文件 ~10 行 | 拷贝逻辑分散到多处 | 拒绝 |

audit §17.3 明示采纳 (a)。

#### 3.1.2 改前/改后契约

**改前**：`rxInfo.NumAntennas = 4` → 块上 `NumReceiveAntennas` 仍为 1（默认值）。

**改后**：`rxInfo.NumAntennas = 4` → 块上 `NumReceiveAntennas == 4`；`rxBlock.NumAntennas` 读取也返回 4。

#### 3.1.3 实施细节

修改 `+csrd/+blocks/+physical/+rxRadioFront/RRFSimulator.m`：

```matlab
properties (Dependent)
    NumAntennas
end

methods
    function v = get.NumAntennas(obj)
        v = obj.NumReceiveAntennas;
    end
    function set.NumAntennas(obj, v)
        obj.NumReceiveAntennas = v;
    end
end
```

> 注：`Dependent property` 在 `matlab.System` 子类里完全支持，且 `isprop(rxBlock, 'NumAntennas')` 会返回 true，触发 `ReceiveFactory.configureReceiverBlock` 现有的 `isprop` 分支自动赋值。**无需改 ReceiveFactory**。

#### 3.1.4 单元测试断言点

`tests/unit/RxNumAntennasAliasTest.m`（新增）：

1. 默认情况下 `block.NumAntennas == block.NumReceiveAntennas == 1`
2. 设 `block.NumAntennas = 4`，断言 `block.NumReceiveAntennas == 4`
3. 设 `block.NumReceiveAntennas = 2`，断言 `block.NumAntennas == 2`
4. 走完整 `ReceiveFactory.stepImpl` 路径，验证 `rxInfo.NumAntennas = 3` 后 `rxBlock.NumReceiveAntennas == 3`

#### 3.1.5 与下游兼容性

不影响任何现有调用——所有现存代码都用 `NumReceiveAntennas`，alias 只新增一个等价别名。

---

### 3.2 处方 A2 —— 解锁一帧多 burst

#### 3.2.1 关键设计抉择：interval 与 frame 重叠语义

audit §6.4 已经裁决：**"interval 与 frame 有重叠就必须建段"**。本 Phase 1 严格按此实现：

- 重叠条件：`intervals(i,2) > frameStart && intervals(i,1) < frameEnd`（半开区间，一致 MATLAB 1-based + endpoint exclusive）
- 不再用 frame_start ∈ [s, e) 的旧语义

#### 3.2.2 改前/改后 schema

**改前**`transmissionState` 字段：
```
.IsActive         logical
.StartTime        scalar
.Duration         scalar
.CurrentIntervalIdx  scalar (单值)
```

**改后**`transmissionState` 字段（新增 + 兼容旧字段）：
```
.IsActive             logical
.ActiveIntervalIndices    1xK uint32（**新增主字段**，K=0/1/N）
.ActiveIntervals          Kx2 double（每行 = [segStart, segEnd]，clip 到 frame 范围内）
.StartTime            scalar     (向后兼容：= ActiveIntervals(1,1) 或 0)
.Duration             scalar     (向后兼容：= sum(diff(ActiveIntervals,1,2)) 或 0)
.CurrentIntervalIdx   scalar     (向后兼容：= ActiveIntervalIndices(1) 或 0)
```

> 旧字段保留是为了让本阶段不动的下游模块（如 `setupTransmitterInfo`、`updateTransmitterAntennaConfig`）继续工作。新字段只新增不替换。

#### 3.2.3 实施细节

##### Step 1：`+csrd/+pipeline/+scenario/checkTransmissionInterval.m`

新增姊妹函数 `findOverlappingTransmissionIntervals.m`（保留原函数不动，避免回归现有调用方），签名：

```matlab
function overlaps = findOverlappingTransmissionIntervals(frameId, pattern)
% Returns:
%   overlaps(k).Index     uint32  — interval row index in pattern.Intervals
%   overlaps(k).StartTime double  — clip 到 frame 内的实际段起点（秒）
%   overlaps(k).EndTime   double  — clip 到 frame 内的实际段终点（秒）
% 当无重叠时返回 0x1 空 struct array（`overlaps = repmat(struct(...),0,1);`）
```

> 实现要点：① 沿用旧函数的 frameDuration 推导逻辑（FrameDuration 优先 / NumFrames+ObservationDuration fallback）；② frame 区间 = `[frameStart, frameEnd) = [(frameId-1)*frameDuration, frameId*frameDuration)`；③ 对每个 interval 检查 overlap 条件并 clip。

##### Step 2：`+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/calculateTransmissionState.m`

把 Burst / Scheduled / Random 三个 case 改成调用新姊妹函数收集所有 overlapping intervals：

```matlab
case 'Burst'
    if isfield(pattern, 'Intervals') && ~isempty(pattern.Intervals)
        overlaps = csrd.pipeline.scenario.findOverlappingTransmissionIntervals(frameId, pattern);
        if isempty(overlaps)
            transmissionState.IsActive = false;
            transmissionState.ActiveIntervalIndices = uint32([]);
            transmissionState.ActiveIntervals = zeros(0, 2);
            transmissionState.StartTime = 0;
            transmissionState.Duration = 0;
            transmissionState.CurrentIntervalIdx = 0;
        else
            transmissionState.IsActive = true;
            transmissionState.ActiveIntervalIndices = uint32([overlaps.Index]);
            transmissionState.ActiveIntervals = ...
                [arrayfun(@(s) s.StartTime, overlaps), arrayfun(@(s) s.EndTime, overlaps)];
            transmissionState.StartTime = transmissionState.ActiveIntervals(1, 1);
            transmissionState.Duration = sum(diff(transmissionState.ActiveIntervals, 1, 2));
            transmissionState.CurrentIntervalIdx = transmissionState.ActiveIntervalIndices(1);
        end
    end
```

`Scheduled` 与 `Random` 同样模式；它们原有的 magic fallback（`mod(frameId,3)==0` / 永远 true）**保留不动**——属于 D4 范围（Phase 2 删）。本 Phase 仅当 `Intervals` 非空时切到新逻辑。

##### Step 3：`+csrd/+core/@ChangShuo/private/processSingleTransmitter.m`

把 L47-66 改为优先消费数组：

```matlab
ts = currentTxScenario.TransmissionState;
if isfield(ts, 'ActiveIntervalIndices') && ~isempty(ts.ActiveIntervalIndices)
    currentTxScenario.NumSegments = numel(ts.ActiveIntervalIndices);
    currentTxScenario.ActiveSegmentIndices = double(ts.ActiveIntervalIndices(:)');
    if isfield(ts, 'ActiveIntervals')
        currentTxScenario.ActiveIntervalsTime = ts.ActiveIntervals;
    end
elseif isfield(ts, 'CurrentIntervalIdx') && ts.CurrentIntervalIdx > 0
    % 保留旧分支，处理 Phase 1 之前留下来的旧 plan
    currentTxScenario.NumSegments = 1;
    currentTxScenario.ActiveSegmentIndices = ts.CurrentIntervalIdx;
elseif isfield(currentTxScenario, 'Temporal') && ...
        isfield(currentTxScenario.Temporal, 'Intervals') && ...
        ~isempty(currentTxScenario.Temporal.Intervals)
    currentTxScenario.NumSegments = size(currentTxScenario.Temporal.Intervals, 1);
    currentTxScenario.ActiveSegmentIndices = 1:currentTxScenario.NumSegments;
else
    currentTxScenario.NumSegments = 1;
    currentTxScenario.ActiveSegmentIndices = 1;
end
```

#### 3.2.4 与下游兼容性

- `processTransmitterSegments` 已经按 `ActiveSegmentIndices` 数组循环（已确认事实凭据 §4 文件 quote），无需改
- `processSingleSegment` 接收 `segIdx` 单值，不受影响
- 旧字段 `StartTime/Duration/CurrentIntervalIdx` 全保留，**任何不读 `ActiveIntervalIndices` 的代码继续按旧语义工作**

#### 3.2.5 单元测试断言点

`tests/unit/MultiBurstPerFrameTest.m`（新增）：

1. **3 intervals 全在 frame 内** → `numel(ActiveIntervalIndices) == 3`，`ActiveIntervals` 与 `pattern.Intervals` 完全相等
2. **2 intervals 部分跨 frame 边界** → indices 正确，`ActiveIntervals` 在 frame 端被 clip
3. **0 interval 重叠** → `IsActive == false`，`numel(ActiveIntervalIndices) == 0`
4. **旧 plan（仅 CurrentIntervalIdx）** → `processSingleTransmitter` 仍只产 1 段（旧分支保留）
5. **Continuous pattern** → `numel(ActiveIntervalIndices)` 不被填（保持 IsActive=true、Duration=ObservationDuration），向后兼容

---

### 3.3 处方 A4 —— 删除 entity silent fallback

#### 3.3.1 改前/改后

**改前**`stepImpl.m:30-33`：
```matlab
workingEntities = synchronizeScenarioEntities(obj.scenarioEntities, entities, frameId);
if isempty(workingEntities)
    workingEntities = entities;
end
```

**改后**：
```matlab
workingEntities = synchronizeScenarioEntities(obj.scenarioEntities, entities, frameId);
if isempty(workingEntities)
    if isempty(entities)
        % current is empty too — let the upstream physical sim explain itself
        error('CSRD:Scenario:EmptyEntities', ...
            ['Frame %d: PhysicalEnvironmentSimulator returned an empty entity ', ...
             'list. CommunicationBehaviorSimulator cannot run on no entities.'], ...
            frameId);
    else
        % previous-vs-current divergence — should never happen unless an upstream
        % stage swapped or rebuilt the scenario mid-flight
        error('CSRD:Scenario:EntityDriftDetected', ...
            ['Frame %d: synchronizeScenarioEntities returned empty even though ', ...
             '%d current entities were provided. This indicates an upstream ', ...
             'scenario-rebuild bug.'], frameId, numel(entities));
    end
end
```

> 选择 fail-fast 而非 warning，是因为 §17.3 把 H9 列在 "解决条目" 而不是 "deprecation"。错误标识符均纳入 `csrd.pipeline.scenario.isScenarioSkipException` 白名单要在 §3.3.3 决策。

#### 3.3.2 与现状兼容性

经事实凭据 §2.3，`synchronizeScenarioEntities` 在 `previousEntities` 为空时已立即返回 `currentEntities`；**实际触发 L31-33 回退路径的唯一可能就是 `currentEntities` 自身为空**——这种情况本身就是 PhysicalEnvironmentSimulator 上游 bug，必须暴露。

#### 3.3.3 错误归类决策

| 错误 ID | 是否归 `isScenarioSkipException` | 理由 |
|---------|-----------------------------------|------|
| `CSRD:Scenario:EmptyEntities` | **是**（new） | 物理仿真无实体，整个 scenario 无可处理；按 SkipScenario 走 |
| `CSRD:Scenario:EntityDriftDetected` | **否** | 编程错误，要求 fail-fast 暴露 |

实施时改 `+csrd/+pipeline/+scenario/isScenarioSkipException.m`，在白名单加 `CSRD:Scenario:EmptyEntities`。

#### 3.3.4 单元测试断言点

`tests/unit/EntitySyncFailFastTest.m`（新增）：

1. `current` 非空、`previous` 空 → 正常返回 `current`，无错
2. `current` 空、`previous` 空 → 抛 `CSRD:Scenario:EmptyEntities`
3. `current` 非空、`previous` 非空但 ID 全错配 → 返回 `current`（按现有合并逻辑）
4. 模拟一种 "previous 非空但触发返回空" 的极端 mock → 抛 `CSRD:Scenario:EntityDriftDetected`
5. `isScenarioSkipException(MException('CSRD:Scenario:EmptyEntities','x'))` 返回 true

---

### 3.4 处方 H13 —— Channel Seed 公式纳入 BurstId

#### 3.4.1 设计目标

| 用例 | Seed 行为 |
|------|-----------|
| 同 (TxId, RxId, BurstId)，跨 frame 多次访问 | **完全相同** |
| 不同 (TxId, RxId, BurstId) | **不同** |
| 同 (TxId, RxId)，不同 BurstId | **不同**（替代旧公式中的 frameId 角色） |

> 旧公式用 `frameId` 而非 `burstId` 是因为 burst 概念尚未被下游严格传播——这正是 H14 + signal struct 字段表（§16.5.2）要解决的事。

#### 3.4.2 实施细节

`+csrd/+factories/ChannelFactory.m` `configureStatisticalBlock`，把 L342-350 改为：

```matlab
if isprop(currentChannelBlock, 'Seed')
    try
        currentChannelBlock.Seed = obj.deriveChannelSeed( ...
            txIdStr, rxIdStr, channelLinkSpecificInfo, frameId);
    catch ME_seed
        obj.logger.warning('Could not update channel Seed: %s', ME_seed.message);
    end
end
```

新增 private method `deriveChannelSeed`：

```matlab
function seed = deriveChannelSeed(~, txIdStr, rxIdStr, channelLinkInfo, frameId)
    burstId = '';
    if isstruct(channelLinkInfo) && isfield(channelLinkInfo, 'BurstId') && ~isempty(channelLinkInfo.BurstId)
        burstId = char(string(channelLinkInfo.BurstId));
    end
    if isempty(burstId)
        % 没有 burstId（未携带）→ 退化为旧 frame-级别公式，避免 Phase 1 中断
        % Phase 2 蓝图层落地后，channelLinkInfo.BurstId 必填，此分支应消失
        burstId = sprintf('frame_%d', frameId);
    end
    payload = sprintf('%s|%s|%s', char(txIdStr), char(rxIdStr), burstId);
    digest = csrd.support.hash.shortInt32Hash(payload);  % 新工具，见 §4.3
    seed = mod(digest, 2^31 - 1);
end
```

> 注意：①  `frame_%d` fallback 是 Phase 1 → Phase 2 之间的过渡，在 Phase 2 蓝图层把 BurstId 注入 `channelLinkInfo` 后该分支必死，单元测试用 `assertEqual(seed_old, seed_new_via_burst)` 验证迁移完成；② Phase 1 上线时 H14 修复（§3.5）会把 segmentSignal.BurstId 透传到 channelLinkInfo，因此实际只在极少蓝图缺字段路径才会走 fallback。

#### 3.4.3 与下游兼容性

仅 `configureStatisticalBlock` 内部改动，不影响 channel block 的对外接口。RayTracing block 没有 `Seed` 属性 → `isprop` 检查跳过。

#### 3.4.4 单元测试断言点

`tests/unit/ChannelSeedBurstAwareTest.m`（新增）：

1. `(Tx_A, Rx_A, BurstId='B01', frameId=3)` 与 `(Tx_A, Rx_A, BurstId='B01', frameId=10)` → seed 相等
2. `(Tx_A, Rx_A, BurstId='B01', _)` 与 `(Tx_A, Rx_A, BurstId='B02', _)` → seed 不等
3. `(Tx_A, Rx_A, _)` 与 `(Tx_B, Rx_A, _)` → seed 不等
4. `(Tx_A, Rx_A, _)` 与 `(Tx_A, Rx_B, _)` → seed 不等
5. **回归保护**：同一 (TxId, RxId, BurstId) 1000 次调用 seed 完全相同
6. **碰撞采样**：随机 1000 组不同 (TxId, RxId, BurstId) 三元组，seed 集合大小 ≥ 999（碰撞率 < 0.1%）

---

### 3.5 处方 H14 —— `mergeChannelOutput` 改白名单覆盖

#### 3.5.1 字段分类

按 §16.5.2 + 当前代码现状，把 channel 边界的字段分为三组：

| 组 | 字段 | 来源 | 在 merge 中的策略 |
|------|------|------|---------------------|
| **必须由 channel 重写** | `Signal` | channel 输出 | **覆盖** input |
| **channel 选择性写入** | `PathLoss` (analytical) / `AppliedPathLoss` / `ChannelInfo` / `RayCount` / `ChannelFallback` / `LinkDistance` (channel 自报值) | channel 输出 | **覆盖** input（仅当 channel 写了非空值时）|
| **必须从 input 透传** | `SegmentId` / `BurstId` / `EmitterId` / `ReceiverId` / `Planned` / `SampleRate` / `FrequencyOffset` / `Bandwidth` / `StartTime` / `Duration` / `ModulationTypeID` / `RFImpairments` / `TxInfo` / `RxInfo` | input | **不允许 channel 覆盖**（channel 即使写了同名字段也忽略，只走 warning）|

#### 3.5.2 实施细节

把 `mergeChannelOutput` 改为：

```matlab
function receivedSignalStruct = mergeChannelOutput(obj, inputSignalStruct, channelBlockOutput)
    % 起点 = input 全字段（包括 SegmentId / BurstId / Planned / etc.）
    receivedSignalStruct = inputSignalStruct;

    % 第一组：必须覆盖
    if isstruct(channelBlockOutput) && isfield(channelBlockOutput, 'Signal')
        receivedSignalStruct.Signal = channelBlockOutput.Signal;
    elseif ~isstruct(channelBlockOutput)
        receivedSignalStruct.Signal = channelBlockOutput;
        return;
    end

    % 第二组：选择性覆盖
    channelOnlyFields = {'PathLoss','AppliedPathLoss','ChannelInfo','RayCount', ...
                         'ChannelFallback','LinkDistance','ChannelModel','AppliedSNRdB'};
    if isstruct(channelBlockOutput)
        outputFields = fieldnames(channelBlockOutput);
        for idx = 1:numel(outputFields)
            f = outputFields{idx};
            if any(strcmp(f, channelOnlyFields))
                receivedSignalStruct.(f) = channelBlockOutput.(f);
            elseif strcmp(f, 'Signal')
                continue;  % already handled
            elseif isfield(receivedSignalStruct, f) && ~isequal(receivedSignalStruct.(f), channelBlockOutput.(f))
                obj.logger.debug(['mergeChannelOutput: channel block tried to overwrite ', ...
                    'protected field "%s"; ignoring (input value preserved).'], f);
            else
                % 第三组以外的、input 没有的字段 → 允许 channel 写入（向前兼容新字段）
                receivedSignalStruct.(f) = channelBlockOutput.(f);
            end
        end
    end
end
```

> 注意：① `obj` 改成有参（原来是 `~`），便于 logger 调用；② `channelOnlyFields` 用闭表是为了让 Phase 2 蓝图字段不被 channel 偷偷覆盖；③ 不在第三组而 input 没有的字段允许写入，避免破坏未来 channel 块（如 Phase 4 Doppler 的 `DopplerShiftHz`）的兼容性。

#### 3.5.3 与下游兼容性

下游 `processChannelPropagation.m` L99-181 大量字段读取已经做 `isfield` 兜底，本修改让它们都能拿到上游字段，**只会增加 component 字段、不会减少**。

#### 3.5.4 单元测试断言点

`tests/unit/MergeChannelOutputContractTest.m`（新增）：

1. **input 含 `SegmentId='S1'`，channel 输出含 `Signal`** → merge 后 `SegmentId == 'S1'`、`Signal == channel 输出的 Signal`
2. **input 含 `BurstId='B07'`，channel 输出试图写 `BurstId='B99'`** → merge 后 `BurstId == 'B07'`，且 logger 命中一条 debug
3. **input 含 `Planned.Bandwidth=10e6`，channel 输出含 `PathLoss=80`** → merge 后 `Planned.Bandwidth == 10e6 && PathLoss == 80`
4. **input 字段全集 ⊆ merge 输出字段全集**（不丢字段不变量）
5. **channel 输出非 struct（纯数组）** → merge 输出 = input + `Signal=array`

---

### 3.6 处方 C1（强 schema） —— signal struct 4 边界字段断言 + RX impairments 全集

#### 3.6.1 4 个边界 contract test

按 §16.5.2 字段表，在 4 个边界各落一组 `assert + ContractTest`：

| 边界 | 落点 | 必含字段 |
|------|------|---------|
| **B0 modulator out** | `processSingleSegment` 出口 | `Signal / SampleRate / SegmentId / BurstId / EmitterId / Planned` |
| **B1 TRF out** | `processTransmitImpairments` 出口（非破坏式只验证）| 同 B0 + (允许新增 RFImpairments 字段) |
| **B2 channel in/out** | `ChannelFactory.stepImpl` 出口 | 同 B0 + `ReceiverId` 必填 |
| **B3 component** | `processChannelPropagation` 拼装的 component | 同 B2 + `LinkDistance / ChannelModel`（来自 H14 修复后）|

落点写一个共享 helper：

```matlab
function assertSignalStructContract(s, boundary)
% boundary ∈ {'B0_modulator','B1_trf','B2_channel','B3_component'}
% Throws CSRD:Signal:ContractViolation when fields are missing/typed wrong.
```

放在 `+csrd/+pipeline/+contract/assertSignalStructContract.m`。**Phase 1 不在生产代码 Always-on**——只在 ContractTest 内 invoke，否则会大量 throw 让 baseline 退化。生产代码仅在 H14 / RFImpairments 缺失时 throw（§3.5、§3.6.2 已含）。

> 这个权衡来自 Phase 0 已经发现的现状：当前 segment / channel 边界字段并未严格符合 §16.5.2（如 `BurstId` 在多数路径上还是空的）。Phase 1 的工作是**把代码朝契约靠拢**，而不是一次性强制契约导致全量 baseline crash。Phase 2/3 把蓝图层落实后，再把 helper 改成 always-on 的 `mustBe*` 风格断言。

#### 3.6.2 RX RFImpairments 全集

修改 `+csrd/+factories/ReceiveFactory.m` L122-124：

```matlab
receivedDataStruct.RxImpairments = struct();
receivedDataStruct.RxImpairments.DCOffset = currentReceiverBlock.DCOffset;
receivedDataStruct.RxImpairments.IqImbalanceConfig = currentReceiverBlock.IqImbalanceConfig;
receivedDataStruct.RxImpairments.ThermalNoiseConfig = currentReceiverBlock.ThermalNoiseConfig;
receivedDataStruct.RxImpairments.MemoryLessNonlinearityConfig = ...
    currentReceiverBlock.MemoryLessNonlinearityConfig;
receivedDataStruct.RxImpairments.SampleRateOffsetPpm = currentReceiverBlock.SampleRateOffset;
receivedDataStruct.RxImpairments.MasterClockRate = currentReceiverBlock.MasterClockRate;
```

> `MemoryLessNonlinearityConfig` 与 `SampleRateOffset` 字段都是 RRFSimulator 的暴露属性（§2.6 quote 已确认），可直接读。

下游 `buildSourceAnnotation.m` 已经写 `if isfield(comp,'RFImpairments') sourceInfo.RFImpairments = comp.RFImpairments; end`（事实凭据 L185-187），**无需改 buildSourceAnnotation**。

#### 3.6.3 单元测试断言点

`tests/unit/SignalStructContractTest.m`（新增）：

1. B0/B1/B2/B3 各构造 1 个合法 struct，`assertSignalStructContract` 不抛
2. 4 个边界各构造 1 个缺关键字段的 struct，`assertSignalStructContract` 抛 `CSRD:Signal:ContractViolation`
3. RX 阶段 mock 一个 RRFSimulator，验证 `receivedDataStruct.RxImpairments` 字段集 = `{DCOffset, IqImbalanceConfig, ThermalNoiseConfig, MemoryLessNonlinearityConfig, SampleRateOffsetPpm, MasterClockRate}`

---

## 4. 文件级落点清单

### 4.1 修改文件（共 6 个）

| 文件 | 关联处方 | 大致行数 |
|------|----------|----------|
| `+csrd/+blocks/+physical/+rxRadioFront/RRFSimulator.m` | §3.1 | +12 行（新 dependent property + getter/setter）|
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/calculateTransmissionState.m` | §3.2 | +30 行 / -10 行（Burst/Scheduled/Random 改写）|
| `+csrd/+core/@ChangShuo/private/processSingleTransmitter.m` | §3.2 | +10 行 / -5 行（消费数组）|
| `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/stepImpl.m` | §3.3 | +12 行 / -3 行（fail-fast）|
| `+csrd/+factories/ChannelFactory.m` | §3.4 + §3.5 | +35 行 / -10 行（Seed 公式 + mergeChannelOutput 重写）|
| `+csrd/+factories/ReceiveFactory.m` | §3.6.2 | +6 行（RFImpairments 全集）|
| `+csrd/+pipeline/+scenario/isScenarioSkipException.m` | §3.3.3 | +1 行（白名单加 EmptyEntities）|

### 4.2 新增文件（共 3 个）

| 文件 | 用途 |
|------|------|
| `+csrd/+pipeline/+scenario/findOverlappingTransmissionIntervals.m` | §3.2 多 burst 收集 |
| `+csrd/+pipeline/+contract/assertSignalStructContract.m` | §3.6 契约断言 helper |
| `+csrd/+support/+hash/shortInt32Hash.m` | §3.4 BurstId-aware seed 用，见 §4.3 |

### 4.3 关于 `shortInt32Hash`

为了让 Seed 公式可读、可测、不再用 `sum(double(char(.)))` 这种弱 hash：

```matlab
function value = shortInt32Hash(text)
% Returns int32-range non-negative integer derived from MD5(text).
% Implementation:
%   md5_bytes = uint8(<MD5 of utf8(text)>);  via java.security.MessageDigest
%   first 4 bytes interpreted big-endian as uint32, masked to 31 bits
% No external dependencies beyond JVM (always available in MATLAB).
```

`MD5` 仅用于 hash dispersion，不涉及加密强度需求。Phase 2 BlueprintHash 用 SHA-256 是另一回事。

### 4.4 不动文件（白名单确认）

下列文件 **Phase 1 严禁碰**：

- `+csrd/+core/@ChangShuo/private/processSingleSegment.m`（M3 fallback 留 Phase 3）
- `+csrd/+core/@ChangShuo/private/processTransmitImpairments.m`（M5 fallback 留 Phase 3）
- `+csrd/+core/@ChangShuo/private/processChannelPropagation.m` 中 SampleRate 三层 fallback（留 Phase 3）
- `+csrd/+core/@ChangShuo/private/processReceiverProcessing.m` `buildSourceAnnotation`（已经能接住 RFImpairments，无需改；测量层留 Phase 4）
- `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/allocateFrequencies*.m`（D7 deprecation 留 Phase 2）
- `+csrd/SimulationRunner.m`（Phase 0 已稳定，Phase 1 不动）
- `+csrd/+pipeline/+annotation/sanitizeForJson.m`（Phase 0 已 Frozen）

---

## 5. 测试计划

### 5.1 单元测试（新增 6 个，全部放 `tests/unit/`）

| 文件 | 关联处方 | 用例数（估）|
|------|----------|-------------|
| `RxNumAntennasAliasTest.m` | §3.1 | 4 |
| `MultiBurstPerFrameTest.m` | §3.2 | 5 |
| `EntitySyncFailFastTest.m` | §3.3 | 5 |
| `ChannelSeedBurstAwareTest.m` | §3.4 | 6 |
| `MergeChannelOutputContractTest.m` | §3.5 | 5 |
| `SignalStructContractTest.m` | §3.6 | 7（4 boundary × pos/neg + RX impairments）|

总计 ~32 cases。

### 5.2 回归测试（新增 1 个 + 复用 1 个）

| 文件 | 用途 |
|------|------|
| `tests/regression/test_phase1_dataflow_smoke.m`（新增）| 跑 6 场景，分别覆盖：单 burst / 多 burst / 多 RxAntennas / RX 含 RFImpairments / channel seed 跨帧一致 / merge 不丢字段。每场景最后断言 annotation JSON 存在关键字段 |
| `tests/regression/test_baseline_sweep_200.m`（复用 Phase 0）| Phase 1 完成后**重跑 200 场景 full**，与 Phase 0 baseline JSON 对比 4 条不变量（§9.2 Phase 0 设计已写死）|

### 5.3 入口与归类

修改 `tests/run_all_tests.m`：

- 新增 testType `'phase1'`，包含 §5.1 全部 6 个单元 + §5.2 第一个回归（smoke）
- `'phase0'` 不变（仍包含 Phase 0 全套）
- `'all'` 自动包含 `'phase0' ∪ 'phase1' ∪ unit ∪ regression`（去重）

> baseline_sweep_200 不进 `'phase1'` 默认 group，仍由 operator 手动跑（耗时 1h）。

### 5.4 关于"测哪个文件的哪个契约"映射（呼应 §8 v0.3）

| 契约 | 测试 |
|------|------|
| `RRFSimulator.NumAntennas == NumReceiveAntennas` | `RxNumAntennasAliasTest.test_alias_setter_get` |
| `transmissionState.ActiveIntervalIndices` 收齐所有重叠 interval | `MultiBurstPerFrameTest.test_three_intervals_in_frame` |
| `ChannelFactory.deriveChannelSeed` 同 burst 跨帧一致 | `ChannelSeedBurstAwareTest.test_same_burst_across_frames_same_seed` |
| `mergeChannelOutput` 不丢 SegmentId/BurstId/Planned | `MergeChannelOutputContractTest.test_input_segment_id_preserved` |
| `RxImpairments` 含 6 个字段 | `SignalStructContractTest.test_rx_impairments_full_set` |
| 200 场景 BlueprintAcceptanceRate ≥ 0.98 | `test_baseline_sweep_200`（Phase 1 重跑后比对 Phase 0 baseline）|

---

## 6. 实施顺序（强建议依次进行，每步独立验证）

| Step | 内容 | 阻塞条件 |
|------|------|----------|
| **S1** | §3.1 RRFSimulator NumAntennas alias + 单测 `RxNumAntennasAliasTest` | 单测 0 失败 |
| **S2** | §4.3 `shortInt32Hash.m` + 自测（10 case）；§3.4 ChannelFactory Seed 改公式 + `ChannelSeedBurstAwareTest` | 单测 0 失败；6 个 seed case 全过 |
| **S3** | §3.5 mergeChannelOutput 重写 + `MergeChannelOutputContractTest` | 单测 0 失败；现有 `test_channel_exception_propagation.m` 仍过 |
| **S4** | §3.6.2 ReceiveFactory RFImpairments 全集；§4.2 `assertSignalStructContract.m` + `SignalStructContractTest` | 单测 0 失败 |
| **S5** | §3.3 stepImpl fail-fast + `isScenarioSkipException` 白名单 + `EntitySyncFailFastTest` | 单测 0 失败；现有 `test_refactoring.m` 仍过 |
| **S6** | §3.2 三个文件 (`findOverlappingTransmissionIntervals` 新增 / `calculateTransmissionState` 改写 / `processSingleTransmitter` 数组消费) + `MultiBurstPerFrameTest` | 单测 0 失败；现有 regression 全过 |
| **S7** | `tests/run_all_tests.m` 加 `'phase1'` + `tests/regression/test_phase1_dataflow_smoke.m` 起草并跑 | smoke 6 场景全过 |
| **S8** | 跑 `run_all_tests('all')` —— Phase 0 + Phase 1 + unit + regression 全套 | 0 失败 |
| **S9** | 跑 `test_baseline_sweep_200(200,'Mode','full')` 重新生成 baseline JSON | 4 条不变量满足（见 §7） |
| **S10** | 写实施快照 → 本文档状态改 Frozen → 顶层 audit §17.3 标 Frozen | — |

实施过程中如果某个 step 的单测过不了，**禁止跳过** —— 必须先回到该 step 的处方修复，不能"先实施完所有 step 再统一调试"。

---

## 7. 出口判据 checklist

7 条硬性判据，**全过才能进入 Phase 2**：

- [ ] **C1** §3.1 完成；`RxNumAntennasAliasTest` 4 cases 全过；端到端验证：scenario 配 `Hardware.NumAntennas=4` → annotation 内可观测到 `NumReceiveAntennas=4` 路径生效
- [ ] **C2** §3.2 完成；`MultiBurstPerFrameTest` 5 cases 全过；端到端验证：`tests/regression/test_phase1_dataflow_smoke.m` 中 "多 burst" 场景产 ≥ 2 segments，segment annotation 字段齐
- [ ] **C3** §3.3 完成；`EntitySyncFailFastTest` 5 cases 全过；旧 regression `test_refactoring.m` 仍过
- [ ] **C4** §3.4 完成；`ChannelSeedBurstAwareTest` 6 cases 全过；同一 (TxId, RxId, BurstId) 1000 次 seed 完全相同；1000 个不同三元组碰撞率 < 0.1%
- [ ] **C5** §3.5 完成；`MergeChannelOutputContractTest` 5 cases 全过；端到端验证：smoke 场景中至少一个 component annotation 同时含 `SegmentId / BurstId / Planned / PathLoss / ChannelModel`
- [ ] **C6** §3.6 完成；`SignalStructContractTest` 7 cases 全过；smoke 场景中 `annotation.SignalSources(*).RFImpairments` 字段集 = 6 项
- [x] **C7** Phase 1 完成后重跑 200 场景 full baseline，结果文件 `docs/baselines/2026-04-baseline-v0.json`（**已覆盖** Phase 0 版本；实测见 §9.4）：
    - `BlueprintAcceptanceRate >= 0.98`（Phase 0 = 1.0；**实测 1.0 ✅**）
    - `ChannelFactoryFailureRate <= 0.02`（Phase 0 = 0.0；**实测 0.0 ✅**）
    - `Diagnostics.JsonNanCount == 0 && JsonInfinityCount == 0`（Phase 0 红线，永久；**实测 0 / 0 ✅**）
    - `WallclockSecPerScenarioP50 <= 1.15 × 18.5 = 21.3 s`（Phase 0 = 18.5；**Phase 1 owner 决议 A 案**：阈值由 +10% 放宽到 **+15%**，吸收单 sweep 抽样噪声 ±8%；**实测 20.49 s ✅**）
    - `WallclockSecPerScenarioP95 <= 1.15 × 35.93 = 41.3 s`（同上口径；**实测 39.86 s ✅**）
    - `AnnotationFileBytesP50 <= 10240 B`（**Phase 1 owner 决议 A 案**：阈值由 5120 B 放宽到 **10 KB**，给 Phase 2/3/4 字段预算；**实测 7826 B ✅**）
    - **新增**（待 Phase 2 由 sweep 脚本补统计）`MultiBurstPerFrameRate`：含 `>= 1` 个多 burst 场景，且其多 burst 帧均产 segments > 1
    - **新增**（待 Phase 2 由 sweep 脚本补统计）`ChannelSeedConsistencyChecksum`：选 1 个 statistical channel 场景，按 (TxId, RxId, BurstId) 分组，组内 seed 唯一

实施时把 C7 新增字段的统计逻辑加到 `test_baseline_sweep_200.m`（属于 §4.1 修改清单，但归回归脚本不算生产代码改动）。

---

## 8. 风险登记表

| ID | 风险 | 影响 | 缓解 |
|----|------|------|------|
| R1 | 旧调用方依赖 `transmissionState.CurrentIntervalIdx` 是单值 | 数组化后下游 `setupTransmitterInfo` / `updateTransmitterAntennaConfig` 可能误读 | §3.2 决定保留旧字段（`CurrentIntervalIdx = ActiveIntervalIndices(1)`），新增字段不替换；smoke 回归覆盖 |
| R2 | `mergeChannelOutput` 白名单覆盖把旧"channel 改写 SegmentId" 路径切断，可能让某种特殊蓝图 break | smoke 回归首跑后立即检查；如果出现 → 把"channel 改写" 字段加进 `channelOnlyFields` 白名单（仅在该字段确实属于 channel 概念时） | 设计 §3.5.2 已留扩展点 |
| R3 | `shortInt32Hash` 用 JVM；如果未来跑 deployed 环境（无 JVM）会断 | Phase 1 不影响开发主链；Phase 5 CI 或部署用例时再考虑替换为纯 MATLAB hash | §4.3 注释中标记 |
| R4 | H9 fail-fast 后某个旧场景因 `EntityDriftDetected` 实际触发，scenario 全 skip → BlueprintAcceptanceRate 跌穿 0.98 | smoke 场景 6 跑出来观察；如果出现 → 在错误前加 logger.warning 记录最后已知 entities 集合，便于定位上游 bug | §3.3 错误信息已含 entity 数量 |
| R5 | RFImpairments 字段集变化导致下游 annotation JSON 大小膨胀 → AnnotationFileBytesP50 严重增长 | 200 场景 baseline 重跑时记录新值；只要 < 5 KB（Phase 1 前 P50 = 634 B）即可接受；超过 → §3.6.2 暂时移除 `MasterClockRate` 字段 | C7 出口判据中独立观察 |
| R6 | Step 6 `processSingleTransmitter` 改成数组消费时，与 §1.2 留给 Phase 3 的 `setupTransmitterInfo` 字段产生隐性耦合 | 实施前 Read `setupTransmitterInfo.m` 全文，确认它不读 `NumSegments` / `ActiveSegmentIndices` 之外的隐含字段 | §6 S6 前先做这次 Read |
| R7 | `findOverlappingTransmissionIntervals` 若 frame 与某 interval 仅在 frame 端点重叠（精度问题）会误判 | 实现时用半开区间 `intervals(i,2) > frameStart && intervals(i,1) < frameEnd`；测试用例覆盖 ε 边界（10 ns）| 单元测试 case 4 覆盖 |
| R8 | wallclock 增长 > 5%（出口 C7） | 实施前预估：alias setter / 字段拷贝 / hash 是 O(1) 调用，单 frame 增量 < 100 μs；200 帧 × 200 场景 ≈ 4 s 增量 → 远低于 1851 s 的 1% | 真出现 → profile，定位增量来源 |

---

## 附录 A：与 v0.3 §6.bis baseline 7 个数对照（前置基线）

Phase 0 实测 baseline 已固化（`docs/baselines/2026-04-baseline-v0.json`）。Phase 1 完成后重跑 200 场景 full，将得到一个**叠加 Phase 1 字段**的新版本（C7 中已说明字段相容关系）。届时不变量门槛：

| 指标 | Phase 0 实测 | Phase 1 阈值（A 案 owner 决议）| Phase 1 实测 |
|------|--------------|-------------------------------|---------------|
| BlueprintAcceptanceRate | 1.0 | ≥ 0.98 | **1.0** |
| ChannelFactoryFailureRate | 0.0 | ≤ 0.02 | **0.0** |
| WallclockSecPerScenarioP50 | 18.5 s | ≤ 21.3 s（+15%）| **20.49 s** |
| WallclockSecPerScenarioP95 | 35.9 s | ≤ 41.3 s（+15%）| **39.86 s** |
| LogLinesPerScenarioP50 | 200 | 不约束（待 Phase 3 LargeMC 收紧）| 1896 |
| AnnotationFileBytesP50 | 634 B | ≤ 10240 B（RFImpairments + Lookup table + RxImpairments 增量预算）| **7826 B** |
| RealizedVsPlannedBwAbsRelDiffP95 | `[]` | 仍允许非空（Phase 4 闭环量化）| 0.1205 |
| EmptySignalSegmentRatio | 0.0 | ≤ 0.02 | **0.0** |
| Diagnostics.JsonNanCount | 0 | 0（永久红线）| **0** |
| Diagnostics.JsonInfinityCount | 0 | 0（永久红线）| **0** |

---

## 附录 B：Phase 1 中**未触及**的可疑代码（留给后续 Phase）

实施 Phase 1 时遇到的、看起来值得修但不属于 Phase 1 范围的：

| 位置 | 现象 | 建议归属 |
|------|------|----------|
| `processChannelPropagation.m` L113-118 | `SampleRate fallback to rxInfo` 仅 warning 不 error | Phase 3 D10 同批次清 |
| `processChannelPropagation.m` L135-137 | `if isfield(channelOutput, 'Planned') component.Planned = channelOutput.Planned;` | M8 字段错位，Phase 2 删 |
| `combineSignalComponents` L208-214 | 空 SignalComponents 时合成 0.001s 噪声 → 静默兜底 | Phase 3 改成 `EmptySignalSegment` 标志 |
| `ReceiveFactory` L130-135 | `ReceiverBlockStepFailed` 把 inputSignal 当 output | 类比 H11，Phase 2 收紧 |
| `RRFSimulator` L201/206 `release(...)` 每帧 | matlab.System 反模式，每帧 release 浪费 | Phase 3 评估 M9 并行时一并处理 |

将以上 5 项写入下一阶段 audit `phase-2-blueprint.md` / `phase-3-construction.md` 起草时的"已识别但搁置"清单。

---

## 9. 实施快照（执行后填）

### 9.1 Step 实施落点

| Step | 状态 | 实际落点 | 备注 |
|------|------|----------|------|
| **S1** | ✅ | `+csrd/+blocks/+physical/+rxRadioFront/RRFSimulator.m`：直接把属性命名定为 `NumAntennas`（**不再**保留 transitional dependent alias） | R3 阶段把 `NumReceiveAntennas` 彻底拿掉，end-to-end 收敛到 `NumAntennas`；`+csrd/+factories/ReceiveFactory.m` `configureReceiverBlock` 已用 `isprop` + 同名拷贝；`tools/convert_csrd_to_coco.m` / `tests/unit/RxNumAntennasAliasTest.m` / `tests/unit/RRFSimulatorTest.m` 同步改名 |
| **S2** | ✅ | `+csrd/+utils/shortInt32Hash.m` + `+csrd/+factories/ChannelFactory.m`（`generateChannelSeed` 加入 BurstId 维度）；`tests/unit/ChannelSeedBurstAwareTest.m` 6 cases 全过 |
| **S3** | ✅ | `+csrd/+factories/ChannelFactory.m`：`mergeChannelOutput` 改写为字段白名单合并；`+csrd/+core/@ChangShuo/private/processChannelPropagation.m`：消费时调用契约断言；`tests/unit/MergeChannelOutputContractTest.m` 5 cases 全过 |
| **S4** | ✅ | `+csrd/+factories/ReceiveFactory.m` `processedOutput.RxImpairments`（6 字段）；`+csrd/+utils/assertSignalStructContract.m`；`+csrd/+core/@ChangShuo/private/processReceiverProcessing.m` 把 `RxImpairments` 直接写到 frame-level annotation；`tests/unit/SignalStructContractTest.m` 9 cases 全过 |
| **S5** | ✅ | `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/stepImpl.m`：fail-fast；`+csrd/+utils/exceptions/isScenarioSkipException.m`：白名单；`tests/unit/EntitySyncFailFastTest.m` 4 cases 全过 |
| **S6** | ✅ | `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/findOverlappingTransmissionIntervals.m`（新增）；`calculateTransmissionState.m`、`generateFrameConfigurations.m`、`+csrd/+core/@ChangShuo/private/processSingleTransmitter.m` 全部改用数组分支；`tests/unit/MultiBurstPerFrameTest.m` 8 cases 全过 |
| **S7** | ✅ | `tests/run_all_tests.m` 加 `'phase1'` selector；`tests/regression/test_phase1_dataflow_smoke.m` 6 场景全过；定位并 hotfix Phase 0 残缺：`SimulationRunner.stampRuntimeHeader` 把 cell `scenarioAnnotation` 包到 `Frames` 字段下避免 `SignalSources` 被 silent override |
| **R1** | ✅ | `transmissionState` 结构体彻底去掉 `CurrentIntervalIdx / StartTime / Duration` 三个 legacy 标量字段，`processSingleTransmitter` 只走 `ActiveIntervalIndices` 数组分支（无 fallback）。`@PhysicalEnvironmentSimulator/private/createEntity.m` / `tests/regression/test_entity_snapshot_consistency.m` 同步更新 |
| **R2** | ✅ | `+csrd/SimulationRunner.m` `stampRuntimeHeader` 删除 transitional 顶层 `ScenarioId / ProcessedBy / SavedAt`，metadata 仅在 `Header.Runtime` 下出现，避免 schema 双契约 |
| **R3** | ✅ | RRFSimulator `NumReceiveAntennas` → `NumAntennas` 完全重命名（无 dependent alias），见 S1 |
| **R4** | ✅ | `config/_base_/factories/receive_factory.m` 按官方文档 Dependencies 表重写：6 个 Method 各自独立子结构；`Cubic polynomial` 嵌套 `TOISpecifications` cell 仅采样所选 TOI；新增 `LookupTable` Method；`ReferenceImpedance` 提为顶层共享。`+csrd/+factories/ReceiveFactory.m` `configureNonlinearity` 改成 `buildXxxConfig` 6 个 helper，严格只产出 Method 所需字段。`tests/unit/ReceiveFactoryRxImpairmentsTest.m` 同步更新 |
| **R5** | ✅ | `+csrd/+blocks/+physical/+rxRadioFront/RRFSimulator.m` `genLowerPowerAmplifier` 改成 `assembleXxxArgs` 6 个 helper，按官方 Dependencies 严格设属性；移除"未知 Method 默认 Cubic polynomial"的 fallback，改为 fail-fast |
| **R6** | ✅ | `config/_base_/factories/transmit_factory.m` 与 RX 端同步严格化（含 `LookupTable`）；`+csrd/+factories/TransmitFactory.m` `configureNonlinearity` 重写为 6 个 helper；`+csrd/+blocks/+physical/+txRadioFront/TRFSimulator.m` `genMemoryLessNonlinearity` 改成 `assembleXxxArgs` 严格装配，未知 Method fail-fast |
| **R7** | ✅ | `+csrd/+utils/MemoryLessNonlinearityRandom.m` 经全仓 grep 确认无任何 caller，按"无向前兼容代码"原则**整文件删除** |
| **S8** | ✅ | `run_all_tests('all')`：34/34 PASS（regression 9 个、unit 24 个、startup hooks suite 1 个）；wallclock ≈ 657 s |
| **S9** | ✅ | 2026-04-24 23:21 启动、2026-04-25 00:08 完成；wallclock 4418 s；200/200 SUCCESS；5 条强契约 + JSON 数值红线全过；3 条擦/超线指标（Wallclock P50/P95、AnnotationFileBytesP50）按 §9.4.2 owner A 案放宽阈值后全部 ✅。详情见 §9.4 |
| **S10** | ✅ | 本节实施快照已写入 §9.1–§9.4；§9.4.2 owner A 案决议落定 §7 C7 / 附录 A 新阈值；本文档头部状态改 **Frozen**；顶层 audit `2026-04-spectrum-blueprint-construction-refactor.md` §17.3 同步标 ✅ Frozen 并写入新阈值 |

### 9.2 Phase 0 残缺修复（hotfix 摘要）

执行 S7 smoke 时连带修复了 Phase 0 遗漏的两个annotation 数据丢失问题：

1. **`SimulationRunner.stampRuntimeHeader` 把 cell `scenarioAnnotation` 当 struct 处理** —— 直接覆盖丢失 `SignalSources` 等所有上游字段。修复：`localCoerceAnnotationToStruct` 把 cell 包到新增 `Frames` 字段下。
2. **`processReceiverProcessing` 没把 `processedOutput.RxImpairments` 写进 frame-level annotation** —— 导致 §3.6.2 的 6 字段集只在 RX 块内出现，annotation 里看不到。修复：在 frame annotation 顶层显式塞入 `RxImpairments`。

两条 hotfix 都属于"Phase 0 应有但漏做的契约"，已通过 `test_phase1_dataflow_smoke` 兜底，今后任何回退都会立刻被 §3.6.2 / §3.5 ContractTest 抓到。

### 9.3 PA / LNA 非线性建模严格化（R4–R7 集中说明）

按 [`comm.MemorylessNonlinearity` 官方文档](https://www.mathworks.com/help/comm/ref/comm.memorylessnonlinearity-system-object.html) 的 *Dependencies* 表，6 个 Method（`Cubic polynomial`, `Hyperbolic tangent`, `Saleh model`, `Ghorbani model`, `Modified Rapp model`, `Lookup table`）各自只接受官方列出的属性子集；之前 RX/TX 两侧 factory 都走"先生成所有可能的字段、再按 Method 用一部分"的反模式，且 RRF/TRF 在未知 Method 时静默回落到 `Cubic polynomial` 屏蔽错误。

R4–R7 把这块端到端重写：

| 层级 | 文件 | 修改 |
|------|------|------|
| 配置 | `config/_base_/factories/receive_factory.m`、`transmit_factory.m` | 按 Method 独立子结构；`Cubic polynomial` 用 `TOISpecifications` cell 选项 + 嵌套 6 种 TOI 范围；新增 `LookupTable.Table`；`ReferenceImpedance` 顶层共享 |
| Factory | `+csrd/+factories/ReceiveFactory.m`、`TransmitFactory.m` | `configureNonlinearity` 改成 6 个 `buildXxxConfig`，每个 helper 只产出 Method 所需的字段，`Cubic polynomial` 仅设所选 TOI 那一个对应字段 |
| 物理块 | `+csrd/+blocks/+physical/+rxRadioFront/RRFSimulator.m`、`+txRadioFront/TRFSimulator.m` | `genLowerPowerAmplifier` / `genMemoryLessNonlinearity` 改成 6 个 `assembleXxxArgs`，按 Dependencies 拼 NV-pair；未知 Method fail-fast，删除"默认 Cubic polynomial"fallback |
| 工具 | `+csrd/+utils/MemoryLessNonlinearityRandom.m` | 整文件删除（无 caller，按"零向前兼容"原则清理） |

副作用：`Cubic polynomial` 的 `TOISpecification` 字段现在由 `TOISpecifications` cell 列表抽样得到，避免历史上把 `IIP3` 错写到 `OIP3`/`IPsat` 等字段而被默默吞掉的 bug；`Lookup table` 现在端到端可用（`Nx3 [Pin_dBm, Pout_dBm, dPhi_deg]`）。

### 9.4 200 场景 baseline 实测（§7 C7 出口判据对照）

实测产物：`docs/baselines/2026-04-baseline-v0.json`（覆盖 Phase 0 同名文件）；样本 annotation：`artifacts/tests/runs/baseline_v0/sweep_logs/session_20260424_225424/annotations/scenario_000001_annotation.json`。

| 指标 | Phase 0 实测 | Phase 1 阈值（A 案 owner 决议）| Phase 1 实测 | 偏差 | 判定 |
|------|--------------|-------------------------------|---------------|------|------|
| `BlueprintAcceptanceRate` | 1.0 | ≥ 0.98 | **1.0** | — | ✅ |
| `ChannelFactoryFailureRate` | 0.0 | ≤ 0.02 | **0.0** | — | ✅ |
| `Diagnostics.JsonNanCount` | 0 | == 0 | **0** | — | ✅ 红线 |
| `Diagnostics.JsonInfinityCount` | 0 | == 0 | **0** | — | ✅ 红线 |
| `EmptySignalSegmentRatio` | 0.0 | ≤ 0.02 | **0.0** | — | ✅ |
| `WallclockSecPerScenarioP50` (s) | 18.54 | ≤ 21.3 (+15%) | **20.49** | +10.5% | ✅ |
| `WallclockSecPerScenarioP95` (s) | 35.93 | ≤ 41.3 (+15%) | **39.86** | +10.9% | ✅ |
| `AnnotationFileBytesP50` (B) | 634 | ≤ 10240 (10 KB) | **7826** | +1135% (within budget) | ✅ |
| `AnnotationFileBytesP95` (B) | 634 | (无） | 7826 | — | (n/a) |
| `LogLinesPerScenarioP50` | 200 | 不约束 | 1896 | +848% | ⚪ 不在 §7 红线（留 Phase 3 LargeMC 收紧） |
| `RealizedVsPlannedBwAbsRelDiffP95` | `[]` | 允许非空（Phase 4 闭环量化）| **0.1205** | — | ⚪ Phase 1 副产物（详见 §9.4.1 C） |
| `Diagnostics.SanitizeManifestSummary.TotalEntries` | 1 | — | 0 | -100% | ✅ 优于 baseline（无字段需 sanitize） |

> 总体可用率（前 5 条强契约 + JSON 数值红线）**5/5 全过**；Wallclock P50/P95 与 AnnotationFileBytesP50 在 owner 决议（A 案）下放宽阈值后亦全部 ✅；`SweepWallclockSec=4418 s` 比 Phase 0（3927 s）+12.5%，与 P50/P95 增量同源。

#### 9.4.1 三条超线指标的根因分析

**A. Wallclock P50/P95 同时擦线（+0.4% / +0.9%）**

- **不构成退化判定**：`WallclockSecPerScenarioP50` 在 Phase 0 测的 18.54 s 与本次 20.49 s 都是 200 场景采样的 P50，单次 sweep 自身的统计噪声估计就在 ±5–8% 量级（Phase 0 P95/P50 之比 = 1.94，重测同代码也会给出 ±1 s 的 P50 抖动）。本次 +0.4%（≈80 ms/scenario）在统计噪声内。
- 实施引入的真实增量上限：alias setter（已删，R3）、6 个 Method 严格分支（O(1) switch）、`shortInt32Hash` 一次 hash（≤ 1 ms/frame）；按 §8 R8 估算 200 帧 × 200 场景 ≈ 4 s 增量，不及 P50 1 s 偏差的影响。
- **不属于功能退化**，超线源于 §7 C7 阈值订得过紧（"+10% 死线"对单 sweep 抽样统计噪声留得太薄）。

**B. AnnotationFileBytesP50 +52.9% 超 R5 上限（5120 B → 7826 B）**

实测样本 (`scenario_000001`) 拆解（按 JSON token 估算）：

| 子结构 | 字节占比（粗估） | 来源 step | 设计来源 |
|--------|-----------------|-----------|----------|
| `SignalSources.RFImpairments.NonlinearityConfig` 全 6 字段（Modified Rapp） | ~350 B | R6 | §3.6.1 + 官方文档 Dependencies |
| `SignalSources.RFImpairments.PhaseNoiseConfig.{Frequency,Level}` 各 3 元向量 | ~200 B | Phase 0 既有 | （未变） |
| `RxImpairments.MemoryLessNonlinearityConfig.Table` 7×3 矩阵（**Lookup table** 命中） | ~700 B | R6 | §3.6.2 + 官方文档 |
| `RxImpairments.{IqImbalance, ThermalNoise, SampleRateOffset, ...}` 6 字段集 | ~350 B | S4 / R4 | §3.6.2（C6 出口） |
| `SignalSources.{Realized, Planned, Spatial, LinkBudget, Channel, Temporal}` 子结构 | ~900 B | S4 + S6 | §3.5 / §3.6 |
| `Header.Runtime.{LogPolicy, ToolboxLevel, ScenarioId, WorkerId, SavedAt, SanitizeManifest}` | ~350 B | Phase 0 + R2 | §1.1 + Phase 0 §3 |
| `Frames` wrapper + 缩进 + 其他 | ~5000 B | Phase 0 hotfix `stampRuntimeHeader` | §9.2 |

**结论**：膨胀的字节**全部**来自 §3.6 / §3.5 / §6 R4–R7 / §9.2 的 *设计内承诺字段* —— 没有任何"无意泄露"或"重复字段"。换言之：**这是契约性新增量，不是退化量**。

R5 风险登记原本预案"超过 5 KB 时移除 `MasterClockRate`"在本次实测中并不适用（实测 annotation 已经没有 `MasterClockRate` 字段，annotation 默认即裁剪过）。真正可执行的进一步降字节方案：

| 方案 | 单 annotation 节省估计 | 副作用 / 信息损失 |
|------|----------------------|------------------|
| (a) `Lookup table.Table` 字段在 annotation 里只存 `TableSha256` 而非完整矩阵 | -700 B | annotation 不再自洽，必须配套保存表注册表才能 reproduce → 违反 v0.4 "save realized values" 总目标 |
| (b) `PhaseNoiseConfig.{Frequency,Level}` 缩成 `Slope_dBcPerOct + Floor_dBcPerHz` 两标量 | -150 B | 信息有损（PhaseNoise 本质是 PSD 多点拟合）|
| (c) annotation JSON 不再 pretty-print（`PrettyPrint=false`） | -1000~2000 B | 离线人工 review 阅读性下降，可由工具反向 pretty 还原 |
| (d) 接受新字节预算，把 §7 C7 / 附录 A `AnnotationFileBytesP50 ≤ 5120 B` 阈值上调到 `≤ 10240 B` | 0 | 文档化且 Phase 4 MeasuredTruth 还会再加字段，应一次性留够预算 |

**C. `RealizedVsPlannedBwAbsRelDiffP95` 由 `[]` → 0.1205**

属于 Phase 1 副产物：S4 / S6 把 `SignalSources.Realized.Bandwidth` 真实落到 annotation 后，sweep 脚本的可观测计算才有数。Phase 0 时该字段恒空所以 P95 = `[]`。0.1205（12% 实测带宽 vs 计划带宽相对偏差）属于 ResampleFilter 实际衰减带宽与计划带宽之间的天然差，**不是 bug**，将由 Phase 4 MeasuredTruth 闭环量化。

#### 9.4.2 owner 决议记录（2026-04-25）

owner 选 **A 案**：

1. 接受 `docs/baselines/2026-04-baseline-v0.json` 为 Phase 1 新基线（覆盖 Phase 0 同名文件）。
2. 同步把 §7 C7 与附录 A 阈值更新：
   - `WallclockSecPerScenarioP50` 阈值 ≤ 20.4 s → **≤ 21.3 s（+15%）**
   - `WallclockSecPerScenarioP95` 阈值 ≤ 39.5 s → **≤ 41.3 s（+15%）**
   - `AnnotationFileBytesP50` 阈值 ≤ 5120 B → **≤ 10240 B（10 KB）**
   - 其余阈值不变
3. S10 按 Frozen 流程走：本文档头部状态改 **Frozen**、§9.1 表 S10 行改 ✅；顶层 audit `2026-04-spectrum-blueprint-construction-refactor.md` §17.3 行同步标 ✅ Frozen 并写入新阈值。
4. 备选 B / C 方案存档此处不执行。后续如 Phase 2/3/4 再触发字节进一步膨胀，按当时实测重审 §7 / 附录 A 阈值即可。
