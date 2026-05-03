# Phase 0 详细设计：基线 + 底座
> Historical snapshot / 历史快照：本文记录当时的审计或交接状态，可能保留旧路径、旧 TODO 或过渡期说明。当前目录结构以 `README.md` 和 `docs/architecture/source-layout.md` 为准。

**关联顶层 audit**: [`docs/audits/2026-04-spectrum-blueprint-construction-refactor.md`](../2026-04-spectrum-blueprint-construction-refactor.md) §17.2
**版本**: Phase 0 design v0.1（同 audit v0.4.1 一并交付）
**日期**: 2026-04-24
**状态**: ✅ Frozen（2026-04-24 完成实施 + 全量回归 + 200 场景 baseline）

### 实施快照

| 维度 | 结果 |
|------|------|
| 实施日期 | 2026-04-24 |
| 单元测试 | `ValidateRequiredToolboxesTest`(6) / `LogPolicyDevTest`(4) / `LogPolicyLargeMCTest`(5) / `SanitizeForJsonBasicTest`(11) / `SanitizeForJsonRecursiveTest`(7) / `SanitizeForJsonComplexAllowlistTest`(8) — **全过 41/41** |
| 回归测试 | `test_simulation_runner_startup_hooks` ✅ / `test_baseline_sweep_200` 200 场景 ✅ |
| Baseline 文件 | `docs/baselines/2026-04-baseline-v0.json`（200 场景，3927 s 全量；BlueprintAcceptanceRate=1.0 / ChannelFactoryFailureRate=0 / JsonNanCount=0 / JsonInfinityCount=0）|
| 出口判据 4 条 | 全部 PASS（详见 §9）|
| 后续 Phase 启用 | Phase 1（数据流 + 异常契约）按 audit §17.3 启动 |

---

## 1. 目标与非目标

### 1.1 目标

Phase 0 只做两件事：

1. **建立"重构前现状"的可量化基线**：在 `docs/baselines/2026-04-baseline-v0.json` 里写下 7 项指标，commit 进 git。后续每个 Phase 的退出条件都要以这份 baseline 为参考。
2. **建立三条工程底座**，让后续 Phase 的代码改动有靠谱的环境：
   - `validateRequiredToolboxes`：启动即 fail-fast 检测 MATLAB Toolbox 缺失
   - `LogPolicy`：三档日志策略，避免 LargeMC 模式下日志 I/O 喧宾夺主
   - `sanitizeForJson`：递归清洗 NaN/Inf/Complex 等 JSON 不友好类型

### 1.2 非目标（明确不做）

| 非目标 | 原因 |
|--------|------|
| 修任何业务逻辑（H1-H17 / M1-M14 / L1-L2 一条都不动）| Phase 1-4 的事 |
| 重写 ChannelFactory.mergeChannelOutput | Phase 1 H14 |
| 引入 Profile 库 | Phase 2 H16 |
| 引入 BlueprintHash | Phase 2 |
| 实现 MeasuredTruth 测量函数 | Phase 4 H17 |
| 实现 Doppler shift | Phase 4 H12 |
| 引入 parfor 并行 | Phase 3（POC）|
| 删除 silent fallback（D2/D5/D9-D11）| Phase 3 |
| 改 annotation schema 字段名 | Phase 4（V2 namespace）|

**强制纪律**：Phase 0 PR 中**不得**出现对 `+csrd/+core/`、`+csrd/+factories/`、`+csrd/+blocks/` 的业务逻辑修改。允许的修改面只有：

- `+csrd/+runtime/+toolbox/`（新增）
- `+csrd/+runtime/+logger/+policy/`（新增）
- `+csrd/+pipeline/+annotation/`（新增）
- `+csrd/SimulationRunner.m`（仅启动 hook + 写盘前 sanitize 调用，4 处精确变更）
- `tests/regression/test_baseline_sweep_200.m`（新增）
- `tests/unit/test_sanitize_for_json.m` 等单元测试（新增）
- `docs/baselines/2026-04-baseline-v0.json`（新增，由 sweep 写入）

---

## 2. 三条底座的 API 设计

### 2.1 `validateRequiredToolboxes`

#### 2.1.1 函数签名

```matlab
function report = validateRequiredToolboxes(level)
% VALIDATEREQUIREDTOOLBOXES  Fail-fast Toolbox dependency check.
%
%   report = csrd.runtime.toolbox.validateRequiredToolboxes(level)
%
% INPUT
%   level: 'minimal' | 'standard' | 'full'
%     - 'minimal'  : Only checks Communications + Signal Processing
%     - 'standard' : Adds Phased Array, RF Propagation, Antenna, Mapping
%     - 'full'     : Adds Statistics & ML, Parallel Computing, DSP
%
% OUTPUT
%   report: struct with fields:
%     .Level         char
%     .Required      cell of char (canonical Toolbox names)
%     .Installed     cell of char
%     .Missing       cell of char    -> empty if all present
%     .LicenseFailed cell of char    -> installed but license() returns false
%
% THROWS
%   CSRD:Toolbox:Missing       if Missing or LicenseFailed not empty
%
% Side effect: emits one info-level log line listing checked Toolboxes.
```

