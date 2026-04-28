# Phase 6 Performance Diagnostics Report

| Field | Value |
|-------|-------|
| Status | Draft v0.2 / S6 implemented |
| Date | 2026-04-28 |
| Scope | Diagnostic only; no measurement threshold changes |
| Canonical baseline | `docs/baselines/2026-04-final-v04.json` |
| Reference baseline | `docs/baselines/2026-04-baseline-v0.json` |

## Summary

S6 treats performance as release risk, not label correctness. The final-v04
1000-scenario baseline remains the correctness source of truth. Its operator
wallclock numbers are higher than the Phase 4 210-scenario baseline, but the
annotation and measurement gates remain within frozen limits.

## Baseline Comparison

| Metric | Phase 4 baseline-v0 | final-v04 | Diagnostic |
|--------|---------------------|-----------|------------|
| Scenarios | 210 | 1000 | final-v04 is the release-scale run |
| WallclockSecPerScenarioP50 | 21.2308 s | 31.5050 s | +48.4 %, watch item |
| WallclockSecPerScenarioP95 | 45.4658 s | 66.2850 s | +45.8 %, watch item |
| AnnotationFileBytesP95 | 35244 B | 35591 B | roughly flat |
| LogLinesPerScenarioP95 | 2885 | 303.5 | lower after Phase 5 logging discipline |
| ExecutionVsMeasuredBwAbsRelDiffP95 | 0.021171 | 0.022218 | still below 0.03 |

## Hotspot Hypotheses

1. `obwActual` depends on `pwelch`; it is intentionally used for both
   `Truth.Execution.ModulatedBandwidthHz` and `Truth.Measured.*`.
2. FramePlane measurement is already cached once per receiver in
   `processReceiverProcessing`, so repeated combined-buffer OBW should not be
   reintroduced.
3. `RRFSimulator.stepImpl` releases `ThermalNoise` and `SampleShifter` during
   each receiver step. This is a candidate for profiling, but changing it
   would touch System object lifecycle and randomness, so it needs a separate
   design/test loop.
4. CI should keep using smoke-scale gates. The 1000-scenario MC remains an
   operator run with resume/recovery metadata.

## S6 Machine Gate

The committed S6 tool is `tools/phase6/run_phase6_performance_diagnostics.m`.
By default it is read-only and runs no simulation. It reports:

- baseline comparison between Phase 4 baseline-v0 and final-v04
- frozen correctness contract checks
- static hotspot presence for `obwActual` / FramePlane cache /
  `RRFSimulator` release patterns
- optional deterministic measurement microbench when explicitly requested

Validation snapshot:

| Command | Result |
|---------|--------|
| `run_phase6_performance_diagnostics()` | PASS; wallclock P50/P95 are `watch`, frozen contracts PASS, static hotspots PASS |
| `run_phase6_performance_diagnostics('RunMicrobench',true,'NumMicrobenchRepeats',2)` | PASS; diagnostic-only-no-threshold |
| `run_all_tests('phase6')` | PASS, 5/5 suites |
