# Phase 6 详细设计 —— 发布硬化 + 性能诊断 + annotation v2 工具链

| 字段 | 值 |
|------|----|
| 状态 | **Draft v0.3 / Executing**（2026-04-27：S1-S4 已完成；先回顾冻结契约，再进入发布硬化） |
| 顶层 audit 引用 | `docs/audits/2026-04-spectrum-blueprint-construction-refactor.md` §18（待同步） |
| 关联条目 | v0.4 六阶段冻结证据 / Phase 5 backlog / annotation v2 下游工具链 / operator MC 性能诊断 |
| 前置 | Phase 0 / 1 / 2 / 3 / 4 / 5 已 Frozen；commit `42e70d0` 已入库；final baseline `docs/baselines/2026-04-final-v04.json` |
| 目标产出 | release readiness checklist / annotation v2 读取与导出工具 / COCO v2 converter 设计与实现 / 性能诊断报告 / CI 门禁收敛 |
| 非目标 | 不改变 Blueprint / Construction / Measurement truth contract；不回退 annotation v2；不为旧 v1 schema 做兼容层 |

---

## 0. 工作流契约

1. Phase 6 不是 v0.4 truth contract 的续改阶段，而是冻结后的 release hardening。
2. 任一实现改动前必须回看 Phase 0-5 对应契约，确认不会动摇已有冻结证据。
3. 性能优化只能减少开销，不能跳过 measurement、annotation completeness、Doppler 或 provenance。
4. annotation v2 工具链只读 v2；旧 v1 不兼容、不迁移、不静默猜字段。
5. 若工具或性能工作暴露物理/annotation 设计问题，先修订本文，再回到对应模块设计。

---

## 1. Phase 0-5 回顾基线

| 阶段 | 冻结事实 | Phase 6 必须保护的契约 |
|------|----------|------------------------|
| Phase 0 | `LogPolicy` / `sanitizeForJson` / `validateRequiredToolboxes` / `Header.Runtime` 已冻结 | release 工具必须沿用 JSON sanitize 与 runtime header，不绕过 toolbox fail-fast |
| Phase 1 | signal struct schema / ChannelSeed 含 `BurstId` / `mergeChannelOutput` 白名单 / PA-LNA 严格化已冻结 | 不新增隐式字段覆盖，不引入隐藏 RNG draw，不回退 `comm.MemorylessNonlinearity` 严格构造 |
| Phase 2 | profile 库 / BlueprintHash / 21 条 Validator / ScenarioFactory resample loop 已冻结 | 发布工具必须展示 recipe hash / blueprint provenance，不把 validator skip 当普通成功 |
| Phase 3 | silent fallback 删除 / ReceiverViews 真投影 / construction fail-fast / provenance dataflow 已冻结 | 性能优化不能恢复 magic default、silent fallback 或 emitter 全局 projection |
| Phase 4 | measurement 包 / Doppler / annotation v2 / receiver-view 持久化已冻结 | 导出工具必须以 `Truth.{Design,Execution,Measured}` 为唯一 schema；设计事实来自 Blueprint，观测事实来自 Measured |
| Phase 5 | 1000 场景 final-v04 / `Resume=true` / CI smoke / fail-fast 收尾已冻结 | 长跑复核必须优先 resume；operator MC wallclock 只作诊断，CI smoke 仍是 runtime hard gate |

final-v04 关键指标：

| 指标 | 值 |
|------|----|
| NumScenarios | 1000 |
| BlueprintAcceptanceRate | 1.0 |
| ChannelFactoryFailureRate | 0 |
| ExecutionVsMeasuredBwAbsRelDiffP95 | 0.022217530072084515 |
| JsonNanCount / JsonInfinityCount | 0 / 0 |
| RunRecovery | `Resume=true` / `NumRecoveredScenarios=1000` |
| WallclockSecPerScenarioP50 / P95 | 31.505 s / 66.285 s（diagnostic） |

---

## 2. 范围与边界

### 2.1 在范围内