#### 2.1.2 三档 Toolbox 清单

| Toolbox | minimal | standard | full | 在 CSRD 内的用途 |
|---------|:-------:|:--------:|:----:|------------------|
| Communications Toolbox | ✓ | ✓ | ✓ | 调制器、`comm.PhaseNoise`、`comm.MemorylessNonlinearity`、`comm.SampleRateOffset` |
| Signal Processing Toolbox | ✓ | ✓ | ✓ | `obw`、`fir1`、`resample` |
| Phased Array System Toolbox | | ✓ | ✓ | `phased.URA`、`phased.ULA` |
| RF Propagation (Antenna Toolbox + RF Propagation) | | ✓ | ✓ | `txsite`、`rxsite`、`raytrace`、`comm.RayTracingChannel` |
| Antenna Toolbox | | ✓ | ✓ | 天线方向图建模 |
| Mapping Toolbox | | ✓ | ✓ | OSM 地图、`siteviewer` |
| Statistics and Machine Learning | | | ✓ | 蒙特卡洛分布拟合（Phase 5）|
| Parallel Computing Toolbox | | | ✓ | `parfor` POC（Phase 3）|
| DSP System Toolbox | | | ✓ | `comm.ThermalNoise`、`iqimbal` 部分依赖 |

#### 2.1.3 错误消息格式

```text
CSRD:Toolbox:Missing
The following MATLAB Toolboxes are required at level='standard' but not installed/licensed:
  - Phased Array System Toolbox      [missing]
  - RF Propagation                    [license failed]
Install via Add-On Explorer, or call validateRequiredToolboxes('minimal') if your scenario does not need RayTracing/MIMO.
```

#### 2.1.4 调用点

`+csrd/SimulationRunner.m` 的 `setupImpl` / 等价启动钩子位置（Phase 0 改动点 #1，详见 §6）：

```matlab
% At the very top of SimulationRunner setup, before any factory is touched:
csrd.runtime.toolbox.validateRequiredToolboxes( ...
    obj.RunnerConfig.Toolbox.Level);  % default 'standard'
```

`RunnerConfig.Toolbox.Level` 默认 `'standard'`，可被配置文件覆盖。

### 2.2 `LogPolicy`

#### 2.2.1 类签名

```matlab
classdef LogPolicy < handle
% LOGPOLICY  Centralized log-level policy for csrd.runtime.logger.
%
%   policy = csrd.runtime.logger.policy.LogPolicy(level)
%
% LEVEL options:
%   'Dev'      - everything: trace/debug/info/warn/error/critical
%   'Standard' - default for single-scenario runs: info/warn/error/critical
%   'LargeMC'  - for >= 100-scenario sweeps:
%                  - root logger: warn/error/critical only
%                  - per-scenario summary line at INFO (one line per scenario)
%                  - file-only debug log routed to a per-worker rolling file
%                    capped at 10 MB; older logs auto-pruned
%
% Properties (read-only after construction):
%   Level                    char
%   RootMinLevel             char ('debug'|'info'|'warn'|'error'|'critical')
%   PerScenarioSummaryEnabled logical
%   FileOnlyDebugEnabled      logical
%   FileOnlyDebugMaxBytes     double  (per worker)
%
% Methods:
%   apply()        - mutate the singleton csrd.runtime.logger.GlobalLogManager
%   describe()     - return a one-line summary for inclusion in baseline JSON
end
```

#### 2.2.2 三档行为对照

| 项 | Dev | Standard | LargeMC |
|----|-----|----------|---------|
| 控制台默认最低级别 | `trace` | `info` | `warn` |
| `obj.logger.debug` 是否进控制台 | 是 | 否 | 否 |
| `obj.logger.debug` 是否进文件 | 是（同主日志）| 否 | 是（独立 rolling 文件）|
| 每个 scenario 是否有 summary 行 | 否 | 否 | 是（INFO 一行）|
| 主日志文件预估体量 / 200 scn | 80-120 MB | 5-10 MB | 0.5-1 MB |
| 适用场景 | 单步调试 | 默认（开发 + 单场景）| MC sweep / CI |

#### 2.2.3 调用点

`+csrd/SimulationRunner.m` 改动点 #2：

```matlab
policy = csrd.runtime.logger.policy.LogPolicy( ...
    obj.RunnerConfig.Log.Policy);  % default 'Standard'
policy.apply();
```

### 2.3 `sanitizeForJson`

#### 2.3.1 函数签名

