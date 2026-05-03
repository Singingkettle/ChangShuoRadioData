# CSRD Source Layout

## Production Entry Points

- `tools/simulation.m` is the formal generation entry point.
- `config/csrd2025/*.m` contains public generation configurations.
- `+csrd/SimulationRunner.m` and `+csrd/+core/@ChangShuo` own the main
  simulation pipeline.

## Package Responsibilities

- `+csrd/+blocks`: scenario, physical channel, modulation, message, and RF
  processing blocks.
- `+csrd/+factories`: factory objects that construct production blocks from
  configuration.
- `+csrd/+runtime`: runtime services such as logging, configuration loading,
  toolbox checks, system information, RF propagation capabilities, and map
  helper probes.
- `+csrd/+catalog`: source-backed regulatory spectrum catalogs and reusable
  configuration profiles.
- `+csrd/+pipeline`: helpers that protect cross-module contracts for blueprint,
  measurement, annotation, link budget, and scenario truth.
- `+csrd/+support`: internal documentation, validation, hashing, random,
  optimization, and test-support-adjacent utilities.

## Rules

- Do not introduce new production code under `+csrd/+utils`.
- Prefer the narrow package matching the responsibility above.
- Runtime fallbacks must be visible in metadata or annotations; they must not
  silently change the executed physical model.
- Historical audit documents may preserve old paths when documenting past work,
  but current documentation and examples should use the new package names.

## Generated Output Locations

- Formal dataset generation writes under `data/<DatasetName>/`; `data/` is
  ignored and must not be added to git.
- Automated test runs write under `artifacts/tests/runs/`.
- Generated test configs write under `artifacts/tests/generated_configs/`.
- Visual inspection products, including spectrogram overlay PNGs, write under
  `artifacts/visual_checks/`.
- Temporary diagnostics may live under `artifacts/` while running, but durable
  conclusions belong in `docs/audits/`.
- Legacy `csrd_simulation_output` folders are not valid output roots and should
  be removed by `tools/maintenance/clean_csrd_artifacts.m`.