| 编号 | 项目 | 处方 |
|------|------|------|
| P6-1 | release readiness | 增加可重复的 release checklist，汇总基线、测试、schema、CI 与剩余风险 |
| P6-2 | annotation v2 reader | 提供只读 v2 annotation 解析入口，显式验证 `Truth.Design/Execution/Measured` 与 receiver-view 字段 |
| P6-3 | COCO v2 converter | 替换当前 fail-fast stub；只支持 v2，字段映射必须标明 design/execution/measured 来源 |
| P6-4 | performance diagnostics | 对 `obwActual` / `pwelch` / FramePlane 缓存 / RRFSimulator release pattern 建诊断，不先改阈值 |
| P6-5 | CI hardening | 把本地 CI smoke、static gates、release readiness 串成可复用命令；不把 1000 MC 放进普通 CI |
| P6-6 | docs and examples | 补 annotation v2 schema example、downstream reader example、release notes 草案 |

### 2.2 不在范围内

| 项目 | 理由 |
|------|------|
| v1 annotation 兼容或迁移 | owner `A_full_replace` 决议；旧 schema 不再支持 |
| 修改 measurement 阈值以追求性能 | 会改变 label 语义；必须单独建模与 MC 验证 |
| 默认重跑 1000 场景 MC | Phase 5 已有 canonical final；Phase 6 默认使用 resume/readiness 检查 |
| 引入 parfor 改主仿真语义 | 并行会触碰 RNG、System object 生命周期与日志隔离，需单独小阶段 |
| 发布新 tag / push | 需要 owner 明确授权 |

---

## 3. 当前事实与风险

1. `tools/convert_csrd_to_coco.m` 当前是 v2 未实现 fail-fast stub，这是正确的 Phase 5 保护，但会阻塞下游导出。
2. 1000 MC correctness 全过，但 operator wallclock P50/P95 为 31.505/66.285 s，高于 Phase 4 单机预算；这是性能风险，不是 label correctness 失败。
3. annotation 文件 P95 约 35 KB，未来若 source/receiver 数继续上升，需要评估 stream-write 或分块导出。
4. `obwActual` 的 `PeakRelativeDb=-3 dBc` 与 `SnrFloorDb=6` 是 Phase 4/5 证据支持的组合，Phase 6 只能诊断，不能静默调整。
5. `run_csrd_ci_smoke()` 已在 1239.4 s 通过 30 min 门禁；CI hardening 应该稳定这个入口，而不是扩大普通 CI。

---

## 4. annotation v2 导出语义

COCO 或其他下游格式只能是 annotation v2 的派生产物。字段来源必须显式标注：

| 导出字段类别 | 来源 | 规则 |
|--------------|------|------|
| 类别 / 调制族 / 消息族 | `Truth.Design` | 设计事实，不从 IQ 反推 |
| 实际带宽 / Doppler / 信道模型 / 几何快照 | `Truth.Execution` | 施工兑现事实，不由 converter 重新估计 |
| 占用带宽 / 频谱中心 / SNR / burst envelope / frequency occupancy | `Truth.Measured` | 生成后测量事实；若缺失则 fail-fast |
| receiver-view bbox / frequency window projection | `ReceiverView` + `Truth.Measured` | bbox 必须以 receiver output window 为坐标系 |
| provenance / seed / schema | `Header.Runtime` + baseline recipe | 导出文件必须保留 |

禁止行为：

- 从旧 `annotation.rx/tx` 路径读取。
- 用 `Truth.Execution.ModulatedBandwidthHz` 冒充 measured occupied bandwidth。
- 在 source 不可见时生成可见 bbox。
- 缺字段时写空 label 继续。

---

## 5. 初始实施顺序

| Step | 内容 | 验证 |
|------|------|------|
| S1 | 写 Phase 6 设计文档，含 Phase 0-5 回顾 | ✅ 本文件存在，状态 Draft |
| S2 | 顶层 audit / README 同步 Phase 6 Draft | ✅ grep 无“下一阶段未知”类误述 |
| S3 | 增加 release readiness 文档或脚本 | ✅ `tools/release/run_csrd_release_readiness.m` 可读取 final-v04 并输出关键门禁 |
| S4 | 实现 annotation v2 reader + schema validation | ✅ `ReadAnnotationV2Test` + `run_all_tests('phase6')` PASS |
| S5 | 实现 COCO v2 converter 最小可用路径 | converter unit + fixture regression PASS |
| S6 | 增加 performance diagnostic report | 不改变 baseline correctness metric |
| S7 | 本地 CI smoke + release readiness PASS | 30 min 内；不跑 full 1000 MC |
| S8 | 根据结果修订本文，决定是否 Frozen | docs / tests / handover 更新 |