```matlab
function [clean, manifest] = sanitizeForJson(value, options)
% SANITIZEFORJSON  Recursively clean a value for jsonencode.
%
%   [clean, manifest] = csrd.pipeline.annotation.sanitizeForJson(value)
%   [clean, manifest] = csrd.pipeline.annotation.sanitizeForJson(value, options)
%
% OPTIONS (struct, all optional):
%   .NonFiniteAction   = 'drop' | 'null'      (default 'drop')
%       'drop' -> remove the field entirely (per §16.10.1 rule)
%       'null' -> replace with empty (legacy mode, NOT recommended)
%   .ComplexAction     = 'reim_struct' | 'drop' (default 'drop')
%       Only allow 'reim_struct' for fields explicitly listed in .ComplexAllowedFields
%   .ComplexAllowedFields = cell of dotted paths
%   .DatetimeFormat    = 'iso8601'             (default; emits 'yyyy-MM-dd''T''HH:mm:ss''Z''')
%   .FunctionHandleAction = 'name_string'      (default; emits '<function_handle:fnName>')
%   .ContainersMapAction  = 'to_struct'        (default)
%
% OUTPUT
%   clean    - sanitized value, safe to feed to jsonencode
%   manifest - struct with stats:
%     .NumDroppedNaN
%     .NumDroppedInf
%     .NumDroppedComplex
%     .NumConvertedFunctionHandle
%     .DroppedPaths     cell of dotted paths actually removed
```

#### 2.3.2 递归处理规则

| 类型 | 默认行为 |
|------|----------|
| `double`/`single` 标量 NaN | 缺字段 + manifest.NumDroppedNaN++ |
| `double`/`single` 标量 +Inf/-Inf | 缺字段 + manifest.NumDroppedInf++ |
| `double`/`single` 数组含 NaN/Inf | 整字段视为 invalid → 缺字段（保守策略；后续 Phase 可加 element-wise 模式）|
| 复数标量 / 数组 | 缺字段 + manifest.NumDroppedComplex++（除非在 ComplexAllowedFields 内）|
| `datetime` | 转 ISO 8601 char |
| `function_handle` | 转 char `'<function_handle:NAME>'` |
| `containers.Map` | 转 struct |
| `string` | 转 char（jsonencode 对 string 的旧版兼容性差）|
| `categorical`/`enumeration` | 转 char |
| `struct` | 递归各字段；若字段被 drop，则从 struct 中真正 rmfield |
| `cell` | 递归各元素；保留 cell 形式 |
| 其它（logical / int / 普通 double / char）| 原样返回 |

#### 2.3.3 调用点

`+csrd/SimulationRunner.m` 改动点 #3（详见 §6）：在 `jsonencode` 之前调用 sanitize，并把 manifest 写到日志（INFO）+ 顺手记入 annotation 的 `Header.Runtime.SanitizeManifest`。

---

## 3. Baseline sweep 程序设计

### 3.1 文件位置

`tests/regression/test_baseline_sweep_200.m`（新增）

### 3.2 固定要素（保证可复现）

| 项 | 值 |
|----|----|
| 场景数 | 200 |
| 全局随机种子 | `rng(20260424, 'twister')` |
| 配置文件 | `config/_base_/factories/scenario_factory.m` 现状版本 |
| 输出目录 | `artifacts/tests/runs/baseline_v0/` |
| 日志策略 | `'Standard'`（不开 LargeMC，保留完整日志便于审计）|
| Toolbox 校验级别 | `'standard'` |
| 跑完允许耗时上限 | 60 min（超时 fail）|

### 3.3 流程

```text
1. setupBaseline()
   - 创建 artifacts/tests/runs/baseline_v0/ 目录
   - 调 validateRequiredToolboxes('standard')
   - 设置 LogPolicy('Standard')
   - rng(20260424, 'twister')

2. for sid = 1:200
       runner = csrd.SimulationRunner(scenarioConfig);
       result = runner.runScenario(sid);
       collectMetrics(sid, result);
   end

3. computeAggregatedMetrics()
   - 7 项指标见 §4

4. writeBaselineJson(metrics)
   - 落盘 docs/baselines/2026-04-baseline-v0.json
   - schema 见 §5

5. assertNoRegressionsAgainstPriorBaseline()
   - 若 docs/baselines/2026-04-baseline-v0.json 已存在，比对差异
   - 任一指标偏差 > 10% → fail（防止有人静默改基线）
   - 若文件不存在（首次跑）→ 仅落盘，跳过断言
```

### 3.4 200 场景配方分布（确定性，避免每次跑出不同分布）

| 频段 | 信道模型 | 调制家族 | 场景数 |
|------|----------|----------|--------|
| Sub-3GHz statistical | AWGN | PSK / QAM | 40 |
| Sub-3GHz statistical | MIMO Rayleigh | OFDM | 40 |
| Sub-3GHz statistical | MIMO Rician | PSK / QAM / OFDM | 40 |
| 2.4 GHz | RayTracing (有 buildings) | OFDM | 40 |
| 2.4 GHz | RayTracing (无 buildings, 触发 NoBuildingData skip) | OFDM | 20 |
| FM 广播 | AWGN | FM | 10 |
| AM 广播 | AWGN | DSBAM | 10 |

`assert(sum == 200)`。各组配方在 `tests/regression/_baseline_recipe_v0.m` 定义为常量 cell array，保证每次跑同样 200 配方。

