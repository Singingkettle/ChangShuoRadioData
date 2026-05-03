# Phase 5 详细设计 —— 大规模 MC + CI + 收尾硬化

| 字段 | 值 |
|------|----|
| 状态 | **Frozen**（2026-04-27：S1-S10 已完成；final-v04 1000 场景 MC 与 CI smoke 证据已入库）|
| 顶层 audit 引用 | `docs/audits/2026-04-spectrum-blueprint-construction-refactor.md` §17.7 / §17.9 |
| 关联条目 | Phase 0-4 全部出口条件回放 / P5-followup-1..7 / catch-swallow 残留收敛 / annotation v2 工具链收尾 / CI 防回退 |
| 前置 | Phase 0 / 1 / 2 / 3 / 4 已 Frozen；Phase 4 baseline `docs/baselines/2026-04-baseline-v0.json` 为 210 场景 |
| 目标产出 | 1000 场景 MC 报告 / CI smoke hook / 文档状态同步 / 异常契约补洞 / 旧 v1 工具处理 / targeted + full regression 证据 |
| 实测备注 | 完整 1000 场景 MC 为 operator-run 长跑；最终 baseline 通过 `Resume=true` checkpoint/artifact recovery 聚合冻结 |

---

## 0. 工作流契约

1. Phase 5 必须沿用“设计 → 代码 → 覆盖测试 → 设计修订”的闭环。
2. 任一测试暴露设计问题，先回本文件修订设计，再改代码。
3. 不再新增 v1/v2 共存期，不写 annotation v1→v2 迁移工具。
4. 对物理允许的 fallback，必须记录触发条件、实际模型和 annotation/metadata 信号。
5. 对执行期错误，禁止写半损坏 frame；非可恢复错误必须 fail-fast，场景级可跳过错误统一通过 `isScenarioSkipException`。

---

## 1. Phase 5 总目标

Phase 5 不是功能扩张阶段，而是把 Phase 0-4 的重构约束放到更大样本、更严格错误契约和 CI 中固化。

最终目标：

1. 1000 场景 MC 回放 Phase 0-4 全部出口条件。
2. CI smoke 能发现 annotation schema、measurement completeness、silent fallback、Doppler 和 baseline metric 回退。
3. 清理文档与工具链中仍暗示 v1 schema、迁移工具或旧 Planned/Realized 顶层字段的内容。
4. 将代码中仍存在的 catch-swallow / sentinel-error-output 路径收敛为 fail-fast 或显式可审计 fallback。

---

## 2. Measurement 语义澄清

本阶段采用 owner 在 2026-04-26 明确的语义：

- Measurement 不表示“所有 annotation 字段都要从 IQ 反推”。
- Measurement 表示最终 annotation 必须完整记录数据生成过程和最终可观测事实。
- 调制方式、消息类型、设计中心频率、设计带宽等设计事实来自 Blueprint，不需要从 IQ 测量。
- `Truth.Execution.*` 记录施工层真正兑现的参数，例如实际调制带宽、Doppler、信道模型、几何快照、RF impairments。
- `Truth.Measured.*` 只用于那些生成后才知道或可能偏离设计的观测量，例如 occupied bandwidth、spectrum centroid、burst envelope、frequency occupancy、SNR。
- 当设计值与生成后测量值不一致时，不能“修正”其中一方；必须同时保留，并让 downstream 明确知道偏差来源。

这条语义约束优先于命名偏好。后续若发现字段归属不清，先按 `Design / Execution / Measured` 三层语义重新设计，再写代码。

---

## 3. 范围与边界

### 3.1 在范围内

