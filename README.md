![Citybuster Studio Logo](assets/logo.svg)

# ChangShuo Radio Data (CSRD)

[English](README.md) | [Chinese](README.zh-CN.md)

CSRD is a MATLAB spectrum-sensing data generator. Its core promise is simple:
the generated IQ signal, the simulated scene state, and the exported annotation
must describe the same radio event.

The current refactored pipeline is no longer the old "one global frame shape"
design. A run provides policies, each scenario first builds a frozen
`ScenarioPlan`, every frame is generated from that plan, and annotations record
what was planned, executed, and measured.

## Quick Start

**New here? Read [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)** for the full
walkthrough: requirements, OSM map data, the run, the output layout, and
troubleshooting.

In short, from the repository root in MATLAB:

```matlab
addpath(pwd)
addpath(fullfile(pwd, 'tools'))
simulation(1, 1, 'csrd2025/csrd2025.m')
```

Generated data lands under `data/CSRD2025/session_*/` (per-scenario annotation
JSON + IQ `.mat`).

**Before the first run** you need:
- MATLAB **R2025a** with the **Communications**, **Signal Processing**, **Phased
  Array System**, and **Antenna** toolboxes.
- **OSM map data** under `data/map/osm/` — the default config is ~90% OSM ray
  tracing, so an empty map directory fails fast with `CSRD:Scenario:MissingOSMFile`.
  Get it with `pip install requests && python tools/download_osm.py`, or switch to
  the statistical-only channel (`Map.Types = {'Statistical'}`).

See [GETTING_STARTED.md](docs/GETTING_STARTED.md) for details.

## Current Entry Points

| Task | Entry |
| --- | --- |
| Run default generation | `tools/simulation.m` |
| Load a config | `csrd.runtime.config_loader` |
| Orchestrate scenarios/workers | `+csrd/SimulationRunner.m` |
| Generate one scenario | `+csrd/+core/@ChangShuo` |
| Build run policies | `csrd.pipeline.runtime.buildRuntimePlan` |
| Build per-scenario plan | `csrd.pipeline.runtime.buildScenarioPlan` |
| Read annotations | `csrd.pipeline.annotation.readAnnotation` |

Minimal run from the repository root:

```matlab
addpath(pwd)
addpath(fullfile(pwd, 'tools'))
simulation(1, 1, 'csrd2025/csrd2025.m')
```

Generated datasets are written under `data/<DatasetName>/`. The only durable
content expected under `data/` is `data/map/`, which stores local map assets.

## Runtime Model

The production flow is:

```text
config_loader
  -> RuntimePlan          run-level policies and fingerprints
  -> SimulationRunner     scenario dispatch, output, failure accounting
  -> ChangShuo
      -> ScenarioFactory.planScenario
      -> ScenarioPlan     frozen scenario construction plan
      -> frame loop       per-frame execution from the plan
      -> receiver frames  actual signal buffers
      -> annotation    Design / Execution / Measured truth planes
```

Important contracts:

- Raw config stores authorities and policies only.
- `RuntimePlan` is a run-level policy object, not a resolved frame fact store.
- `ScenarioPlan.Frame` owns concrete `FrameNumSamples`,
  `NumFramesPerScenario`, `FrameDurationSec`, and
  `ObservationDurationSec` for one scenario.
- A scenario is generated in three steps: make the plan, execute the plan,
  annotate the actual generated signal.
- `Truth.Design` comes from the scenario plan and blueprint facts.
- `Truth.Execution` comes from actual sample-grid insertion, channel, RF, and
  geometry execution.
- `Truth.Measured` comes from receiver-side measurements of generated signals.

Old raw fields such as `Runner.FixedFrameLength`,
`Factories.Scenario.Global.FrameLength`,
`Factories.Scenario.Global.FrameNumSamples`,
`Factories.Scenario.Global.NumFramesPerScenario`, `FrameDuration`, and
`ObservationDuration` are not compatibility aliases. They are rejected at the
configuration boundary.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `+csrd/` | Main MATLAB package. |
| `+csrd/+core/@ChangShuo/` | Per-scenario engine and per-frame generation helpers. |
| `+csrd/+factories/` | Factory objects for scenario, message, modulation, Tx RF, channel, and Rx RF execution. |
| `+csrd/+blocks/` | Scenario simulators and physical-layer blocks. |
| `+csrd/+pipeline/` | Cross-module contracts for runtime plans, annotation, measurement, link budget, scenario timing, and signal gating. |
| `+csrd/+runtime/` | Config loading, logging, map helpers, performance tracing, toolbox checks, and system info. |
| `+csrd/+catalog/` | Regulatory spectrum catalogs and reusable profile libraries. |
| `+csrd/+support/` | Internal validation, hashing, documentation, random, and maintenance helpers. |
| `config/` | Base configs and public `csrd2025` configs. |
| `tools/` | Public entrypoints, CI gates, audits, diagnostics, visualization, and maintenance scripts. |
| `tests/` | MATLAB unit and regression tests. |
| `docs/` | Current documentation plus archived audit history. |
| `data/map/` | Local OSM/map assets. Do not delete during cleanup. |

See [docs/architecture/source-layout.md](docs/architecture/source-layout.md)
for the current package responsibilities.

## Configuration

Use `config/csrd2025/csrd2025.m` as the default working example. Custom configs
inherit from files under `config/_base_/` through `baseConfigs`.

Current frame diversity is configured with `Factories.Scenario.FramePolicy`:

```matlab
config.Factories.Scenario.FramePolicy.FrameNumSamples.Mode = 'Choice';
config.Factories.Scenario.FramePolicy.FrameNumSamples.Values = [1024, 2048, 4096];
config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Mode = 'IntegerRange';
config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Min = 4;
config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Max = 10;
```

OSM map selection is file-level balanced coverage. There is no default
file-size cap or "large map" exclusion. Large OSM files may be slow because
MATLAB `siteviewer` and `raytrace` must process the map geometry; that is a
performance fact, not a reason to silently skip or downgrade a case.

For configuration details, see [docs/configuration.md](docs/configuration.md).

## Validation

Fast local smoke:

```matlab
addpath(pwd)
addpath(fullfile(pwd, 'tools', 'ci'))
run_csrd_ci_smoke('IncludePhase4', false, 'BaselineScenarios', 1)
```

Useful focused tests:

```matlab
runtests('tests/unit/ScenarioPlanBuildTest.m')
runtests('tests/unit/ScenarioPlanFrozenBeforeFrameExecutionTest.m')
runtests('tests/unit/BuildSourceAnnotationTest.m')
runtests('tests/unit/MeasurementCompletenessHookTest.m')
```

## Documentation

Start here:

- [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md): generate your first dataset
  (requirements, OSM data, the run, the output, troubleshooting).
- [docs/README.md](docs/README.md): documentation index.
- [docs/configuration.md](docs/configuration.md): current configuration and
  runtime-plan contract.
- [docs/annotation-schema.md](docs/annotation-schema.md): annotation
  consumer contract.

Historical refactoring audits, phase notes, and overnight bug-hunt findings are
preserved on the
[`archive/history-2026-06-30`](https://github.com/Singingkettle/ChangShuoRadioData/tree/archive/history-2026-06-30)
branch, not on `main`.

If you need the older JSAC-era behavior, use the historical stable revision:
[a6d09a4b264894b76f852ce33bfd82adc7b270b5](https://github.com/Singingkettle/ChangShuoRadioData/tree/a6d09a4b264894b76f852ce33bfd82adc7b270b5).
