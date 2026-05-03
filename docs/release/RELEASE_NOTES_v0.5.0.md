# CSRD v0.5.0 Release Notes Draft

Status: Phase 7 validated release notes draft. No public tag has been cut from
this document.

## Summary

v0.5.0 is the post-refactor release-candidate line for CSRD. Phase 0-6 are
Frozen: the Blueprint / Construction / Measurement truth contract is in place,
annotation v2 is the only supported annotation schema, and release readiness
checks are machine-readable.

## Correctness Baseline

The canonical release-scale validation artifact is:

`docs/baselines/2026-04-final-v04.json`

Key final-v04 metrics:

| Metric | Value |
|--------|-------|
| NumScenarios | 1000 |
| BlueprintAcceptanceRate | 1.0 |
| ChannelFactoryFailureRate | 0 |
| ExecutionVsMeasuredBwAbsRelDiffP95 | 0.022217530072084515 |
| JsonNanCount / JsonInfinityCount | 0 / 0 |
| RunRecovery | `Resume=true`, `NumRecoveredScenarios=1000` |

Operator 1000-scenario wallclock remains diagnostic metadata. CI smoke is the
runtime hard gate for normal release readiness.

## Major Changes

- Blueprint, construction, and measurement responsibilities are separated.
- Silent construction fallbacks have been removed or converted to fail-fast
  contracts.
- Receiver-view projection is persisted per source per receiver.
- Doppler and measured truth are recorded in annotation v2.
- `csrd.pipeline.annotation.readAnnotationV2` validates annotation v2.
- `tools/convert_csrd_to_coco.m` exports a minimal receiver-frequency COCO
  representation.
- Release readiness and release CI readiness tools are available under
  `tools/release`.

## Breaking Changes

- No annotation v1 compatibility is provided.
- Legacy top-level fields `Realized`, `Planned`, `Temporal`, `Spatial`,
  `LinkBudget`, and `Channel` must not appear in new source annotations.
- Downstream consumers must use `Truth.Design`, `Truth.Execution`, and
  `Truth.Measured`.
- `tools/migrate_annotation_v1_to_v2.m` is intentionally not provided.

## Release Readiness Commands

```matlab
addpath(fullfile(pwd, 'tools', 'release'))
run_csrd_release_readiness()
run_csrd_release_ci_readiness()
```

`run_csrd_release_readiness()` is read-only and validates final-v04 metrics,
static gates, and required release documentation. `run_csrd_release_ci_readiness()`
also runs the Phase 6 curated suite, performance diagnostics, and local CI smoke
by default. It does not run the 1000-scenario MC; there is no 1000-scenario MC
rerun in this release-readiness path.

## Downstream Documentation

- `docs/annotation-v2-schema.md`
- `docs/examples/annotation-v2-downstream.md`
- `examples/read_annotation_v2_downstream.m`

## Remaining Backlog

- Strong nonlinearity bandwidth behavior under IBO below 3 dB.
- Lower-SNR cohort policy if future datasets include samples below the current
  C8 SNR floor.
- Multi-worker or `parfor` support, which requires a separate RNG and System
  object lifecycle design.
- RF front-end System object lifecycle profiling, especially release patterns
  in receiver processing.

## Publishing Note

This file is a release notes draft. Creating a tag, pushing a branch, or opening
a public release requires owner authorization.