| 编号 | 项目 | 处方 |
|------|------|------|
| P5-1 | Phase 5 设计与状态文档 | 新增本文件；同步 README 与顶层 audit，删除迁移工具叙述 |
| P5-2 | skip 异常契约补洞 | `isScenarioSkipException` 加 `CSRD:Measurement:`；补单测 |
| P5-3 | catch-swallow 残留收敛 | 优先处理 channel propagation / ChannelFactory / receiver processing / frame generation 的半损坏输出路径 |
| P5-4 | annotation v2 工具链收尾 | `tools/convert_csrd_to_coco.m` 不得再默认读 `annotation.rx/tx`；要么升级到 v2，要么明确 fail-fast 不支持 |
| P5-5 | 1000 场景 MC | 基于 Phase 4 baseline recipe 扩展，生成 `docs/baselines/2026-04-final-v04.json` |
| P5-6 | CI smoke | 增加可本地复用的 CI 入口，并提供 workflow hook |
| P5-7 | 性能与稳定性复核 | C8、SNR floor、multi-Rx ratio、RRFSimulator release pattern、parfor 风险登记 |

### 3.2 不在范围内

| 项目 | 理由 |
|------|------|
| v1→v2 annotation 迁移工具 | owner 决议 `A_full_replace`，无共存期 |
| 用旧脚本兼容新 schema | 与“不保留向前兼容”冲突 |
| 为通过 1000 MC 调宽阈值 | 先 profile / 定位原因；阈值调整必须有证据 |
| 将所有设计字段改成测量字段 | 违背 §2 Measurement 语义 |

---

## 4. 事实凭据

Phase 5 启动时发现的事实：

- `README.md` 仍写 Phase 1 为 Next、Phase 2-4 Pending，Phase 5 包含 migration tooling（S2 已修）。
- 顶层 audit §17.7 仍写 `tools/migrate_annotation_v1_to_v2.m` 和迁移 roundtrip 出口条件（S2 已修）。
- `docs/audits/phases/phase-4-measurement.md` 已明确 owner 决议 `A_full_replace`，不做迁移工具。
- `+csrd/+pipeline/+scenario/isScenarioSkipException.m` 文档和 token 列表只有 `CSRD:Annotation:`，缺 `CSRD:Measurement:`（S3 已修）。
- `processChannelPropagation.m` 中非 skip channel error 被记录后继续（S4 已修）。
- `ChannelFactory.m` 中 channel block step 失败会返回带 `Error='ChannelBlockStepFailed'` 的信号结构（S4 已修）。
- `processReceiverProcessing.m` 中 receiver error 会写 `Status='Error'` annotation 继续（S5 已修）。
- `generateSingleFrame.m` 中非 skip frame error 会写 `FrameGenerationFailed` annotation（S5 已修）。
- `tools/convert_csrd_to_coco.m` 仍要求 `meta.annotation.rx` / `meta.annotation.tx`，与 annotation v2 不一致（S6 已改为显式 fail-fast）。

---

## 5. 处方

### 5.1 文档同步

1. README phase table 改为 Phase 0-5 Frozen。
2. README baseline 描述最终改为 1000 场景 Phase 5 final-v04，并保留 Phase 4 canonical sweep 入口。
3. 顶层 audit §17.7 改为“大规模 MC + CI + 收尾硬化”，删除迁移工具。
4. 顶层 audit §17.9 指标改用 v2 schema 名称，不再引用 `Realized.Bandwidth`。

### 5.2 异常契约

1. `CSRD:Measurement:` 加入 skip token。
2. `MeasurementCompletenessHookTest` 增加 `CSRD:Measurement:*` predicate case。
3. 后续新引入的 measurement fail-fast 必须使用该命名空间。

### 5.3 catch-swallow 收敛顺序

优先级从最可能写出假 annotation 的路径开始：

1. `processChannelPropagation`: 非 skip channel error 直接 rethrow，不允许丢失 component 后继续。
2. `ChannelFactory`: generic channel block step error rethrow；不得返回 `ChannelBlockStepFailed` sentinel。
3. `processReceiverProcessing`: receiver chain error rethrow；不得写 `Status='Error'` annotation 作为成功 frame 的一部分。
4. `generateSingleFrame`: 非 skip frame error rethrow；`FrameGenerationFailed` annotation 只能用于明确设计过的测试 stub，不用于生产链路。

每一项都必须配 targeted test，再跑对应 phase/regression selector。