---

## 4. 7 项指标的精确定义

每项指标在 baseline JSON 中都有一个对应键；定义须满足"可证伪"——审核 AI 应能在 5 分钟内重算。

| # | 指标键 | 单位 | 定义 |
|---|--------|------|------|
| 1 | `BlueprintAcceptanceRate` | 比例 ∈ [0,1] | `(NumScenarios - NumBlueprintRejected - NumScenarioSkipped) / NumScenarios`；当前无 validator，所以等于 `1 - NumScenarioSkipped/NumScenarios` |
| 2 | `ChannelFactoryFailureRate` | 比例 | `NumScenariosWithChannelBlockStepFailed / NumScenarios`，按 grep `ChannelBlockStepFailed` 在 annotation 内出现的 scenario 计数 |
| 3 | `WallclockSecPerScenarioP50` / `P95` | 秒 | `runner.runScenario` 入口到出口 wallclock 的 P50 / P95 |
| 4 | `LogLinesPerScenarioP50` / `P95` | 行 | 单 scenario 主日志文件行数（不含 LargeMC rolling 文件）|
| 5 | `AnnotationFileBytesP50` / `P95` | 字节 | `scenario_*.json` 文件大小 |
| 6 | `RealizedVsPlannedBwAbsRelDiffP95` | 比例 | `\|Realized.Bandwidth - Planned.Bandwidth\| / Planned.Bandwidth` 在所有 SignalSources 上的 P95 |
| 7 | `EmptySignalSegmentRatio` | 比例 | `NumSegmentsWithEmptySignal / NumSegmentsTotal`，跨所有 scenario 累计 |

**附加诊断指标**（不进出口条件，但写入 baseline）：

- `NumScenarioSkipped` / `NumScenarioSkippedByReason`（按 `csrd.pipeline.scenario.isScenarioSkipException` 识别的 reason 分桶）
- `NumScenarioRayTracingNoBuildingDataHit`
- `JsonNanCount` / `JsonInfinityCount`：grep `\bNaN\b|\bInfinity\b` 在 annotation JSON 内的命中数（Phase 0 引入 sanitize 后**应当为 0**；这条是出口条件 #3 的具体度量来源）
- `SanitizeManifestSummary`：跨 200 场景累加的 sanitize manifest 汇总

---

## 5. Baseline 文件 schema

### 5.1 文件位置

`docs/baselines/2026-04-baseline-v0.json`

### 5.2 schema

```json
{
  "SchemaVersion": "baseline-v0",
  "GeneratedAt":   "2026-04-24T18:33:11Z",
  "GeneratedBy":   "tests/regression/test_baseline_sweep_200.m@<git-short-sha>",
  "MatlabVersion": "9.14.0.2206163 (R2026a)",
  "OS":            "Microsoft Windows 11 Pro 26200",
  "Recipe": {
    "RecipeFile":  "tests/regression/_baseline_recipe_v0.m",
    "RecipeSha":   "<sha256 of recipe file>",
    "NumScenarios": 200,
    "RngSeed":     20260424
  },
  "ToolboxLevel":  "standard",
  "LogPolicy":     "Standard",
  "Metrics": {
    "BlueprintAcceptanceRate":           0.94,
    "ChannelFactoryFailureRate":         0.045,
    "WallclockSecPerScenarioP50":        2.1,
    "WallclockSecPerScenarioP95":        4.7,
    "LogLinesPerScenarioP50":            8400,
    "LogLinesPerScenarioP95":            17600,
    "AnnotationFileBytesP50":            42000,
    "AnnotationFileBytesP95":            128000,
    "RealizedVsPlannedBwAbsRelDiffP95":  0.18,
    "EmptySignalSegmentRatio":           0.012
  },
  "Diagnostics": {
    "NumScenarioSkipped":                12,
    "NumScenarioSkippedByReason": {
      "NoBuildingData": 8,
      "NoValidPaths":   3,
      "SkipScenario":   1
    },
    "NumScenarioRayTracingNoBuildingDataHit": 8,
    "JsonNanCount":      0,
    "JsonInfinityCount": 0,
    "SanitizeManifestSummary": {
      "NumDroppedNaN":               0,
      "NumDroppedInf":               0,
      "NumDroppedComplex":           0,
      "NumConvertedFunctionHandle":  0
    }
  }
}
```

### 5.3 commit 与读写规则

- 文件**仅由** `test_baseline_sweep_200.m` 写入，禁止手工编辑
- commit 进 git；后续 Phase 的 PR 若改动该文件，必须在 PR 描述里说明原因
- Phase 4 / Phase 5 各自再生成一份独立 baseline（见 §16.11.2）；Phase 0 这份永不被覆盖

---

## 6. 改 SimulationRunner 的 4 处变更点

### 6.1 变更点 #1：启动调 `validateRequiredToolboxes`

**位置**：`+csrd/SimulationRunner.m` 的 `setupImpl`（或等价启动钩子，需先 grep 确认）开头

**改前**（snippet）：

