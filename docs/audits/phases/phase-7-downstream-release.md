# Phase 7 详细设计 —— 下游消费文档 + 发布候选材料

| 字段 | 值 |
|------|----|
| 状态 | **Frozen**（2026-04-28：S1-S5 已完成；downstream docs readiness 已落地） |
| 日期 | 2026-04-28 |
| 前置 | Phase 0 / 1 / 2 / 3 / 4 / 5 / 6 已 Frozen；Phase 6 S8 已把 release readiness 内容门禁纳入机器检查 |
| 目标产出 | annotation v2 schema 文档 / downstream reader 示例 / v0.5 release notes 草案 / 文档 readiness 工具与回归 |
| 非目标 | 不改仿真主链路；不改 annotation v2 schema；不新增 v1 兼容；不重跑 1000-scenario MC；不 tag / push |

---

## 0. Phase 0-6 回顾

Phase 7 只服务发布与下游消费，不重新解释冻结后的 truth contract。

| 上游阶段 | Phase 7 必须保护 |
|----------|------------------|
| Phase 4 | `Truth.Design / Truth.Execution / Truth.Measured` 三层语义；设计事实来自蓝图，带宽等观测事实来自测量 |
| Phase 5 | final-v04 是 canonical 1000-scenario correctness baseline；默认只读，不重写 |
| Phase 6 | `readAnnotationV2`、COCO v2 converter、performance diagnostics、release/CI readiness 已冻结；Phase 7 只能补发布材料与机器检查 |

调研发现：Phase 6 范围表中的 P6-6 写有“annotation v2 schema example /
downstream reader example / release notes 草案”。S1-S8 已冻结发布硬化主链路，
但这些下游材料还没有独立文档和测试。Phase 7 因此把 P6-6 从“范围备注”
收敛成独立、可验证的发布交付，而不是回改已冻结 Phase 6。

---

## 1. 范围

### 1.1 在范围内

| 编号 | 项目 | 规则 |
|------|------|------|
| P7-1 | annotation v2 schema 文档 | 必须列出 `Truth.Design`、`Truth.Execution`、`Truth.Measured`、`ReceiverView` 的字段来源和单位 |
| P7-2 | downstream reader 示例 | 必须调用 `csrd.pipeline.annotation.readAnnotationV2`；必须把 COCO 导出说明为 receiver-frequency canvas |
| P7-3 | release notes 草案 | 必须显式写明 Phase 0-6 Frozen、无 v1 annotation 兼容、final-v04 指标和 release readiness 命令 |
| P7-4 | 文档 readiness 工具 | 必须只读检查文档和示例内容，不运行仿真，不重写 baseline |
| P7-5 | 回归测试 | 必须验证 readiness 工具，并用合成 annotation v2 fixture 执行 downstream 示例 |

### 1.2 不在范围内

| 项目 | 理由 |
|------|------|
| 修改 annotation v2 schema | 会影响 Phase 4/6 冻结契约 |
| 兼容 annotation v1 | owner `A_full_replace` 决议；旧 schema 不再支持 |
| 重新生成数据集或重跑 1000 MC | Phase 5 final-v04 已是 canonical baseline |
| 发布 tag / push | 需要 owner 明确授权 |

---

## 2. 交付设计

| 文件 | 作用 | 机器检查 |
|------|------|----------|
| `docs/annotation-v2-schema.md` | 面向下游的 schema 说明和最小字段表 | 检查 truth 三层、receiver-view、measurement semantics、v1 禁止说明 |
| `docs/examples/annotation-v2-downstream.md` | 读取 annotation v2、汇总 sources、导出 COCO 的使用说明 | 检查 `readAnnotationV2`、`convert_csrd_to_coco`、`RequireSources`、receiver-frequency canvas |
| `docs/release/RELEASE_NOTES_v0.5.0.md` | v0.5 release notes 草案 | 检查 Phase 0-6 Frozen、breaking changes、release readiness 命令、final-v04 指标 |
| `examples/read_annotation_v2_downstream.m` | 可执行 downstream 示例函数 | `checkcode` + regression 用合成 fixture 调用 |
| `tools/release/run_csrd_downstream_docs_readiness.m` | 发布材料只读门禁 | Phase 7 regression 调用；release readiness 可聚合 |

---

## 3. 验收条件

| 编号 | 条件 |
|------|------|
| C1 | 新增文档清楚区分 Design / Execution / Measured，不把调制方式等设计事实说成测量结果 |
| C2 | downstream 示例只读 annotation v2，不读 v1 字段，不从 IQ 反推类别或带宽 |
| C3 | COCO 示例说明 bbox 宽度来自 measured SourcePlane bandwidth，类别来自 Design |
| C4 | release notes 显式声明无 v1 兼容、无新 public tag、无 1000 MC 重跑 |
| C5 | readiness 工具和 regression 全过，且不生成 tracked artifact |

---

## 4. 实施顺序

| Step | 内容 | 验证 |
|------|------|------|
| S1 | 写本设计文档并明确 Phase 0-6 回顾边界 | 本文件存在，状态 Draft |
| S2 | 增加 schema / downstream / release notes 文档 | readiness 内容检查 |
| S3 | 增加 downstream 示例函数和文档 readiness 工具 | `checkcode` |
| S4 | 增加 Phase 7 regression 与 `run_all_tests('phase7')` selector | targeted regression PASS |
| S5 | 回填测试证据，更新 README / audit / HANDOVER，冻结 Phase 7 | release readiness + phase7 PASS |

---

## 5. 验证快照

| 命令 | 结果 |
|------|------|
| targeted `checkcode(...,'-id')` on Phase 7 tool / example / regression / `tests/run_all_tests.m` | PASS，0 issues |
| `run_all_tests('phase7')` | PASS，1/1 regression；约 0.79 s；合成 annotation v2 fixture 调用 `read_annotation_v2_downstream`，生成 COCO JSON |
| `run_csrd_release_readiness()` | PASS；final-v04 指标仍通过；`DownstreamDocs.Success=true` |
| `run_all_tests('phase6')` | PASS，6/6 suites；约 6.04 s；确认 release readiness 加入 Phase 7 docs 门禁后未破坏 Phase 6 curated suite |

Phase 7 没有运行仿真，没有重写 baseline，没有改变 annotation v2 schema。

## 6. 实施快照

| Step | 状态 | 落点 |
|------|------|------|
| S1 | ✅ | 新增本设计文档，明确 Phase 7 是发布材料阶段，不回改 Phase 6 truth contract |
| S2 | ✅ | 新增 `docs/annotation-v2-schema.md`、`docs/examples/annotation-v2-downstream.md`、`docs/release/RELEASE_NOTES_v0.5.0.md` |
| S3 | ✅ | 新增 `examples/read_annotation_v2_downstream.m` 与 `tools/release/run_csrd_downstream_docs_readiness.m` |
| S4 | ✅ | 新增 `tests/regression/test_phase7_downstream_docs_readiness.m` 与 `run_all_tests('phase7')` selector |
| S5 | ✅ | `run_csrd_release_readiness()` 聚合 downstream docs readiness；README / audit / HANDOVER 同步 Phase 7 |

---

## 7. 修订历史

| 版本 | 日期 | 变化 |
|------|------|------|
| v0.1 | 2026-04-28 | Phase 7 启动：把 Phase 6 P6-6 发布材料缺口拆成独立可验证阶段 |
| v0.2 | 2026-04-28 | Phase 7 Frozen：schema 文档、downstream 示例、release notes 草案、readiness 工具和 regression 全部落地 |