### 5.4 annotation v2 工具链

`tools/convert_csrd_to_coco.m` 当前按 v1 schema 工作。Phase 5 处理选项：

| 选项 | 结论 |
|------|------|
| 升级为 v2 | 首选；从 `Frames[*].SignalSources[*].Truth` 读取调制、时间、频率、带宽、SNR |
| 明确 fail-fast | 可临时接受；脚本开头检测 v2 后抛出 actionable error |
| 保持静默 skip | 禁止 |

首轮先禁止静默旧 schema，后续再做完整 v2 COCO 转换。

### 5.5 1000 场景 MC

Phase 5 canonical MC 采用直接 1000 场景 deterministic sweep，而不是 5 次 200 场景平均。

理由：

- 直接 1000 更能暴露 cohort 组合尾部问题。
- Phase 4 baseline 已是 210 场景，重复 200 平均会弱化极端组合覆盖。
- 最终 baseline 文件应记录完整 recipe hash、随机种子、skip reason 分布和 metric 分位数。

输出文件：

- `docs/baselines/2026-04-final-v04.json`
- `artifacts/tests/runs/baseline_v04_1000/` 下的 operator-run artifacts（git ignored）

#### 5.5.1 Resumable MC 修订（2026-04-27）

1000 场景 full MC 在单机单 worker 下是数小时级任务。2026-04-27 首次 S9 长跑在 `scenario_000713` 附近被外部环境中断，stdout/stderr 没有 MATLAB exception，且未写出 final baseline。这暴露出 Phase 5 原设计缺口：canonical MC 不能只依赖内存中的 `perScenario` 聚合。

修订：

1. `test_baseline_sweep_200` 必须支持 `Resume=true`，能够从既有 `artifacts/tests/runs/<RunLabel>/scenario_*/session_*/annotations/scenario_000001_annotation.json` 恢复已完成场景记录。
2. 恢复记录必须重新计算 annotation bytes、JSON NaN/Inf、log lines、Truth bandwidth metric、Blueprint provenance；wallclock 从 per-scenario log 中解析 `Total simulation time` / `Time: ...s`。
3. 恢复失败或 annotation 不完整的 scenario 不得伪造成功记录，必须重跑该 scenario。
4. 每跑完一个 scenario 追加 checkpoint MAT 文件，避免下一次 resume 必须重新扫描全部 artifacts。
5. Phase 5 wrapper 的 full mode 默认 `Resume=true`；smoke mode 默认 `Resume=false`，避免 smoke 使用旧临时输出。
6. 对 `baseline-v04` final full run，和 `2026-04-baseline-v0.json` 的 10% drift 对比不作为 hard gate；v0 是 210 场景 Phase 4 基线，final-v04 是 1000 场景 + resume-capable operator MC，二者样本规模和运行方式不同。Phase 5 hard gate 直接检查当前 final-v04 的 correctness metrics，drift 留作诊断。

入口：

```matlab
addpath(fullfile(pwd, 'tools', 'phase5'))
run_phase5_mc_validation()
```

该 wrapper 默认执行 1000 场景 full sweep；小规模入口验证必须显式使用 `Mode='smoke'`，并写 `docs/baselines/2026-04-final-v04.smoke.json`，避免误覆盖 canonical final。

### 5.6 CI hook

CI 采用 smoke gate，不跑 1000 场景：

- `run_csrd_static_gates()`
- `run_all_tests('phase4')`
- `run_phase5_mc_validation(12,'Mode','smoke')`
- 静态 grep gate：no v1 SignalSources top-level keys, no forbidden catch-swallow sentinel strings

本地入口：

```matlab
addpath(fullfile(pwd, 'tools', 'ci'))
run_csrd_ci_smoke()
```

GitHub Actions hook：`.github/workflows/csrd-ci-smoke.yml`，默认绑定 self-hosted Windows + MATLAB runner。CI wallclock 目标 30 min 内；若 runner 抖动导致 Phase 4 + MC smoke 超过 30 min，优先 profile/拆 nightly，不调宽物理或 annotation 阈值。完整 1000 MC 作为 release/operator gate，不强塞普通 PR CI。

