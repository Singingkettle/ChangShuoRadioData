# CSRD Refactoring Status

This page is the current refactoring index, not a historical implementation
report. Older phase details remain in [`audits/phases/`](audits/phases/) and
handover snapshots under [`audits/`](audits/).

## Current State

The active architecture after the latest refactoring is:

- `RuntimePlan` is run-level policy only. It stores rules such as frame sampling
  policy, receiver policy, map policy, seed policy, and config fingerprint.
- `ScenarioPlan` is built once before each scenario starts. It freezes concrete
  frame length, frame count, receiver-frame accounting, selected map/channel,
  Tx/Rx plans, and the communication schedule.
- Frame execution follows the frozen `ScenarioPlan`. Scenario-level facts must
  not be re-sampled inside the frame loop.
- Annotation v2 separates `Truth.Design` from `ScenarioPlan`,
  `Truth.Execution` from actual sample-grid insertion and channel/RF execution,
  and `Truth.Measured` from post-generation measurements.

## Removed Or Rejected Patterns

Do not reintroduce these in active code or current docs:

- `+csrd/+utils` as a production package.
- `normalizeRuntimeContracts` as a production fallback layer.
- `config.Log` or `Runner.Log.Policy` as logging authorities. Use top-level
  `config.Logging` and `RuntimePlan.Logging`.
- Raw config fields such as `Factories.Scenario.Global.FrameLength`,
  `Factories.Scenario.Global.FrameNumSamples`,
  `Factories.Scenario.Global.NumFramesPerScenario`, `FrameDuration`,
  `ObservationDuration`, or `Runner.FixedFrameLength`.
- Old antenna authority helpers such as `updateTransmitterAntennaConfig` or
  `applyAntennaConfigFromSegments`.
- Committed generated JSON audit manifests under `docs/audits/reports/`.

Legacy fields are configuration errors, not compatibility entry points. Derived
facts must come from `RuntimePlan` policies or from the per-scenario
`ScenarioPlan`.

## What To Read First

1. [`../README.md`](../README.md)
2. [`configuration.md`](configuration.md)
3. [`architecture/source-layout.md`](architecture/source-layout.md)
4. [`annotation-v2-schema.md`](annotation-v2-schema.md)
5. [`audits/manual-full-code-review-guide.md`](audits/manual-full-code-review-guide.md)

## Validation Pointers

High-signal checks before review:

```matlab
run_csrd_ci_smoke('IncludePhase4', false, 'BaselineScenarios', 1)
run_phase34_boundary_quality_audit('StopOnFailure', true, 'StressCount', 6)
runtests({'RunPlanPolicyOnlyTest','ScenarioPlanBuildTest','ScenarioPlanFrozenBeforeFrameExecutionTest'})
```

For OSM/RayTracing risks, cover both empty/flat and building-present paths.
For annotation risks, check `BuildSourceAnnotationV2Test`,
`MeasurementCompletenessHookTest`, and `ScenarioPlanAnnotationContractTest`.

## Historical Trail

- [`audits/HANDOVER_2026-04-26.md`](audits/HANDOVER_2026-04-26.md): first major
  AI handover snapshot.
- [`audits/HANDOVER_2026-05-03.md`](audits/HANDOVER_2026-05-03.md): second
  handover snapshot after deeper restructuring.
- [`audits/phases/`](audits/phases/): detailed phase notes. Treat them as
  evidence, not as current API documentation.
