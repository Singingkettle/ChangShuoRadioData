# CSRD Source Layout

This page describes the current source tree. Historical audit documents may
mention removed packages or helpers; use this page for current navigation.

## Production Data Flow

```text
tools/simulation.m
  -> csrd.runtime.config_loader
  -> csrd.pipeline.runtime.buildRuntimePlan
  -> csrd.SimulationRunner
  -> csrd.core.ChangShuo
  -> csrd.factories.ScenarioFactory.planScenario
  -> ScenarioPlan + FramePlan execution
  -> receiver frame assembly
  -> annotation v2 export
```

The central invariant is unchanged: signal data, scene state, and annotation
must describe the same event.

## Production Entry Points

- `tools/simulation.m`: formal generation entry point.
- `csrd.runtime.config_loader`: modular config load and run-level policy build.
- `+csrd/SimulationRunner.m`: scenario scheduling, output directories, logging,
  and runner-level validation.
- `+csrd/+core/@ChangShuo`: per-scenario execution engine.
- `+csrd/+pipeline/+runtime/buildScenarioPlan.m`: scenario construction plan
  builder.
- `+csrd/+pipeline/+annotation/readAnnotationV2.m`: annotation reader and
  schema gate.

## Package Responsibilities

| Package | Responsibility |
| --- | --- |
| `+csrd/+blocks` | Scenario, physical environment, modulation, message, RF, channel, receiver blocks. |
| `+csrd/+catalog` | Regulatory spectrum catalogs and reusable spectrum profiles. |
| `+csrd/+core` | `ChangShuo` execution engine and frame/receiver orchestration. |
| `+csrd/+factories` | Factory objects that construct production blocks from config and scenario plans. |
| `+csrd/+pipeline` | Cross-module contracts: runtime plans, annotation, measurement, link budget, scenario truth. |
| `+csrd/+runtime` | Config loading, logging, toolbox checks, system information, map/runtime services. |
| `+csrd/+support` | Validation, documentation audit, hashing, random helpers, optimization, test-support-adjacent utilities. |

Do not add new production code under `+csrd/+utils`; that package was removed.

## Scenario-Level Plan Rule

Run-level policy lives in `RuntimePlan`; concrete per-scenario facts live in
`ScenarioPlan`. The frame loop should not re-sample:

- frame sample count
- number of frames
- selected map file
- Tx/Rx counts or identities
- communication schedule

If a scenario-level fact needs randomness, draw it before the first frame and
record it in `ScenarioPlan`.

## OSM And RayTracing Notes

- OSM selection is balanced at file level; no size cap or runtime tier filters
  are active.
- Empty/no-building OSM files are valid when the flat-terrain policy is explicit
  and visible in metadata.
- Geographic coordinates are for RayTracing site construction; distance,
  Doppler, and movement use meter-based positions and velocities.
- RayTracing fallbacks must be explicit and reflected in execution metadata.

## Generated Output Locations

- Formal dataset generation writes under `data/<DatasetName>/`; `data/` is
  ignored and must not be added to git.
- Original map assets live under `data/map/` and must be preserved.
- Automated test runs write under `artifacts/tests/runs/`.
- Generated test configs write under `artifacts/tests/generated_configs/`.
- Long-running diagnostics and performance traces write under `artifacts/`.
- Large generated audit manifests write under `artifacts/audits/reports/`.
- Durable human conclusions belong in `docs/audits/`.