---

## 6. 测试矩阵

| 层级 | 命令 | 目标 |
|------|------|------|
| 单点契约 | `MeasurementCompletenessHookTest` | Annotation / Measurement skip token |
| 静态回归 | `test_no_dead_code_phase4` | v1 schema 不回流 |
| catch-swallow | 新增/扩展 unit tests | channel / receiver / frame error 不写半损坏 annotation |
| Phase 4 suite | `tests.run_all_tests('phase4')` | Phase 4 主约束不回退 |
| 全量测试 | `tests.run_all_tests('all')` | 60/60 或更新后的全套 PASS |
| MC smoke | `test_baseline_sweep_200(12,'Mode','smoke')` | baseline harness 健康 |
| MC full | `run_phase5_mc_validation()` | 生成 final-v04 baseline |

---

## 7. 实施顺序

| Step | 内容 | 验证 |
|------|------|------|
| S1 | 写本设计文档 | 文档存在，Phase 5 范围明确 |
| S2 | README + audit 状态同步 | grep 无 migration-tool Phase 5 误述 |
| S3 | `CSRD:Measurement:` 白名单 + 单测 | targeted unit PASS |
| S4 | channel propagation / ChannelFactory fail-fast | targeted unit + channel regression PASS |
| S5 | receiver/frame fail-fast | targeted unit + phase smoke PASS |
| S6 | v2 tool链处理 | tool 静态检查 + no silent skip |
| S7 | Phase 5 MC wrapper / final baseline writer | smoke PASS |
| S8 | CI hook | 本地 CI 命令 PASS |
| S9 | full test + 1000 MC | final-v04 入库 |
| S10 | 根据结果修订设计，冻结 Phase 5 | audit / handover 更新 |

---

## 8. 出口条件

| 编号 | 条件 |
|------|------|
| C1 | Phase 0-4 全部测试 selector 仍通过 |
| C2 | catch-swallow sentinel-output 路径不再能写出成功 annotation |
| C3 | annotation v2 schema 不回退，无 v1 SignalSources 顶层字段 |
| C4 | `CSRD:Annotation:` 与 `CSRD:Measurement:` 均被 skip predicate 识别 |
| C5 | 1000 场景 MC `BlueprintAcceptanceRate >= 0.90`，非 skip fatal 0 |
| C6 | `ExecutionVsMeasuredBwAbsRelDiffP95 < 0.03` 或有设计修订解释 |
| C7 | JSON NaN / Infinity 为 0 |
| C8 | CI smoke 30 min 内完成 |
| C9 | `docs/baselines/2026-04-final-v04.json` 入库并记录 recipe hash / seed / metrics |
| C10 | 1000 场景 operator MC 的 wallclock P50/P95 作为诊断记录；不作为 Phase 5 freeze 硬门禁，避免非独占 workstation / resume 长跑环境把标注正确性门禁误判为失败 |

---

## 9. 风险登记

| 风险 | 等级 | 处理 |
|------|------|------|
| 1000 MC 暴露 C8 尾部上拉 | 中 | 先按 cohort / modulation / SNR 分桶诊断，不直接调阈值 |
| 强非线性下 peak-relative OBW 偏移 | 中 | 增加 IBO < 3 dB diagnostic cohort 或测试 |
| CI 环境无 MATLAB license | 中 | workflow hook 保持可选；本地 CI command 必须可复用 |
| 1000 MC 被外部环境中断 | 已处理 | S9 暴露；已加 `Resume=true` + checkpoint + artifact recovery，不重跑已完成 scenario |
| 1000 MC wallclock 超 Phase 4 单机预算 | 中 | 2026-04-27 final-v04 记录 P50=31.505 s / P95=66.285 s；作为 operator-run diagnostic，不阻塞 correctness freeze；CI smoke 30 min 仍为硬门禁 |
| fail-fast 导致旧 smoke 大量失败 | 高 | 先确认是设计缺失还是代码吞错被揭开；必要时回到设计 |
| v2 COCO 转换一次性升级过大 | 中 | 先 fail-fast 禁止静默错读，再分步升级 |
| RRFSimulator release pattern 与并行互相影响 | 中 | 先记录和测试，不和 catch-swallow 同 commit 大改 |

