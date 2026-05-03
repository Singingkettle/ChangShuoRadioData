# Phase 6 CI Readiness Report

| Field | Value |
|-------|-------|
| Status | Frozen / S7 implemented |
| Date | 2026-04-28 |
| Scope | Release/CI gate aggregation |
| Long-run policy | CI smoke only; no 1000-scenario MC |

## Goal

S7 provides a single release-owner command that combines:

- frozen final-v04 release readiness
- Phase 6 curated tests
- Phase 6 performance diagnostics
- optional full local CI smoke

The command must make skipped long checks explicit. A quick run can prove the
aggregator wiring, but only a run with CI smoke enabled can satisfy the S7
release-readiness evidence.

## Gate Semantics

| Gate | Source | Release Interpretation |
|------|--------|------------------------|
| Release readiness | `run_csrd_release_readiness()` | Frozen final-v04 metrics and docs are still valid |
| Phase 6 suite | `run_all_tests('phase6')` | v2 reader, COCO export, readiness, diagnostics regressions pass |
| Performance diagnostics | `run_phase6_performance_diagnostics()` | wallclock is diagnostic watch only; correctness gates pass |
| CI smoke | `run_csrd_ci_smoke()` | local smoke-scale simulation path remains under the 30 min gate |

## Non-Goals

- Do not run the 1000-scenario final MC.
- Do not change CI smoke scenario count silently.
- Do not reinterpret performance watch items as label correctness failures.
- Do not publish tags or push branches.

## Validation Plan

1. Run a quick regression with CI smoke disabled to keep `run_all_tests('phase6')`
   cheap and deterministic.
2. Run the full S7 aggregator with CI smoke enabled before marking S7 complete.
3. If the smoke baseline changes, inspect it as a generated validation artifact
   and document the result before committing.

## Validation Snapshot

| Command | Result |
|---------|--------|
| `run_csrd_release_ci_readiness('RunCiSmoke',false,'IncludePhase6Suite',false)` | PASS; long-check skip is explicit via `CiSmokeSkipped=true` |
| `run_all_tests('phase6')` | PASS, 6/6 suites |
| `run_csrd_release_ci_readiness()` | PASS; CI smoke elapsed `933.55 s`, below the `1800 s` release limit |
| `docs/baselines/2026-04-final-v04.smoke.json` after full smoke | No tracked diff; smoke baseline remains deterministic for this run |

The full S7 command ran release readiness, Phase 6 curated tests,
performance diagnostics, Phase 4 curated tests, and the 12-scenario Phase 5
smoke wrapper. It did not run the 1000-scenario MC.
