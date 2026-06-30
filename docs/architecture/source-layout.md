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
  -> annotation export
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
- `+csrd/+pipeline/+annotation/readAnnotation.m`: annotation reader and
  schema gate.

## Package Responsibilities

| Package | Responsibility |
| --- | --- |
| `+csrd/+blocks` | Scenario, physical environment, modulation, message, RF, channel, receiver blocks. |
| `+csrd/+catalog` | Regulatory spectrum catalogs (`+spectrum`) and SDR monitoring-receiver capability profiles (`+receiver`). |
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

## Receiver And Signal Contracts

- **Monitoring receiver capability.** The receiver behaves like a real SDR.
  `csrd.catalog.receiver.SdrReceiverCatalog` holds capability profiles
  (tuning range, max instantaneous bandwidth, ADC bits, noise figure, channel
  count) for popular models (USRP B210/N310, BladeRF, HackRF, RTL-SDR, Airspy,
  SDRplay). The selected model caps the unified `SampleRate` (the captured
  instantaneous bandwidth) and antenna count, and constrains the monitoring
  band center to the model tuning range. Configure with
  `CommunicationBehavior.Receiver.Sdr.Model`.
- **Message source contract.** The baseband source is a deterministic function
  of the modulation family: analog families (FM/PM/AM variants) use `Audio`,
  digital families use `RandomBit`
  (`csrd.support.modulation.messageSourceForModulation`). The binding is
  enforced at planning, at segment construction, and in the annotation reader.
- **Service-aware emitters.** Under regulatory planning, transmit power and
  modulation order follow the service class and channel bandwidth, and each
  country catalog covers broadcast, mobile, land-mobile, ISM, short-range,
  aeronautical, and maritime services.

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
- Historical refactoring/audit conclusions are preserved on the
  `archive/history-2026-06-30` branch, not on `main`.
