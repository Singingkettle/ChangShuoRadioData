# Phase 15: Building OSM RayTracing and Architecture Reorganization
> Historical snapshot / 历史快照：本文记录当时的审计或交接状态，可能保留旧路径、旧 TODO 或过渡期说明。当前目录结构以 `README.md` 和 `docs/architecture/source-layout.md` 为准。

## Summary

Phase 15 fixes a real validation defect found after the formal full-coverage
run: the building OSM case was skipped because the preflight check treated
`siteviewer` as missing unless `exist(...,'file') == 2`. On this MATLAB runtime
`siteviewer` is distributed as p-code and returns `exist == 6`, while `raytrace`
is available as a `txsite` method. The previous skip therefore hid a usable OSM
building ray-tracing path.

This phase also moves the overloaded `+csrd/+utils` package into explicit
runtime, catalog, pipeline, and support packages. The public execution entry
points remain `tools/simulation.m` and `config/csrd2025/*.m`.

## Investigation

- Local probe showed `siteviewer` resolves to MATLAB p-code, `txsite` and
  `rxsite` resolve as site classes, `propagationModel` resolves as an RF
  propagation helper, and `comm.RayTracingChannel` resolves as a class.
- Existing `test_osm_building_raytracing` passes on the same runtime, proving
  the building OSM path can execute.
- The old skip logic was duplicated in the formal full-coverage validator and
  the public-entry coverage regression.

## Design Decisions

- Runtime capability checks now live in `csrd.runtime.capabilities` and use
  `which`, class detection, and an optional hidden `siteviewer` smoke probe.
- Building OSM RayTracing may be skipped only for a measured environment
  limitation. The reason must be recorded in the validation/test summary.
- `initializeOSMMap` no longer silently converts a requested RayTracing
  building OSM map into Statistical mode after siteviewer creation failure.
- The package layout is organized as:
  - `csrd.runtime`: logging, configuration loading, system/toolbox/capability
    probes, map runtime helpers.
  - `csrd.catalog`: regional spectrum catalogs and reusable profiles.
  - `csrd.pipeline`: blueprint, contracts, measurement, annotation,
    link-budget, and scenario truth helpers.
  - `csrd.support`: documentation audit, validation harnesses, hashing,
    random/optimization helpers, and internal support classes.

## Cleanup Record

- Removed the old `+csrd/+utils` package directory after moving its contents to
  the target packages.
- Updated production code, tests, and current documentation references from
  `csrd.utils.*` to the new package names.
- Historical audit documents may still mention older package paths when
  describing past phases; new production code must not add `csrd.utils.*`.

## Verification Plan

- `RFPropagationCapabilitiesTest`
- `test_osm_building_raytracing`
- `test_empty_osm_raytracing`
- `test_phase13_full_coverage_config_load`
- `test_simulation_entrypoint_coverage_sweep('Mode','extended','IncludeBuildingOSM',true,'EnforceCoverage',true)`
- `simulation(1,1,'csrd2025/csrd2025_full_coverage_validation.m')`

## Verification Results

2026-04-30:

- RF capability probe resolved `siteviewer` as p-code (`exist == 6`) and
  found `txsite`, `rxsite`, `propagationModel`, `raytrace`, and
  `comm.RayTracingChannel`; building OSM capability was true.
- `test_osm_building_raytracing`, `test_empty_osm_raytracing`, and
  `test_phase13_full_coverage_config_load` passed.
- `run_all_tests('phase2')`, `phase3`, `phase4`, `phase8`, and `phase9`
  passed after the package migration.
- Extended public-entry coverage passed with 43 passed, 0 skipped, covering
  building OSM, flat OSM, all configured modulation families, RF methods,
  regulatory regions, and antenna/entity combinations.
- Formal full-coverage validation from `tools/simulation.m` completed with
  47 passed, 0 skipped, 0 failed.
- `run_all_tests('unit')` passed with 54/54.
- The first full `run_all_tests('regression')` exposed stale post-migration
  references in the Phase 6 performance diagnostics and downstream example,
  plus missing I/O comments in the new RF capability helper. After fixing
  those, the full regression suite passed with 32/32.
