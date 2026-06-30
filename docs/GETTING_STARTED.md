[English](GETTING_STARTED.md) | [中文](GETTING_STARTED.zh-CN.md)

# Getting Started — Generate Your First Dataset

This guide takes you from a fresh clone to a generated CSRD dataset on disk. CSRD
(ChangShuo Radio Data) is a MATLAB spectrum-sensing data generator: it produces
baseband IQ signals together with annotations that describe, for every emitter in
every frame, what was **planned**, **executed**, and **measured**.

If you only want to read an already-generated dataset, skip to
[Reading the output](#5-read-the-output) and
[`annotation-schema.md`](annotation-schema.md).

---

## 1. Prerequisites

### MATLAB
- **MATLAB R2025a** or later.
- Required toolboxes (the run validates these at startup and fails fast if one is
  missing — see `+csrd/+runtime/+toolbox/validateRequiredToolboxes.m`):
  - **Communications Toolbox** — modulation, channel models, RF impairments.
  - **Signal Processing Toolbox** — filtering, spectral measurement.
  - **Phased Array System Toolbox** — `txsite`/`rxsite`/`raytrace` for OSM ray tracing.
  - **Antenna Toolbox** — antenna geometry used by ray tracing.
  - Parallel Computing Toolbox is **optional** (only for multi-worker runs).

### Python (only to download OSM map data — see Step 1)
- **Python 3.6+** with the `requests` package: `pip install requests`.
- Python is **not** needed to generate or read data; it is only used by the OSM
  download helper `tools/download_osm.py`. (The COCO exporter
  `tools/convert_csrd_to_coco.m` is pure MATLAB.)

### Disk
- A full OSM map set (`tools/download_osm.py`) is ~hundreds of MB. Generated
  datasets grow with the number of scenarios/frames.

---

## 2. Get the map data (OSM) — required for the default config

**Why this matters:** the default `csrd2025` config draws ~90% of scenarios from
the **OSM ray-tracing** channel and ~10% from the statistical channel
(`config/_base_/factories/scenario_factory.m`: `Map.Types = {'Statistical','OSM'}`,
`Map.Ratio = [0.1, 0.9]`). OSM scenarios read real OpenStreetMap building geometry
from `data/map/osm/`. **If that directory is empty, generation fails fast** with
`CSRD:Scenario:MissingOSMFile` (`+csrd/+factories/ScenarioFactory.m`).

Pick one option:

### Option A — Download OSM data (recommended for realistic ray tracing)
```bash
pip install requests
python tools/download_osm.py
```
The script queries the public Overpass API and writes `.osm` files under
`data/map/osm/<Category>/` (e.g. `Dense_Urban_High_Rise/`, `Urban_Canyon/`, …).
Downloading the full default set is slow (rate-limited; budget time for it); you
can stop it early — any `.osm` files already written are usable.

### Option B — Statistical channel only (no OSM download)
For a quick first run with no external data, restrict the channel to the
statistical model in your config:
```matlab
config.Factories.Scenario.PhysicalEnvironment.Map.Types = {'Statistical'};
config.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;
```
(Edit a copy of `config/csrd2025/csrd2025.m` — see [Customizing](#6-customize-the-run).)

> Audio for analog modulation (FM/AM/PM) is **bundled** in the repo
> (`+csrd/+blocks/+physical/+message/audio/*.wav`, public-domain NASA clips) — no
> download needed.

---

## 3. Generate data

From the repository root, in MATLAB:

```matlab
addpath(pwd)
addpath(fullfile(pwd, 'tools'))
simulation(1, 1, 'csrd2025/csrd2025.m')
```

`simulation(worker_id, num_workers, config_name)` (`tools/simulation.m`) loads the
config, validates toolboxes, and runs the scenarios assigned to this worker. All
three arguments are optional; the call above is the explicit single-worker form
(equivalent to `simulation()`).

Headless / batch (e.g. CI, scripting):
```bash
matlab -batch "addpath(pwd); addpath(fullfile(pwd,'tools')); simulation(1, 1, 'csrd2025/csrd2025.m')"
```

Multi-worker (each worker is a separate MATLAB process; round-robin over scenarios):
```bash
matlab -batch "addpath(pwd); addpath(fullfile(pwd,'tools')); simulation(1, 4, 'csrd2025/csrd2025.m')"   # worker 1 of 4
# ... repeat with 2, 3, 4 of 4 in parallel processes
```

---

## 4. What a run does

For each scenario the engine builds a **frozen `ScenarioPlan`**, then for each
frame instantiates transmitters/receivers, generates the modulated signal,
propagates it through the channel, applies receiver RF impairments, and records
the receiver frames. Every emitter is annotated on three truth planes —
`Design` (the plan), `Execution` (the realized analytical state), and `Measured`
(measured from the realized RX signal, which is the dataset ground truth).

---

## 5. Read the output

Data lands under a timestamped session directory:

```
data/CSRD2025/session_YYYYMMDD_HHMMSS/
├── scenarios/    scenario_000001_data.mat   (IQ signal buffers, variable: scenarioData)
├── annotations/  scenario_000001_annotation.json   (per-frame, per-emitter truth)
└── logs/         CSRD_YYYYMMDD_HHMMSS.log
```

- `Runner.Data.OutputDirectory` (default `CSRD2025`) sets the folder under `data/`.
- One annotation JSON per scenario holds `Frames[*]` → `SignalSources[*]` with
  `Truth.Design` / `Truth.Execution` / `Truth.Measured`, plus receiver info and
  RF impairments. Field-by-field meaning is in
  [`annotation-schema.md`](annotation-schema.md); a downstream-reader example
  (including COCO export) is in
  [`examples/annotation-downstream.md`](examples/annotation-downstream.md).

Read an annotation in MATLAB with `csrd.pipeline.annotation.readAnnotation`.

---

## 6. Customize the run

Copy `config/csrd2025/csrd2025.m` to a new file under `config/csrd2025/` and pass
its path to `simulation(...)`. Common knobs:

| Goal | Field | Default |
| --- | --- | --- |
| Number of scenarios | `Runner.NumScenarios` | 4 |
| Reproducible runs | `Runner.RandomSeed` | `'shuffle'` (set an integer) |
| Frames per scenario | `Factories.Scenario.FramePolicy.NumFramesPerScenario.{Min,Max}` | 4–10 |
| Frame sizes (samples) | `Factories.Scenario.FramePolicy.FrameNumSamples.Values` | `[1024 2048 4096]` |
| Target SNR range (dB) | `Factories.Channel.LinkBudget.TargetSnrRangeDb` | `[-10, 30]` |
| Channel mix (statistical/OSM) | `Factories.Scenario.PhysicalEnvironment.Map.{Types,Ratio}` | `{'Statistical','OSM'}`, `[0.1,0.9]` |

Configs inherit from `config/_base_/` via the `baseConfigs` list; see
[`configuration.md`](configuration.md) for the full contract.

---

## 7. Verify your install

Fast smoke (one baseline scenario, skips the heavy Phase-4 suite):
```matlab
addpath(pwd); addpath(fullfile(pwd, 'tools', 'ci'))
run_csrd_ci_smoke('IncludePhase4', false, 'BaselineScenarios', 1)
```
The full CI smoke (what GitHub Actions runs) is `run_csrd_ci_smoke()`
(`.github/workflows/csrd-ci-smoke.yml`). Unit tests:
```matlab
addpath(pwd); addpath(fullfile(pwd, 'tests'))
run_all_tests('unit')
```

---

## 8. Troubleshooting

| Symptom | Cause & fix |
| --- | --- |
| `CSRD:Scenario:MissingOSMFile` | `data/map/osm/` is empty but the config wants OSM. Do Step 1 (download, or switch to statistical-only). |
| Toolbox-missing error at startup | A required toolbox (Communications / Signal Processing / Phased Array System / Antenna) is not installed or licensed. |
| `CSRD:Message:NoAudioClips` | The bundled audio under `+csrd/+blocks/+physical/+message/audio/` is missing — restore it from the repo. |
| Empty / no output | Check the session `logs/` for the fail-fast error; CSRD does not silently skip — a failed scenario fails the run. |

---

See also: [docs index](README.md) · [configuration](configuration.md) ·
[annotation schema](annotation-schema.md) · [source layout](architecture/source-layout.md).