---

## 10. Owner 决议汇总

| 决议 | 结果 |
|------|------|
| annotation schema | `A_full_replace`，无 v1 共存和迁移工具 |
| Measurement 语义 | annotation 是完整生成记录；设计事实来自 Blueprint，生成后才知道的偏差值进入 Measured |
| Phase 5 MC | 直接 1000 场景 canonical sweep；CI 只跑 smoke |
| 工作流 | 先文档，再代码，再覆盖测试；发现设计问题回文档迭代 |

---

## 11. 实施快照

### 11.1 S1-S6 已完成（2026-04-26）

| Step | 状态 | 落点 |
|------|------|------|
| S1 | ✅ | 新增本文件，明确 Phase 5 是 MC + CI + 收尾硬化，不是迁移工具阶段 |
| S2 | ✅ | README phase table 最终改为 Phase 0-5 Frozen；顶层 audit §17.7 删除迁移工具计划 |
| S3 | ✅ | `isScenarioSkipException` 加 `CSRD:Measurement:`；`MeasurementCompletenessHookTest` 增加 predicate case |
| S4 | ✅ | `ChannelFactory` 与 `processChannelPropagation` 对 generic channel error rethrow，不再写 `ChannelBlockStepFailed` |
| S5 | ✅ | `processReceiverProcessing` / `generateSingleFrame` / `processSingleTransmitter` / `processTransmitterSegments` 收敛错误路径，不再写 `Status='Error'` / `FrameGenerationFailed` / `Error_MissingTxScenarioID` 半损坏 annotation |
| S6 | ✅ | `tools/convert_csrd_to_coco.m` 删除 v1 converter 实现，改为 v2 未实现时显式 fail-fast |

### 11.2 测试证据（2026-04-26）

| 命令 | 结果 |
|------|------|
| `runtests({'MeasurementCompletenessHookTest','CatchSwallowRemovedTest','ChannelExceptionPropagationTest','ChannelFactoryNoSilentFallbackTest'})` | PASS，43 cases |
| `test_channel_exception_propagation()` | PASS，5/5 |
| `run_all_tests('phase4')` | PASS，9/9，约 1339.75 s |
| `test_refactoring` | PASS，10/10 |
| `test_empty_osm_raytracing` | PASS |
| `run_all_tests('all')` | PASS，60/60，约 1975.74 s |
| targeted `checkcode(...,'-id')` on modified core files | PASS，0 issues |

### 11.3 S7-S10 最终状态

| Step | 状态 | 说明 |
|------|------|------|
| S7 | ✅ | Phase 5 1000 场景 MC wrapper / final baseline writer |
| S8 | ✅ | CI hook + local smoke entry |
| S9 | ✅ | 1000 场景 full MC 完成，生成并重新聚合 `docs/baselines/2026-04-final-v04.json` |
| S10 | ✅ | Phase 5 freeze / README / 顶层 audit 更新 |

### 11.4 S7-S8 已完成（2026-04-26）

| Step | 状态 | 落点 |
|------|------|------|
| S7 | ✅ | `tests/regression/test_baseline_sweep_200.m` 增加 `BaselineFilename` / `RunLabel` / `SchemaVersion` 参数；新增 `tools/phase5/run_phase5_mc_validation.m`，默认 1000 场景写 `docs/baselines/2026-04-final-v04.json`，smoke 模式写 `2026-04-final-v04.smoke.json` |
| S8 | ✅ | 新增 `tools/ci/run_csrd_static_gates.m`、`tools/ci/run_csrd_ci_smoke.m`、`.github/workflows/csrd-ci-smoke.yml`；CI smoke 执行 static gates + Phase 4 curated suite + Phase 5 MC wrapper smoke |

### 11.5 入口验证（2026-04-26）

