[English](README.md) | [中文](README.zh-CN.md)

# CSRD Documentation Index

**Generating a dataset for the first time? Start at
[`GETTING_STARTED.md`](GETTING_STARTED.md).** Use the root
[`README.md`](../README.md), this index, the configuration guide, and the
architecture guide as the current operating documentation. Each doc has a
Chinese (`.zh-CN.md`) counterpart linked at its top.

## Current Docs

| Document | Purpose |
| --- | --- |
| [`GETTING_STARTED.md`](GETTING_STARTED.md) | **Start here.** Requirements, OSM/Python prerequisites, how to generate data, output layout, troubleshooting. |
| [`../README.md`](../README.md) | Project overview, current entry points, runtime model, repository layout. |
| [`configuration.md`](configuration.md) | Raw config authorities, `RuntimePlan` policies, per-scenario `ScenarioPlan`, rejected legacy fields. |
| [`architecture/source-layout.md`](architecture/source-layout.md) | Current source package responsibilities and production data flow. |
| [`annotation-schema.md`](annotation-schema.md) | Annotation contract: `Truth.Design`, `Truth.Execution`, `Truth.Measured`, receiver view. |
| [`examples/annotation-downstream.md`](examples/annotation-downstream.md) | Downstream consumer example: read the annotation, export COCO. |
| [`README_Weather.md`](README_Weather.md) | Weather configuration path, units, defaults, and ScenarioPlan timing notes. |

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

## Historical material

The refactoring audits, phase notes, handovers, and overnight bug-hunt findings
that record how the project reached its current state are preserved on the
[`archive/history-2026-06-30`](https://github.com/Singingkettle/ChangShuoRadioData/tree/archive/history-2026-06-30)
branch, not on `main`. They are evidence, not current operating instructions.
Generated audit manifests are not committed; regenerate them under ignored
`artifacts/`.