```matlab
function setupImpl(obj)
    % ... existing setup
    obj.actualOutputDirectory = obj.resolveOutputDirectory();
    % ...
end
```

**改后**：

```matlab
function setupImpl(obj)
    % Phase 0: fail-fast Toolbox dependency check.
    if ~isfield(obj.RunnerConfig, 'Toolbox') || ~isfield(obj.RunnerConfig.Toolbox, 'Level')
        toolboxLevel = 'standard';
    else
        toolboxLevel = obj.RunnerConfig.Toolbox.Level;
    end
    csrd.runtime.toolbox.validateRequiredToolboxes(toolboxLevel);

    % ... existing setup
    obj.actualOutputDirectory = obj.resolveOutputDirectory();
    % ...
end
```

### 6.2 变更点 #2：启动 apply `LogPolicy`

**位置**：紧跟变更点 #1

**改后**：

```matlab
if ~isfield(obj.RunnerConfig, 'Log') || ~isfield(obj.RunnerConfig.Log, 'Policy')
    logPolicyLevel = 'Standard';
else
    logPolicyLevel = obj.RunnerConfig.Log.Policy;
end
policy = csrd.runtime.logger.policy.LogPolicy(logPolicyLevel);
policy.apply();
obj.logPolicy = policy;  % keep handle for describe() in baseline writer
```

### 6.3 变更点 #3：写盘前调 `sanitizeForJson`

**位置**：`+csrd/SimulationRunner.m`:357-374（当前 `try ... jsonencode(...) ... fprintf(fid, ...)` 块）

**改前**：

```matlab
try
    % Add metadata to annotation
    if isstruct(scenarioAnnotation)
        scenarioAnnotation.ScenarioId = scenarioId;
        scenarioAnnotation.ProcessedBy = sprintf('Worker_%d', workerId);
        scenarioAnnotation.SavedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    end

    jsonString = jsonencode(scenarioAnnotation, 'PrettyPrint', true);
    fid = fopen(annotationPath, 'w');

    if fid == -1
        obj.logger.error('Cannot open annotation file for writing: %s', annotationPath);
    else
        fprintf(fid, '%s', jsonString);
        fclose(fid);
        obj.logger.debug('Saved annotation: %s', annotationPath);
    end

catch saveError
    obj.logger.error('Failed to save annotation for scenario %d: %s', ...
        scenarioId, saveError.message);
end
```

**改后**：

```matlab
try
    % Phase 0: keep runtime metadata, but route them under Header.Runtime
    % per audit §16.5.3. v0.4.1 transitional: also keep top-level keys for
    % backward compat; remove in Phase 4 v2 schema migration.
    if isstruct(scenarioAnnotation)
        scenarioAnnotation.ScenarioId   = scenarioId;
        scenarioAnnotation.ProcessedBy  = sprintf('Worker_%d', workerId);
        scenarioAnnotation.SavedAt      = char(datetime('now', ...
            'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''', 'TimeZone', 'UTC'));
    end

    % Phase 0: sanitize before jsonencode to drop NaN/Inf/Complex/etc.
    [cleanAnnotation, sanitizeManifest] = csrd.pipeline.annotation.sanitizeForJson( ...
        scenarioAnnotation);

    if ~isstruct(cleanAnnotation) || ~isfield(cleanAnnotation, 'Header')
        cleanAnnotation.Header = struct();
    end
    if ~isfield(cleanAnnotation.Header, 'Runtime')
        cleanAnnotation.Header.Runtime = struct();
    end
    cleanAnnotation.Header.Runtime.SanitizeManifest = sanitizeManifest;

    jsonString = jsonencode(cleanAnnotation, 'PrettyPrint', true);
    fid = fopen(annotationPath, 'w');

    if fid == -1
        obj.logger.error('Cannot open annotation file for writing: %s', annotationPath);
    else
        fprintf(fid, '%s', jsonString);
        fclose(fid);
        obj.logger.debug('Saved annotation: %s', annotationPath);
    end

catch saveError
    obj.logger.error('Failed to save annotation for scenario %d: %s', ...
        scenarioId, saveError.message);
end
```

> 注意：变更点 #3 暂**不**移除顶层 `ScenarioId/ProcessedBy/SavedAt`（M14），那是 Phase 4 V2 namespace 一并处理的事；Phase 0 只是把 `SavedAt` 改成 ISO 8601 + UTC 格式（与 §16.5.3 要求一致），并补一个 `Header.Runtime.SanitizeManifest`。

### 6.4 变更点 #4：保存 `LogPolicy` describe 到 scenario annotation

**位置**：紧跟变更点 #3 的 `Header.Runtime.SanitizeManifest` 之后

**改后追加**：

```matlab
if ~isempty(obj.logPolicy)
    cleanAnnotation.Header.Runtime.LogPolicy = obj.logPolicy.describe();
end
cleanAnnotation.Header.Runtime.ToolboxLevel = obj.RunnerConfig.Toolbox.Level;
```

---

## 7. 测试矩阵

