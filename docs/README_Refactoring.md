# Refactoring Status Index / 重构状态索引

This page is an index, not a design source of truth. Current source layout is
documented in `docs/architecture/source-layout.md`; current runtime contracts
are summarized in `docs/configuration.md`.

本页只作为重构状态索引。当前目录结构以 `docs/architecture/source-layout.md` 为准；
当前运行合同以 `docs/configuration.md` 为准。

## Current State / 当前状态

- Phase 0-18 have been merged into `main`.
- Phase 18 hardened runtime truth contracts across frame/time, sample rate,
  carrier frequency, bandwidth, power/noise, receiver view, TRF resampling, and
  annotation measurement visibility.
- Phase 19 realigns documentation so current docs no longer describe removed
  paths or historical transitional states.

## Handover Documents / 交接文档

- `docs/audits/HANDOVER_2026-04-26.md`: first major handover snapshot.
- `docs/audits/HANDOVER_2026-05-03.md`: second handover snapshot before Phase 17/18 closure.

Both files are historical records. They intentionally preserve past state and
may mention paths that have since moved.

两份交接文档是历史记录，可能保留当时有效但现在已迁移的路径。

## Phase Documents / 阶段文档

| Phase | Document |
| --- | --- |
| 0 | `docs/audits/phases/phase-0-baseline.md` |
| 1 | `docs/audits/phases/phase-1-dataflow.md` |
| 2 | `docs/audits/phases/phase-2-blueprint.md` |
| 3 | `docs/audits/phases/phase-3-construction.md` |
| 4 | `docs/audits/phases/phase-4-measurement.md` |
| 5 | `docs/audits/phases/phase-5-mc-validation.md` |
| 6 | `docs/audits/phases/phase-6-release-hardening.md` |
| 7 | `docs/audits/phases/phase-7-downstream-release.md` |
| 8 | `docs/audits/phases/phase-8-regulatory-spectrum.md` |
| 9 | `docs/audits/phases/phase-9-simulation-entry-coverage.md` |
| 10 | `docs/audits/phases/phase-10-full-coverage-verification.md` |
| 11 | `docs/audits/phases/phase-11-config-and-dead-code-cleanup.md` |
| 12 | `docs/audits/phases/phase-12-config-field-consumption-audit.md` |
| 13 | `docs/audits/phases/phase-13-full-generation-and-comment-audit.md` |
| 14 | `docs/audits/phases/phase-14-production-bilingual-comment-audit.md` |
| 15 | `docs/audits/phases/phase-15-osm-raytracing-and-architecture-reorg.md` |
| 16 | `docs/audits/phases/phase-16-osm-raytracing-stress-and-artifact-governance.md` |
| 17 | `docs/audits/phases/phase-17-config-contract-unification.md` |
| 18 | `docs/audits/phases/phase-18-runtime-truth-contract-hardening.md` |

## Validation Evidence / 验证证据

Durable summaries belong in Markdown phase docs. Large generated manifests and
runtime outputs belong under ignored `data/` or `artifacts/`.

长期证据写入 Markdown 阶段文档；大型生成清单和运行输出写入 ignored 的 `data/` 或
`artifacts/`。
