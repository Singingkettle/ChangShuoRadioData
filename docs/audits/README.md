# CSRD Historical Audit Archive

This directory stores historical refactoring evidence. It is intentionally not
the first place to learn the current codebase.

当前目录中的 handover、phase 文档和旧报告用于追踪项目演进。它们可能包含旧路径、
旧兼容策略或已经删除的 helper 名称。当前项目结构以：

- [`../../README.md`](../../README.md)
- [`../README.md`](../README.md)
- [`../configuration.md`](../configuration.md)
- [`../architecture/source-layout.md`](../architecture/source-layout.md)

为准。

## How To Read / 阅读方式

- `HANDOVER_2026-04-26.md` and `HANDOVER_2026-05-03.md` are historical
  snapshots from previous refactoring passes.
- `phases/` records phase-level decisions and verification notes.
- `reports/` keeps small human-written reports. Large generated JSON manifests
  are not committed anymore.
- `manual-full-code-review-guide.md` is current enough to use for human review,
  but cross-check its commands against the root README if the code changes.

## Generated Reports / 生成报告

Regenerate large audit manifests under ignored artifacts:

```matlab
summary = csrd.support.docs.auditProductionComments( ...
    'WriteManifest', true, ...
    'ManifestPath', fullfile('artifacts','audits','reports', ...
        'phase-14-production-comment-audit.json'));
```

Do not commit generated manifest JSON files under `docs/audits/reports/`.