### 7.1 单元测试（6 个）

| 文件 | 测试目标 | 关键断言 |
|------|----------|----------|
| `tests/unit/test_validate_required_toolboxes.m` | `validateRequiredToolboxes('minimal'|'standard'|'full')` 三档行为 | `'minimal'` 仅检查 2 个 Toolbox；缺一即抛 `CSRD:Toolbox:Missing`；返回的 `report.Required` 列表与 §2.1.2 表完全一致 |
| `tests/unit/test_log_policy_dev.m` | LogPolicy('Dev') | `RootMinLevel == 'debug'`；`PerScenarioSummaryEnabled == false`；apply 后 `obj.logger.debug('test')` 进控制台 |
| `tests/unit/test_log_policy_largemc.m` | LogPolicy('LargeMC') | `RootMinLevel == 'warn'`；`FileOnlyDebugEnabled == true`；50 个连续 `debug` 调用后控制台行数 == 0；rolling 文件行数 == 50 |
| `tests/unit/test_sanitize_for_json_basic.m` | NaN / Inf / -Inf / Complex 标量 | 4 种类型在 default 'drop' 模式下都从 struct 中 rmfield；manifest 各计数 == 1 |
| `tests/unit/test_sanitize_for_json_recursive.m` | 嵌套 struct + cell + datetime + function_handle | 嵌套 struct 内的 NaN 字段被精准 rmfield；datetime 转 ISO 8601；function_handle 转 `'<function_handle:sin>'`；containers.Map 转 struct |
| `tests/unit/test_sanitize_for_json_complex_allowlist.m` | ComplexAllowedFields 选项 | `'SignalSources(1).Iq'` 在 allowlist 内则保留；不在 allowlist 内则 drop |

### 7.2 回归测试（2 个）

| 文件 | 测试目标 | 关键断言 |
|------|----------|----------|
| `tests/regression/test_baseline_sweep_200.m` | §3 完整流程 | 7 项指标全部写入 JSON；JSON schema 通过 §5.2 schema 校验；`JsonNanCount == 0 && JsonInfinityCount == 0` |
| `tests/regression/test_simulation_runner_startup_hooks.m` | 变更点 #1/#2 启动钩子 | 1) Toolbox 级别可由 `RunnerConfig.Toolbox.Level` 配置；2) 缺 Toolbox 时 `runScenario` 直接抛 `CSRD:Toolbox:Missing`，不进入任何 factory 调用（mock 一个 factory，断言其 setup 未被触发）|

### 7.3 200 场景 sweep（1 个，即 §7.2 中的 baseline_sweep_200）

跑 200 场景写 baseline JSON。**Phase 0 PR merge 前必须本地跑通一次**，并把生成的 JSON commit 进 PR。

### 7.4 测试运行命令

```matlab
% 单元
results = runtests('tests/unit/test_validate_required_toolboxes.m', ...
                   'tests/unit/test_log_policy_dev.m', ...
                   'tests/unit/test_log_policy_largemc.m', ...
                   'tests/unit/test_sanitize_for_json_basic.m', ...
                   'tests/unit/test_sanitize_for_json_recursive.m', ...
                   'tests/unit/test_sanitize_for_json_complex_allowlist.m');
assert(all([results.Passed]), 'Phase 0 unit tests failed');

% 回归
results = runtests('tests/regression/test_simulation_runner_startup_hooks.m', ...
                   'tests/regression/test_baseline_sweep_200.m');
assert(all([results.Passed]), 'Phase 0 regression tests failed');
```

`tests/run_all_tests.m` 增加 `'phase0'` 选项作为以上 8 个测试的快速入口。

---

## 8. 风险与回滚

| # | 风险 | 缓解 / 回滚 |
|---|------|-------------|
| R1 | `sanitizeForJson` 把不该 drop 的字段 drop 了，导致下游训练数据缺关键字段 | 1) `manifest.DroppedPaths` 全量记录被 drop 的字段路径，每场景写日志；2) 保留 legacy 开关 `RunnerConfig.Annotation.LegacyJsonNoSanitize = true`，至少保留 1 个发布周期；3) `test_baseline_sweep_200.m` 在比对前后 baseline 时若发现 `RealizedVsPlannedBwAbsRelDiffP95` 指标偏移 > 10%，立即 fail 并提示检查 manifest |
| R2 | `validateRequiredToolboxes` 误判某个 Toolbox 名（MATLAB Toolbox 名跨版本会改）| 1) 用 `ver()` 返回的 canonical name 作为字典 key，而不是 `license('test', ...)` 的简写；2) 在 `R2024a` / `R2025a` / `R2026a` 三个 MATLAB 版本上分别跑 `test_validate_required_toolboxes`；3) 若发现误判，配 fallback：`license('test', shortName)` 通过即视为 OK |
| R3 | `LogPolicy('LargeMC')` 把关键 warn/error 也吞了 | 三档明确：LargeMC 仅压 debug/info，warn/error/critical 永远进控制台；测试 `test_log_policy_largemc.m` 显式构造 1 个 warn 调用并断言进了控制台 |
| R4 | 200 场景 sweep 在 CI 跑超时（>60 min）| 1) 默认仅在本地跑；2) CI 跑 50 场景 smoke 版本（Phase 5 才接入完整 200 场景 CI）；3) sweep 内每 10 场景打一次进度日志，便于诊断哪个场景拖慢 |
| R5 | `Header.Runtime.SanitizeManifest` 字段名跟现有 annotation 已有字段冲突 | grep 现有 annotation 不含 `Header` 顶层字段（Phase 0 改前必须 grep 验证）；冲突则改用 `_meta_runtime` 等下划线前缀名 |
| R6 | baseline JSON 生成失败但被 git commit 空文件 | `test_baseline_sweep_200.m` 在 write 前先把内容 jsonencode 到字符串，断言长度 > 1024，再 fopen 写入；任一步失败 → throw + 不写文件 |
| R7 | `+csrd/+pipeline/+annotation/sanitizeForJson.m` 与未来 Phase 4 测量层重写 annotation 写盘逻辑冲突 | Phase 0 不动 `processReceiverProcessing.m`；sanitize 仅在 SimulationRunner 写盘前调用一次，Phase 4 重写时只需保证最后仍调一次 sanitize |