---

## 6. 出口条件

| 编号 | 条件 |
|------|------|
| C1 | Phase 0-5 冻结契约在文档和 readiness 输出中可追溯 |
| C2 | annotation v2 reader 对缺失 `Truth.Design/Execution/Measured` fail-fast |
| C3 | COCO v2 converter 不再 fail-fast stub，并且不读取 v1 路径 |
| C4 | 导出 labels 的 design/execution/measured 来源在 metadata 中可审计 |
| C5 | performance diagnostics 只报告热点，不改变 measurement 阈值或 label 语义 |
| C6 | `run_csrd_ci_smoke()` 或等价 local CI 仍在 30 min 内 PASS |
| C7 | final-v04 baseline 仍可解析，核心指标未被工具链改动污染 |

---

## 7. 风险登记

| 风险 | 等级 | 处理 |
|------|------|------|
| COCO bbox 语义与 receiver-view 坐标系混淆 | 高 | 先写 schema + fixture，再实现 converter |
| 下游希望 v1 兼容 | 中 | 明确拒绝；必要时写独立外部迁移说明，不进主工具 |
| 性能优化误改 measurement 结果 | 高 | 所有性能改动必须用 C8 metric 和 targeted measurement tests 回放 |
| release checklist 变成纸面文档 | 中 | 至少提供一个机器可读 readiness 入口 |
| CI 时间膨胀 | 中 | 普通 CI 不跑 1000 MC；只跑 smoke + schema + static gates |

---

## 8. 实施快照

### 8.1 S1-S4 已完成（2026-04-27）

| Step | 状态 | 落点 |
|------|------|------|
| S1 | ✅ | 新增本文件，明确 Phase 6 是 release hardening / performance diagnostics / annotation v2 toolchain，不是 truth contract 续改 |
| S2 | ✅ | 顶层 audit 升 `Draft v0.5.0`，README 增 `v0.5 next track` |
| S3 | ✅ | 新增 `tools/release/run_csrd_release_readiness.m`，只读校验 final-v04、Phase 0-6 文档、CI static gates 与可选 git clean |
| S4 | ✅ | 新增 `+csrd/+utils/+annotation/readAnnotationV2.m`、`tests/unit/ReadAnnotationV2Test.m`、`tests/regression/test_phase6_release_readiness.m`；`tests/run_all_tests.m` 增 `phase6` selector |

### 8.2 S3-S4 验证（2026-04-27）

| 命令 | 结果 |
|------|------|
| targeted `checkcode(...,'-id')` on `tools/release/run_csrd_release_readiness.m` | PASS，0 issues |
| `run_csrd_release_readiness()` | PASS，读取 `docs/baselines/2026-04-final-v04.json`；1000 scenarios；BW P95 diff = 0.022218 |
| targeted `checkcode(...,'-id')` on Phase 6 reader/readiness/test files | PASS，0 issues |
| `run_all_tests('phase6')` | PASS，2/2 suites（`ReadAnnotationV2Test` 5 cases + `test_phase6_release_readiness`），约 2.85 s |

---

## 9. 修订历史

| 版本 | 日期 | 变化 |
|------|------|------|
| v0.1 | 2026-04-27 | 初版 Draft：基于 Phase 0-5 回顾，定义 release hardening / performance diagnostics / annotation v2 toolchain 范围 |
| v0.2 | 2026-04-27 | S1-S3 落地：顶层文档同步，新增 release readiness 只读脚本并通过 checkcode/readiness 验证 |
| v0.3 | 2026-04-27 | S4 落地：annotation v2 reader + schema validation，新增 Phase 6 curated test selector |
