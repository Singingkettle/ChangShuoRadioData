# CSRD Test Layout

`tests/` stores project tests by purpose instead of leaving executable scripts in the repository root.

## Directories

```text
tests/
├── run_all_tests.m         # Maintained regression test entry point
├── README.md               # This file
├── regression/             # End-to-end and targeted regression tests
├── integration/            # Legacy matlab.unittest integration tests
└── unit/                   # Legacy matlab.unittest unit tests
```

## Regression Tests

The actively maintained regression suite lives in `tests/regression/`:

- `test_empty_osm_raytracing.m`
- `test_osm_building_raytracing.m`
- `test_entity_snapshot_consistency.m`
- `test_bandwidth_consistency.m`
- `test_map_config_validation.m`
- `test_refactoring.m`

These tests cover the spectrum-sensing simulation pipeline, including:

- empty/building OSM ray-tracing behavior
- communication snapshot persistence across frames
- bandwidth consistency between scenario planning and realized modulation
- map configuration validation
- end-to-end multi-frame regression coverage

## Recommended Usage

From the project root:

```matlab
addpath(fullfile(pwd, 'tests'));
results = run_all_tests();
```

Run a single regression test directly:

```matlab
addpath(fullfile(pwd, 'tests', 'regression'));
test_refactoring
```

Or from the command line:

```powershell
matlab -batch "addpath(fullfile(pwd,'tests','regression')); test_refactoring"
matlab -batch "addpath(fullfile(pwd,'tests')); results = run_all_tests(); disp(results.Success)"
```

## Conventions

- Do not place new test scripts in the repository root.
- Prefer `tests/regression/` for executable scenario and bug-regression scripts.
- Use `tests/unit/` and `tests/integration/` for `matlab.unittest` class-based tests.
- Keep test fixtures local to the test that owns them unless reuse is necessary.
