# Phase 16: OSM RayTracing Stress, Artifact Governance, and Visual QA

## Summary

Phase 16 turns the earlier Phase 13/15 coverage checks into a formal
OSM-focused generation run through `tools/simulation.m`. The goal is to prove
that building OSM RayTracing, empty/no-building OSM flat-terrain fallback,
multi-transmitter/multi-receiver layouts, antenna-count variation, modulation
coverage, and regulatory frequency planning all survive the same production
entry point.

Generated data and visual QA products remain outside git. Source changes may
add configs, validators, tests, docs, and maintenance tools, but `.mat` data,
PNG spectrograms, generated configs, and test run directories stay under
ignored `data/` or `artifacts/` roots.

## Design

- `config/csrd2025/csrd2025_osm_raytracing_validation.m` is the formal Phase
  16 config. It writes generated data under
  `data/CSRD2025_osm_raytracing_validation`.
- `csrd.support.validation.runFullCoverageValidation` now recognizes
  `CoverageValidation.Mode = 'osm_raytracing_stress'` and appends OSM
  RayTracing matrix cases:
  - building OSM regulatory cases,
  - empty/no-building OSM flat-terrain regulatory cases,
  - representative building OSM modulation cases, while all configured
    modulation handles remain covered by the existing non-OSM full-modulation
    sweep,
  - Tx/Rx and Tx/Rx antenna combinations up to the configured 4x4 case.
- `Truth.Execution` now carries optional RayTracing execution metadata:
  `MapProfile`, `RayCount`, and `ChannelFallback`. This makes the flat OSM
  fallback auditable in the saved annotation instead of only in transient
  channel structs.
- `tools/visualization/render_csrd_spectrogram_overlays.m` renders receiver IQ
  spectrograms and overlays annotation v2 receiver-view frequency boxes.
- `tools/maintenance/clean_csrd_artifacts.m` provides a safe dry-run-first
  cleanup path for ignored test artifacts, visual checks, and legacy
  `csrd_simulation_output` folders.

## Design Adjustment: OSM Modulation Scope

The first Phase 16 formal run proved that building OSM RayTracing is genuinely
executing, but also showed that putting every modulation handle through
building OSM by default makes the single-worker validation run impractically
long. A 1Tx/2Rx building case took about 170 seconds and a 2Tx/1Rx building
case took about 145 seconds on the local workstation.

The default formal Phase 16 config therefore keeps OSM RayTracing broad across
map type, region, frequency band, Tx/Rx count, and antenna count, but uses a
representative modulation subset on building OSM. The full modulation inventory
is still covered by the Phase 9/Phase 13 modulation sweeps, so the default
Phase 16 run remains validation-grade instead of becoming a multi-hour
training-grade generation job.

## Defect Loop: Tx Antenna Compatibility

During the formal run, the `JP_ISDB_UHF` building OSM case requested
`3 Tx / 2 Rx / 4 Tx antennas / 4 Rx antennas` and successfully generated the
RayTracing signal, but the post-case validator failed because the annotation
reported `Truth.Design.NumTransmitAntennas = 2`. The root cause was not OSM:
the regulatory transmitter planner hard-coded OFDM to two transmit antennas
even when the case config requested four, and the OFDM modulator also contained
a pilot-allocation branch that could silently reduce `NumTransmitAntennas`.

The repair keeps antenna count as a contract fact. The regulatory planner now
honors the configured Tx antenna range for multi-Tx-capable modulation
families, fixed/single-antenna families remain at one antenna, and the OFDM
pilot allocation shrinks the pilot count rather than mutating the hardware
antenna count. Mixed regulatory bands that can randomly choose single-antenna
families use a one-antenna expectation in the Phase 16 OSM matrix, while
OFDM/QAM-only bands continue to cover multi-antenna building RayTracing.

## Defect Loop: Target-Rate Frequency Translation

The first spectrogram overlay review exposed a real signal/annotation
misalignment on narrow-band modulation cases. For example, a DSB-AM case
planned `ReceiverView.ProjectedCenterOffsetHz = -9.67 MHz`, but the rendered
IQ energy and measured centroid appeared near baseband. The root cause was in
`TRFSimulator`: it applied the complex carrier translation at the modulator
output sample rate, then resampled to the receiver rate. When a narrow
modulator produced only hundreds of kHz of sample rate, any planned offset
outside that low-rate Nyquist interval aliased before the receiver-rate
resampling stage.

The repair changes the transmitter RF chain to resample the impaired baseband
signal to `TargetSampleRate` first, then apply the complex exponential
frequency translation on the same sample-rate grid used by ReceiverView and
annotation. `TRFSimulatorTest.frequencyTranslationAvoidsLowRateAlias` pins this
with a 640 kHz input-rate / 20 MHz target-rate case at `-9.67 MHz`.

## Defect Loop: Antenna Coverage Accounting

After the TRF fix, the full `simulation.m` Phase 16 run completed all 68
generation cases, including `multi_4tx_4rx_4txant_4rxant`, but failed in the
final coverage assertion with "Coverage did not include antenna-count
variation." Annotation inspection showed the generated sources did carry
`Truth.Design.NumTransmitAntennas = 4`; the defect was in the validator, which
derived antenna coverage only from formatted strings such as
`4tx-4rx-4txant-4rxant`.

The coverage accumulator now records numeric `TxAntennaCounts` and
`RxAntennaCounts` alongside the human-readable combo label. The final gate
checks these numeric fields directly, so a correct generation run is not
rejected by string matching.

## Artifact Policy

- Formal generated data: `data/<DatasetName>/`.
- Test run outputs: `artifacts/tests/runs/`.
- Generated test configs: `artifacts/tests/generated_configs/`.
- Visual QA PNG/contact sheets: `artifacts/visual_checks/`.
- Persistent audit conclusions: `docs/audits/`.
- `data/` and `artifacts/` must not be tracked by git.

## Verification Plan

- Preflight:
  - `git status --short`
  - `git status --short --ignored`
  - `git diff --check`
  - RF propagation capability diagnostic.
- Targeted:
  - `test_osm_building_raytracing`
  - `test_empty_osm_raytracing`
  - `test_phase16_osm_raytracing_validation_config`
  - `test_phase16_artifact_governance`
  - `test_phase16_spectrogram_overlay_renderer`
- Formal generation:
  - `simulation(1,1,'csrd2025/csrd2025_osm_raytracing_validation.m')`
  - `csrd.support.validation.validateOsmRayTracingRun(...)`
  - Spectrogram overlay rendering through the configured visualization hook.
- Regression:
  - `run_all_tests('phase8')`
  - `run_all_tests('phase9')`
  - `run_all_tests('unit')`
  - `run_all_tests('regression')`
  - `test_simulation_entrypoint_coverage_sweep('Mode','extended','IncludeBuildingOSM',true,'EnforceCoverage',true)`

## Acceptance Notes

This phase is considered complete only when building OSM cases execute on a
capable MATLAB runtime, empty OSM cases remain valid and publish fallback
metadata, OSM outputs report `Truth.Execution.ChannelModel = 'RayTracing'`,
spectrogram GT rectangles are in-bounds, and git status contains no unignored
generated data or temporary artifacts.