| 命令 | 结果 |
|------|------|
| targeted `checkcode(...,'-id')` on baseline/phase5/ci/tool files | PASS，0 issues |
| `run_csrd_ci_smoke('IncludePhase4', false, 'BaselineScenarios', 12)` | PASS，约 325.2 s，写出 `docs/baselines/2026-04-final-v04.smoke.json` |
| `test_baseline_sweep_200(12,'Mode','smoke')` | PASS，约 347.4 s，确认默认 v0 smoke 路径未被参数化破坏 |
| `run_csrd_ci_smoke()` | PASS，约 1239.4 s（static gates + `run_all_tests('phase4')` + Phase 5 MC smoke），满足 30 min CI smoke 目标 |

### 11.6 S9 1000 场景 MC 结果（2026-04-27）

首轮 `run_phase5_mc_validation()` 在 `scenario_000713` 附近被外部环境中断，未写 final baseline。按 §5.5.1 修订后新增 resumable checkpoint/artifact recovery，并用 `run_phase5_mc_validation('Resume', true)` 续跑完成。

| 指标 | final-v04 |
|------|-----------|
| 输出 | `docs/baselines/2026-04-final-v04.json` |
| NumScenarios | 1000 |
| BlueprintAcceptanceRate | 1.0 |
| ChannelFactoryFailureRate | 0 |
| ExecutionVsMeasuredBwAbsRelDiffP95 | 0.022217530072084515 |
| EmptySignalSegmentRatio | 0 |
| BlueprintResamplesP95 / Max | 0 / 0 |
| BlueprintProvenanceCoverage | 1.0 |
| JsonNanCount / JsonInfinityCount | 0 / 0 |
| NumBwSamplesUsed | 3133 |
| NumLowSnrExcludedFromBwMetric | 419 |
| WallclockSecPerScenarioP50 / P95 | 31.505 s / 66.285 s（diagnostic，不作为 Phase 5 correctness gate） |
| RunRecovery.Resume | true |
| RunRecovery.NumRecoveredScenarios | 1000 |
| RunRecovery.AggregationWallclockSec | 32.649335 s |
| RunRecovery.ScenarioWallclockSecSum | 33675.365512299992 s |

判定：物理/annotation/schema 出口条件通过；operator MC wallclock 超 Phase 4 210 场景预算，记录为性能风险，不调宽物理或 annotation 阈值。

### 11.7 S10 冻结验证（2026-04-27）

| 命令 | 结果 |
|------|------|
| targeted `checkcode(...,'-id')` on `test_baseline_sweep_200.m` / `run_phase5_mc_validation.m` | PASS，0 issues |
| `run_phase5_mc_validation('Resume', true)` | PASS，1000/1000 scenarios recovered，重新写出 `docs/baselines/2026-04-final-v04.json`，含 `RunRecovery` 元数据 |
| `test_baseline_sweep_200(3,'Mode','smoke',...,'Resume',false)` | PASS，fresh smoke 写出 `RunRecovery.Resume=false` / `NumRecoveredScenarios=0`，确认非 resume 路径未被恢复元数据破坏 |

冻结结论：Phase 5 不再新增建模功能；剩余项转为后续性能/工具链 backlog，不影响当前 Blueprint / Construction / Measurement truth contract。

---

## 12. 修订历史

| 版本 | 日期 | 变化 |
|------|------|------|
| v0.1 | 2026-04-26 | 初版 Phase 5 设计：MC + CI + 收尾硬化；删除迁移工具范围；澄清 Measurement 语义 |
| v0.2 | 2026-04-26 | S7/S8 落地：Phase 5 MC wrapper、CI 本地入口、self-hosted workflow hook；新增入口级 smoke 与 checkcode 证据 |
| v0.3 | 2026-04-27 | S9/S10 完成并 Frozen：补 resumable MC 设计，续跑/恢复 1000 场景 final-v04；记录 `RunRecovery`，将 operator MC wallclock 改为诊断指标，CI smoke 30 min 保持硬门禁 |
