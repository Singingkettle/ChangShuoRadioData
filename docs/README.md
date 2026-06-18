# CSRD Documentation Index

This directory is split into current operating documentation and historical
audit snapshots.

Use the root [`README.md`](../README.md), this index, the configuration guide,
and the architecture guide as the current operating documentation. Files under
`docs/audits/` are historical evidence and may mention removed paths or older
contracts.

## Current Docs

| Document | Purpose |
| --- | --- |
| [`../README.md`](../README.md) | Project overview, current entry points, runtime model, validation commands. |
| [`configuration.md`](configuration.md) | Raw config authorities, `RuntimePlan` policies, per-scenario `ScenarioPlan`, rejected legacy fields. |
| [`architecture/source-layout.md`](architecture/source-layout.md) | Current source package responsibilities and production data flow. |
| [`annotation-schema.md`](annotation-schema.md) | Annotation contract: `Truth.Design`, `Truth.Execution`, `Truth.Measured`, receiver view. |
| [`README_Weather.md`](README_Weather.md) | Weather configuration path, units, defaults, and ScenarioPlan timing notes. |
| [`audits/manual-full-code-review-guide.md`](audits/manual-full-code-review-guide.md) | Human review workflow for reading the full codebase without losing cross-module contracts. |

## Configuration

Start from [`configuration.md`](configuration.md) when changing simulation
inputs. The current model is:

1. Raw config stores authorities and sampling policies.
2. `csrd.runtime.config_loader` builds a run-level `RuntimePlan`.
3. `ScenarioFactory.planScenario` builds a frozen `ScenarioPlan` before each
   scenario executes.
4. Frame generation follows that plan; annotation records design, execution,
   and measured facts separately.

Do not add compatibility fallbacks for old frame fields. Deprecated fields such
as `Factories.Scenario.Global.FrameNumSamples`, `FrameDuration`,
`ObservationDuration`, `Runner.FixedFrameLength`, and `OSM.MaxFileSizeMB` are
configuration errors.

## Architecture

The production path is:

```text
tools/simulation.m
  -> csrd.runtime.config_loader
  -> csrd.SimulationRunner
  -> csrd.core.ChangShuo
  -> csrd.factories.ScenarioFactory.planScenario
  -> physical environment / communication behavior / waveform / RF / channel
  -> receiver frame assembly
  -> annotation export
```

See [`architecture/source-layout.md`](architecture/source-layout.md) for the
current package map.

## Validation

Useful review-time entry points:

```matlab
run_csrd_ci_smoke('IncludePhase4', false, 'BaselineScenarios', 1)
simulation(1, 1, 'csrd2025/csrd2025.m')
```

Generated validation output belongs under ignored `artifacts/` or `data/`.
`data/map/` is the only data subtree treated as source asset.

## Historical Audits

Historical material lives under [`audits/`](audits/). It records how the project
reached the current state, but it may mention old paths, removed helpers, or
past compatibility decisions.

- [`audits/README.md`](audits/README.md) explains how to read the archive.
- [`audits/HANDOVER_2026-04-26.md`](audits/HANDOVER_2026-04-26.md) and
  [`audits/HANDOVER_2026-05-03.md`](audits/HANDOVER_2026-05-03.md) are handover
  snapshots.
- [`audits/phases/`](audits/phases/) contains phase-by-phase refactoring notes.

Large generated audit manifests are no longer committed. Regenerate them under
`artifacts/audits/reports/` when needed.
