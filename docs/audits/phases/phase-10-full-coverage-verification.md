# Phase 10 - Full Coverage Verification

Version: v0.10.0-draft
Date: 2026-04-29

## Goal

Phase 10 is the post-refactor full-flow verification gate. It checks the
complete refactor from Phase 0 through Phase 9, plus the later regulatory
spectrum and relative-Doppler hardening, against the repository's core
invariant:

> the generated signal, scene state, and annotation describe the same event.

This phase does not introduce a new modeling feature by default. It is a
verification-and-repair loop. Any failure found here is handled in the same
four-step workflow used by the refactor:

1. investigate the failure and the cross-module contract it touches,
2. document the design or verification decision,
3. make the narrow code/test/schema change required,
4. rerun the smallest repro, the affected phase gate, and the public-entry
   coverage gate.

## Verification Targets

- Blueprint facts: region, monitoring band, Tx frequency, bandwidth,
  modulation, antenna count, mobility, channel selection, and provenance.
- Construction facts: emitted waveform sample rate, Tx/Rx RF impairments,
  channel propagation, relative Doppler, receiver-view projection, OSM or
  statistical environment path, and explicit fallback metadata.
- Measurement and annotation facts: annotation v2 `Truth.Design`,
  `Truth.Execution`, and `Truth.Measured` remain populated and numerically
  consistent with the produced IQ.
- Regulatory planning: CN/US/EU/JP/KR catalogs constrain frequency, bandwidth,
  service class, modulation family, source references, and radar exclusion.
- Public entrypoint: the same behavior is visible through `tools/simulation.m`,
  not only through lower-level unit or factory tests.

## Test Gates

The selected mode for this phase is the full long run.

1. Preflight:
   - `git status --short`
   - `git diff --name-status bc3abc438fbd65363db102efb23ba36a4296a392`
   - `git diff --check bc3abc438fbd65363db102efb23ba36a4296a392`
2. Phase gates:
   - `run_all_tests('phase0')`
   - `run_all_tests('phase1')`
   - `run_all_tests('phase2')`
   - `run_all_tests('phase3')`
   - `run_all_tests('phase4')`
   - `run_all_tests('phase6')`
   - `run_all_tests('phase7')`
   - `run_all_tests('phase8')`
   - `run_all_tests('phase9')`
   - `run_all_tests('unit')`
   - `run_all_tests('regression')`
   - `run_all_tests('integration')`
3. Public-entry extended sweep:
   - `test_simulation_entrypoint_coverage_sweep('Mode','extended')`
   - covers regulatory and legacy paths, OSM flat/building probes,
     statistical maps, all configured modulation families, all configured RF
     nonlinearity methods, multi-Tx, multi-Rx, and antenna-count combinations.
4. Reproducibility and annotation consistency:
   - fixed-seed public-entry repeat for key blueprint and annotation fields,
   - annotation v2 readback requiring runtime header and sources,
   - regulatory reverse checks for analog broadcast, LTE/NR approximation, and
     radar exclusion.

Generated `csrd_simulation_output` directories are temporary validation
artifacts. They may be inspected during failure analysis and removed after the
relevant result is recorded.

## Execution Log

2026-04-29 preflight:

- Working tree is intentionally dirty with the Phase 0-9 refactor, Phase 8
  regulatory spectrum package, Phase 9 simulation-entry coverage, and review
  hardening changes.
- The diff against `bc3abc438fbd65363db102efb23ba36a4296a392` includes the
  mandatory Phase 8 runtime files:
  `+csrd/+catalog/+spectrum/{RegionSpectrumCatalog,RegionSpectrumSelector,RegulatoryValidator}.m`
  and
  `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/allocateFrequenciesFromRegulatoryPlan.m`.
- `git diff --check bc3abc438fbd65363db102efb23ba36a4296a392` reported no
  whitespace errors; it only emitted line-ending conversion warnings.

2026-04-29 phase gates:

- `run_all_tests('phase0','verbose',true)` passed: 8/8, elapsed 246.51 s.
  The gate covered startup hooks and the 12-scenario baseline smoke. The run
  emitted the known non-fatal Tx RF resampling approximation warnings.
- `run_all_tests('phase1','verbose',true)` passed: 8/8, elapsed 18.86 s.
  The gate covered the signal struct contract, burst-aware channel seeds,
  Rx antenna compatibility, RF impairment export, and the dataflow smoke.
- `run_all_tests('phase2','verbose',true)` passed: 9/9, elapsed 8.40 s.
  The gate covered blueprint feasibility, validation reports, profile loading,
  deterministic blueprint hashes, resampling, channel fallback removal, and
  frequency allocation strategy checks.
- `run_all_tests('phase3','verbose',true)` passed: 9/9, elapsed 22.76 s.
  The gate covered construction fail-fast behavior, receiver-view projection,
  setup validation, blueprint mobility, catch-swallow removal, provenance
  flow, and the multi-Rx construction smoke.