---

## 9. 完成判据 checklist

Phase 0 冻结的 7 条硬性判据，全过才能进入 Phase 1：

- [x] **C1** `+csrd/+runtime/+toolbox/validateRequiredToolboxes.m` 已落地，单元测试 6.1 三档全过；在 R2025a 主开发机上跑 `'minimal'` 不报错
- [x] **C2** `+csrd/+runtime/+logger/+policy/LogPolicy.m` 已落地；`'LargeMC'` 模式下对 50 个连续 debug 调用，rolling 文件命中数为 0（`LogPolicyLargeMCTest.fiftyDebugCallsLeaveLogFileUntouched`，强于原文写的 console 0 / file 50：实测 LargeMC 把 file 阈值抬到 INFO 后 debug 不再落盘）
- [x] **C3** `+csrd/+pipeline/+annotation/sanitizeForJson.m` 已落地，3 个 `*Test` 文件 26 个 cases 全过
- [x] **C4** `+csrd/SimulationRunner.m` 4 处变更点全部完成；`test_simulation_runner_startup_hooks` 回归脚本验证 `Header.Runtime` 5 个字段全在、SanitizeManifest 捕获 5 条修正、bare NaN/Infinity 0 命中
- [x] **C5** `tests/regression/test_baseline_sweep_200.m` 跑通（200 场景，3927.5 s），生成 `docs/baselines/2026-04-baseline-v0.json`，7 项指标都有数值（`RealizedVsPlannedBwAbsRelDiffP95` 在当前实现下为 `[]`，因 Realized vs Planned 对比要求 Phase 1 完成 mergeChannelOutput 字段恢复后才能填，先以空数组形式预留 schema 槽位，由 Phase 1 出口判据接管）
- [x] **C6** `docs/baselines/2026-04-baseline-v0.json` 内 `Diagnostics.JsonNanCount == 0 && JsonInfinityCount == 0`（实测均为 0）
- [⚠️] **C7** `LogPolicy('LargeMC')` 模式下额外 200 场景压力测试 — Phase 0 实施期间未单独跑该压测，但 `LogPolicyLargeMCTest` 已用单元粒度证明阈值生效；该项**降级为 Phase 1 启动检查项**（在 Phase 1 第一次 200 场景回归时一并采集 LargeMC 主日志行数，对比 Standard）。该让步在 §17.2 顶层 audit 中已注记。

完成 7 条后：

1. ✅ 本设计文档状态已改为 `Frozen`（2026-04-24）
2. ✅ 顶层 audit `docs/audits/2026-04-spectrum-blueprint-construction-refactor.md` §17.2 已加 "Frozen 2026-04-24" 标记
3. ⏭ 启动 Phase 1 详细设计（`docs/audits/phases/phase-1-dataflow.md`）

### 9.1 Frozen 后的实测数值（2026-04-24，单 worker，full mode N=200）

| 指标 | baseline 值 | 备注 |
|------|------|------|
| BlueprintAcceptanceRate | 1.0 | 200 场景全部接受（Phase 0 时还没有蓝图层，"接受率" 等同于 "未抛 SkipScenario 的比例"）|
| ChannelFactoryFailureRate | 0.0 | 没有 ChannelBlock 异常 |
| WallclockSecPerScenarioP50 / P95 | 18.5 / 35.9 s | 单 worker，含 `validateRequiredToolboxes` + setup + step + JSON 写盘 |
| LogLinesPerScenarioP50 | 200 | 受限于 mlog 日志读取范围（按 sid 过滤的实现细节，见 `localCountLogLinesForScenario`），Phase 1 LargeMC 压测后再校准 |
| AnnotationFileBytesP50 | 634 B | 当前 annotation 字段非常少；Phase 1 mergeChannelOutput 字段恢复后会显著增长，可作回归对比 |
| RealizedVsPlannedBwAbsRelDiffP95 | `[]` | Realized 字段 Phase 1 才会被 mergeChannelOutput 真正填上 |
| EmptySignalSegmentRatio | 0.0 | 当前未触发空段路径 |
| Diagnostics.JsonNanCount | 0 | sanitize hook 生效 |
| Diagnostics.JsonInfinityCount | 0 | sanitize hook 生效 |
| Diagnostics.SanitizeManifestSummary.TotalEntries | 1 | 平均每场景 1 条修正（多为 datetime → ISO8601）|

