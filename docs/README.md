# CSRD Documentation Index / 文档索引

This directory contains current operating docs and historical audit records.
Use this page as the navigation entry.

本目录同时包含当前文档和历史审计材料。当前使用项目时，请优先阅读 Current Docs。

## Current Docs / 当前文档

| Document | Purpose |
| --- | --- |
| [`../README.md`](../README.md) | Project overview, current pipeline, active source layout. |
| [`architecture/source-layout.md`](architecture/source-layout.md) | Current package ownership and generated-output policy. |
| [`configuration.md`](configuration.md) | Modular configuration system and runtime contracts. |
| [`annotation-v2-schema.md`](annotation-v2-schema.md) | Annotation v2 schema for downstream users. |
| [`README_Weather.md`](README_Weather.md) | Weather configuration guide. |
| [`README_Refactoring.md`](README_Refactoring.md) | Refactor phase status and audit index. |

## Examples / 示例

| Document | Purpose |
| --- | --- |
| [`examples/annotation-v2-downstream.md`](examples/annotation-v2-downstream.md) | Read annotation v2 and export downstream formats. |
| [`../examples/read_annotation_v2_downstream.m`](../examples/read_annotation_v2_downstream.m) | Executable downstream reader example. |

## Validation / 验证

| Document | Purpose |
| --- | --- |
| [`release/RELEASE_NOTES_v0.5.0.md`](release/RELEASE_NOTES_v0.5.0.md) | Release-facing notes for annotation v2 and downstream tooling. |
| [`audits/reports/phase-6-release-freeze.md`](audits/reports/phase-6-release-freeze.md) | Phase 6 release freeze evidence. |
| [`audits/reports/phase-6-ci-readiness.md`](audits/reports/phase-6-ci-readiness.md) | Phase 6 CI readiness evidence. |
| [`audits/reports/phase-6-performance-diagnostics.md`](audits/reports/phase-6-performance-diagnostics.md) | Phase 6 read-only performance diagnostics. |

Large generated audit manifests are not committed. Regenerate comment-audit
manifests with `csrd.support.docs.auditProductionComments(..., 'WriteManifest', true)`;
the default output is under ignored `artifacts/audits/reports/`.

大型生成型审计清单不再提交到仓库。需要时运行审计工具重新生成，默认输出在 ignored 的
`artifacts/audits/reports/`。

## Historical Audits / 历史审计

The files under `audits/` preserve decisions, failure investigations, and
validation evidence from earlier refactor phases. They may mention paths that
were valid at the time but are no longer current.

`audits/` 下文件是历史记录，可能保留当时有效但现在已迁移或删除的路径。当前目录以
`../README.md` 和 `architecture/source-layout.md` 为准。

Key historical entry points:

- [`audits/2026-04-spectrum-blueprint-construction-refactor.md`](audits/2026-04-spectrum-blueprint-construction-refactor.md)
- [`audits/HANDOVER_2026-04-26.md`](audits/HANDOVER_2026-04-26.md)
- [`audits/HANDOVER_2026-05-03.md`](audits/HANDOVER_2026-05-03.md)
- [`audits/phases/phase-18-runtime-truth-contract-hardening.md`](audits/phases/phase-18-runtime-truth-contract-hardening.md)