- `run_all_tests('phase4','verbose',true)` passed: 10/10, elapsed 1044.73 s.
  The gate covered measurement utilities, relative Doppler, channel
  propagation fail-fast behavior, annotation v2 source construction,
  receiver-view persistence, measurement completeness, dead-code removal, the
  high-speed Doppler deterministic regression, and 20-scenario measured-truth
  coverage. The measured-truth run observed 108 sources with 1.0 coverage for
  the key SourcePlane and FramePlane measurement fields.
- `run_all_tests('phase6','verbose',true)` passed: 6/6, elapsed 9.62 s.
  The gate covered annotation v2 readback, COCO conversion, release readiness,
  performance diagnostics, and CI readiness against the 1000-scenario final
  baseline metadata.
- `run_all_tests('phase7','verbose',true)` passed: 1/1, elapsed 2.29 s.
  The downstream documentation readiness gate read annotation v2 and produced
  the expected example conversion surface.
- `run_all_tests('phase8','verbose',true)` passed: 10/10, elapsed 237.42 s.
  The gate covered CN/US/EU/JP/KR catalog loading, regulatory validation,
  fixed-seed selection, China regulatory scenario construction, all-modulation
  factory smoke, annotation v2 readback, regulatory pipeline smoke, region
  matrix smoke, and unified regulatory coverage. The unified sweep observed 8
  bands, 5 service classes, and 5 modulation families.
- `run_all_tests('phase9','verbose',true)` passed: 2/2, elapsed 326.86 s.
  The public `simulation.m` quick sweep passed 15 cases with 0 skips and
  covered regulatory bands, legacy modulation probes, RF nonlinearity methods,
  OSM flat-terrain fallback, multi-Tx, multi-Rx, and multi-antenna cases.
- `run_all_tests('unit','verbose',true)` passed: 51/51, elapsed 56.91 s.
  This wider unit gate covered channel blocks, modulation factory smoke,
  annotation v2, Doppler, blueprint validation, construction fail-fast,
  regulatory catalog/selector/validator, RF front-end tests, seed contracts,
  receiver views, and utility packages.
- `run_all_tests('integration','verbose',true)` completed: 0/0, elapsed 0.01 s.
  The selector found no `tests/integration` folder in this workspace.
- `run_all_tests('regression','verbose',true)` passed: 25/25, elapsed
  2411.62 s. The wider regression gate reran bandwidth consistency, baseline
  smoke, measured truth, OSM/channel regressions, regulatory sweeps, public
  `simulation.m` quick coverage, startup hooks, and downstream/release checks.

2026-04-29 public-entry extended verification:

- `test_simulation_entrypoint_coverage_sweep('Mode','extended',
  'IncludeBuildingOSM',true,'EnforceCoverage',true)` passed. The sweep built
  43 cases, executed 42, and skipped `osm_building_CN_ISM_24` because the
  local MATLAB runtime lacks RF propagation site functions. Coverage included
  5 regions, 8 bands, 23 modulation families, 6 RF nonlinearity methods, OSM
  flat-terrain fallback, statistical maps, multi-Tx, multi-Rx, and 7 antenna
  combinations.
- A focused OSM diagnostic rerun for cases 9-10 passed with 1 executed flat
  OSM case and 1 building OSM skip. The flat OSM case explicitly logged the
  flat-terrain ray-tracing fallback for the geometry-free open-ocean OSM file.
- A fixed-seed public-entry repeat using the extended CN FM broadcast config
  passed. The two newest sessions had identical `Truth.Design`,
  `ReceiverView`, `Truth.Execution.GeometrySnapshot`, and `DopplerShiftHz`.
  An initial diagnostic comparison script used the wrong `jsondecode` indexing
  shape and failed after both simulation runs completed; the corrected
  comparison passed on the same two outputs.

## Open Items

- No `csrd_simulation_output` directories were found under the repository
  after the full run.
- Test-generated outputs are under ignored `artifacts/` paths or ignored smoke
  baseline files. They are not part of the source patch.
- No Phase 10 production-code repair was required because all mandatory gates
  passed. The only failed command was a diagnostic post-processing script with
  the wrong `jsondecode` indexing shape; the corrected comparison passed on
  the same fixed-seed outputs.

## Closure

Phase 10 confirms that the Phase 0-9 refactor and the later regulatory
spectrum / relative-Doppler hardening are wired through the project-level
entrypoints available in this workspace. The full gate set passed with one
documented environment limitation: building OSM ray-tracing coverage is skipped
because this MATLAB runtime lacks RF propagation site functions, while the
  flat-terrain OSM fallback path is covered and explicitly logged.

> Phase 15 correction: the building OSM skip reason above was later proven to
> be an overly strict capability check. On the same runtime, `siteviewer`
> exists as p-code and the building OSM smoke path executes. Phase 15 replaces
> the old check with `csrd.runtime.capabilities.rfPropagationCapabilities`.
