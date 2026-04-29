# Phase 9 - Simulation Entry Coverage

Version: v0.9.0-draft
Date: 2026-04-28

## Goal

Phase 9 verifies that the refactored regulatory, modulation, RF impairment,
antenna, map, channel, and annotation contracts are visible from the public
entrypoint:

```matlab
tools/simulation.m
```

Earlier Phase 8 tests exercised `SimulationRunner` and lower-level factories
directly. This phase adds a higher-level gate: generated configs are loaded
through `csrd.utils.config_loader`, then executed by `simulation(1, 1, path)`.
The resulting annotation v2 files must prove that the generated signal, scene
state, and annotation still describe the same event.

## Coverage Matrix

The coverage sweep is split into two modes.

`quick` is suitable for curated regression suites:

- regional regulatory smoke cases,
- one statistical map case,
- one OSM flat-terrain case,
- representative legacy modulation cases,
- representative RF nonlinearity methods,
- representative multi-Tx, multi-Rx, and antenna-count combinations.

`extended` is the manual large sweep requested for this refactor:

- all currently configured digital and analog modulation families,
- all configured Tx/Rx memoryless-nonlinearity method names,
- CN/US/EU/JP/KR representative regulatory bands,
- statistical maps and selected OSM maps,
- multi-transmitter and multi-receiver cases,
- SISO and multi-antenna combinations.

The sweep intentionally excludes radar, radiolocation, and radionavigation
emitter services, matching Phase 8.

## Test Artifacts

The regression dynamically writes small config functions under:

```text
artifacts/tests/generated_configs/simulation_entrypoint_coverage/
```

Each generated config writes its run outputs under:

```text
artifacts/tests/runs/simulation_entrypoint_coverage/<case-name>/
```

The test reads the newest `session_*` directory for each case and validates:

- annotation v2 exists and contains successful receiver frames,
- expected Tx/Rx counts are reflected in source counts,
- `Truth.Design.ModulationFamily` matches the requested legacy family or the
  selected regulatory catalog family,
- regulatory design facts still match catalog constraints,
- TX and RX nonlinearity method selections are exported,
- OSM flat terrain or building cases report the expected channel model when
  the local MATLAB installation supports that path,
- antenna counts are surfaced through `Truth.Design.NumTransmitAntennas` and
  receiver frame count.

## Findings During Implementation

The all-modulation probe found three latent bugs that random generation could
hide:

- `APSK` depended on unavailable helper functions (`randfixedsum` and
  `minL1intlin`) for ring allocation.
- `GMSK` and `MSK` attempted to access `FSK.pureModulator`, but the parent
  class declared the property as private.
- Legacy OFDM/OTFS/SC-FDMA planning did not provide realistic multicarrier
  modulator config, so sample rates could fall below the RF impairment chain's
  practical floor.

The fixes are intentionally narrow:

- `APSK` now uses a local positive composition sampler.
- `FSK` exposes its internal pure-modulator handle to subclasses as protected.
- legacy scenario modulation planning now supplies explicit modulator config
  for OFDM, OTFS, SC-FDMA, and OQPSK.
- pulse-shaped modulators receive deterministic default shaping fields through
  `ModulationFactory`.

## Tooling Limitation

The local installation exposes RF propagation functions such as `txsite`,
`siteviewer`, `propagationModel`, and `raytrace`, but the toolbox validator
does not report a full RF Propagation Toolbox license. Therefore:

- flat-terrain OSM fallback is always part of the sweep,
- building OSM ray tracing is included only when the selected OSM file exists
  and the local MATLAB runtime can initialize that path,
- skipped building-raytracing coverage is reported explicitly and must not be
  described as passed.

## Exit Criteria

Phase 9 is considered complete when:

1. the all-modulation factory smoke test passes,
2. the `simulation.m` quick sweep passes and is safe for curated regression,
3. the extended sweep has been run manually for the current workspace,
4. any failure from the extended sweep is either fixed and rerun, or recorded
   as an environment/toolbox limitation with a concrete reason.

## Execution Log

2026-04-28:

- `AllModulationFactorySmokeTest` passed.
- `test_simulation_entrypoint_coverage_sweep('Mode','quick')` passed:
  15 public-entry cases, 0 skipped.
- `test_simulation_entrypoint_coverage_sweep('Mode','extended')` passed:
  42 public-entry cases passed, 1 building-OSM case skipped by local
  environment capability. The executed matrix covered 5 regions, 8
  regulatory bands, 23 modulation families, 6 RF nonlinearity methods, OSM
  flat terrain, statistical maps, multi-transmitter, multi-receiver, and
  multi-antenna combinations.

Additional fixes from extended coverage:

- The legacy modulation planner now stores `RolloffFactor` in the emitted
  modulation config before building OQPSK pulse-shaping config.
- The extended test matrix treats OTFS and SC-FDMA as single-transmit-antenna
  legacy probes because the current antenna compatibility profile allows
  OTFS only at 1 Tx antenna and uses the `SC-FDMA` spelling rather than the
  legacy `SCFDMA` TypeID row. Multi-antenna coverage is still exercised with
  QAM and OFDM-compatible cases.

The quick Phase 9 suite is now available through:

```matlab
run_all_tests('phase9')
```

## Cross-Phase Regression Checkpoint

2026-04-28:

- `run_all_tests('phase0','verbose',true)` passed: 8/8. The smoke baseline
  remains functional under the Phase 8 default regulatory planner, though
  wideband catalog picks can make some scenarios slow.
- `run_all_tests('phase1','verbose',true)` initially exposed a test-design
  issue: the legacy dataflow smoke inherited the unconstrained weighted
  regulatory selector and picked `CN_IMT_2600` with 10/40 MHz emitters and
  multi-antenna OFDM/QAM, turning a contract smoke into a wideband stress run
  and failing the historical 60 s wallclock gate.
- The Phase 1 smoke was kept regulatory-backed but pinned to `CN_SRD_433`
  with `RestrictEmittersToFixedBand=true`. Rerun passed: 8/8; the smoke
  scenario wallclock was 11.74 s and the annotation carried `CN_SRD_433`
  OOK/GFSK design facts with 12.5 kHz bandwidth.
- `run_all_tests('phase2','verbose',true)` passed: 9/9.
- `run_all_tests('phase3','verbose',true)` passed: 9/9.
- `run_all_tests('phase4','verbose',true)` passed: 9/9. The measured-truth
  coverage report reached full SourcePlane and FramePlane key-field coverage
  for the exercised scenarios.
- `run_all_tests('phase6','verbose',true)` passed: 6/6, including annotation
  v2 readback, COCO conversion fixtures, release readiness, and CI readiness.
- `run_all_tests('phase7','verbose',true)` passed: 1/1 downstream documentation
  readiness check.
- No `csrd_simulation_output` temporary directories were found under the
  repository after the simulation-entry and cross-phase regression sweeps.

Residual observation:

- Several regression sweeps still emit non-fatal approximate-resampling
  warnings from `TRFSimulator/resampleToTarget`. They did not break annotation,
  bandwidth, release-readiness, or simulation-entry checks, but remain a
  candidate for a later precision cleanup pass.