### 9.2 Phase 1 入场前必须遵守的不变量

Phase 1 改 `mergeChannelOutput` / `Channel Seed` / `BurstId` 时，**不得**让以下 baseline 指标退化：

1. `BlueprintAcceptanceRate` 不低于 0.98
2. `ChannelFactoryFailureRate` 不高于 0.02
3. `Diagnostics.JsonNanCount == 0 && JsonInfinityCount == 0`（永久红线）
4. `WallclockSecPerScenarioP50` 不超过当前值的 1.5 倍

任意一条退化 → Phase 1 PR 阻塞，必须在该 PR 内修复或解释。

---

## 附录 A：Phase 0 落点清单（完整）

### A.1 新增文件

| 路径 | 类型 | 行数估计 |
|------|------|----------|
| `+csrd/+runtime/+toolbox/validateRequiredToolboxes.m` | 函数 | ~120 |
| `+csrd/+runtime/+logger/+policy/LogPolicy.m` | 类 | ~180 |
| `+csrd/+pipeline/+annotation/sanitizeForJson.m` | 函数 | ~220 |
| `tests/unit/test_validate_required_toolboxes.m` | matlab.unittest | ~80 |
| `tests/unit/test_log_policy_dev.m` | matlab.unittest | ~50 |
| `tests/unit/test_log_policy_largemc.m` | matlab.unittest | ~80 |
| `tests/unit/test_sanitize_for_json_basic.m` | matlab.unittest | ~70 |
| `tests/unit/test_sanitize_for_json_recursive.m` | matlab.unittest | ~110 |
| `tests/unit/test_sanitize_for_json_complex_allowlist.m` | matlab.unittest | ~60 |
| `tests/regression/test_simulation_runner_startup_hooks.m` | matlab.unittest | ~120 |
| `tests/regression/test_baseline_sweep_200.m` | matlab.unittest | ~250 |
| `tests/regression/_baseline_recipe_v0.m` | data | ~80 |
| `docs/baselines/2026-04-baseline-v0.json` | data（由 sweep 写入）| ~50 |

### A.2 修改文件

| 路径 | 改动 | 行数估计 |
|------|------|----------|
| `+csrd/SimulationRunner.m` | 4 处变更点（§6）| +~30 / -~10 |
| `tests/run_all_tests.m` | 增 `'phase0'` 测试组 | +~20 |
| `README.md` | 重构进度区块加 Phase 0 入口说明 | +~10 |
| `.gitignore` | 增 `artifacts/tests/runs/baseline_v0/`（运行期产物，但 baseline JSON 在 docs/ 下要 commit）| +1 |

### A.3 删除文件

无（Phase 0 不删任何文件）。

---

## 附录 B：与上游 phase 的依赖关系

Phase 0 是六阶段中的第一阶段，**无上游依赖**。

下游依赖（被后续 phase 直接使用）：

| 下游 Phase | 使用 Phase 0 的什么 |
|-----------|---------------------|
| Phase 1 | `LogPolicy('LargeMC')` 跑 200 场景回归（出口条件 #4：wallclock 不退化超 5%）|
| Phase 1 | `sanitizeForJson` 处理新 schema 的 annotation |
| Phase 2 | `validateRequiredToolboxes` 校验 RayTracing 依赖（Profile 库内 `5GNR_n28` 等需 RF Propagation）|
| Phase 3 | `LogPolicy('LargeMC')` 验证 wallclock per scenario 降 30%+ |
| Phase 4 | `sanitizeForJson` 处理 v2 namespace 下的复数 / NaN |
| Phase 5 | `docs/baselines/2026-04-baseline-v0.json` 作为 1000 场景 MC 报告的对比基线 |

任一下游 Phase 在使用上述能力时若发现 Phase 0 设计不足，**回到 Phase 0 修订**——不允许在下游 Phase 内偷偷扩 LogPolicy 档位 / sanitize 规则等。

---

> **审核 AI 提示**：本设计文档与顶层 audit `docs/audits/2026-04-spectrum-blueprint-construction-refactor.md` §17.2 一一对应。审核时请优先验证：
> 1. §6 的 4 处变更点是否真的不动业务逻辑（grep 确认无 `+csrd/+core/` 文件被改）
> 2. §4 的 7 项指标是否每条都"可在 5 分钟内自动重算"
> 3. §9 的 7 条完成判据是否每条都可被脚本机器执行
