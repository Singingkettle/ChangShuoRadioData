# Phase 11: Config And Dead-Code Cleanup
> Historical snapshot / 历史快照：本文记录当时的审计或交接状态，可能保留旧路径、旧 TODO 或过渡期说明。当前目录结构以 `README.md` 和 `docs/architecture/source-layout.md` 为准。

## Scope

Phase 11 continues after the Phase 0-10 validation snapshot. The cleanup rule is
strict evidence only: remove or harden code only when the call chain,
configuration entrypoints, tests, and prior phase documents show that the path
is stale, misleading, or inconsistent with the refactor invariants.

Safety snapshot:

- Commit: `998f186 chore: snapshot before config and dead-code cleanup`
- Excluded from snapshot: ignored artifacts, `artifacts/`, `data/`

## Audit Map

| Area | Evidence | Decision |
| --- | --- | --- |
| `config/_base_/factories/transmit_factory.m` / `receive_factory.m` | Both exposed `Real.SDR` blocks with empty handles and `Supported=false`. Static reference search found no production consumer. | Delete the placeholders so configs expose only runnable factory types. |
| `CommunicationBehaviorSimulator.initializeTransmissionScheduler` | Missing `TransmissionPattern.DefaultType` logged a warning and silently used `Continuous`; base config and default config already provide the field. | Convert to fail-fast `CSRD:Scenario:MissingTransmissionPatternDefaultType`; tests that build minimal configs must state the field explicitly. |
| `CommunicationBehaviorSimulator.setupImpl` receiver config | Struct-shaped `Receiver.SampleRate` / `Receiver.NumAntennas` was kept for backward compatibility and introduced hidden RNG draws. Current config and tests use scalar values. | Reject range structs and invalid scalar values; receiver observation is no longer randomly drawn at setup. |
| Tx/Rx velocity into construction | `generateScenario*Configurations` omitted velocity initially, while `setupTransmitterInfo` and `validateRxPlanIntoRxInfo` could default missing velocity to `[0,0,0]`. That can erase mobility before Doppler truth is built. | Publish `Physical.Velocity` from entities, require it in Tx/Rx construction, and keep frame-level synchronization as the update source for moving entities. |
| Tx antenna count into modulation | `buildSegmentConfigFromTxScenario` did not pass `Hardware.NumAntennas` to `ModulationFactory`, and `OFDM.genModulatorHandle` hard-coded `NumTransmitAntennas = 2`. A multi-scenario smoke exposed stale OFDM reshape state. | Require Tx antenna count in segment construction, pass it into modulation, and remove the OFDM hard-coded antenna override. |
| `ModulationFactory` failure logging | The catch path attempted to `jsonencode` full System objects, including function handles, which could mask the original modulation failure. | Log a sanitized modulator summary instead of the raw object so diagnostics remain safe and actionable. |
| Empty `CommunicationBehaviorSimulator` config | Phase 1 empty-entity fail-fast test constructs the simulator with an empty struct. Treating that as user config made the scheduler fail on missing transmission pattern before the entity contract was checked. | Empty structs are normalized to the simulator default config; non-empty user configs remain explicit and fail fast when required fields are missing. |
| `tests/regression/test_refactoring.m` annotation check | The test still looked for optional v1 `SignalSources.Planned/Realized` fields. The current release explicitly forbids v1 top-level fields. | Repoint the regression to v2 `Truth.Design/Execution` bandwidth fields and fail if v1 top-level keys appear. |
| Physical environment `TimeResolution` default | Base and default configs set it; `ScenarioFactory` still backfills a custom missing config. | Record as follow-up, not deleted in this pass, because standalone simulator construction remains a public path. |
| Message `SegmentID` / `SeedValue` aliases | Unit tests explicitly preserve these as public compatibility contracts. | Retain in this pass; do not remove without a separate owner decision and migration window. |

## Verification Plan

1. Targeted checks for new static cleanup gate and affected unit tests.
2. Phase gates touching config, construction, measurement, regulatory planning,
   and public entry coverage.
3. Full `unit`, `regression`, and `integration` selectors where available.
4. Extended `tools/simulation.m` entry coverage sweep, then verify no tracked
   temporary output is introduced.

## Results

Implemented cleanup/hardening:

- Removed non-runnable `Real.SDR` placeholders from transmit/receive base
  factory configs.
- Replaced silent transmission-pattern fallback with
  `CSRD:Scenario:MissingTransmissionPatternDefaultType`.
- Rejected legacy receiver range structs for sample rate and antenna count.
- Required Tx/Rx physical velocity through scenario generation and construction.
- Passed Tx antenna count into modulation and removed the OFDM two-antenna
  hard-code.
- Updated refactoring regression to annotation v2 only and added
  `test_no_dead_code_phase11`.

Retest evidence:

- Targeted: `test_no_dead_code_phase11`,
  `ConstructionFailFastTest`, `AllModulationFactorySmokeTest`,
  `ScenarioFactoryRegulatoryChinaTest`, `SetupReceiversFailFastTest`,
  `test_refactoring` all passed.
- Phase gates: `run_all_tests('phase0')`, `phase1`, `phase2`, `phase3`,
  `phase4`, `phase6`, `phase7`, `phase8`, and `phase9` all passed. There is
  no `phase5` selector in `tests/run_all_tests.m`.
- Full selectors: `run_all_tests('unit')` passed 51/51,
  `run_all_tests('regression')` passed 26/26, and
  `run_all_tests('integration')` found no `tests/integration` folder and
  therefore ran 0 tests.
- Extended entrypoint coverage:
  `test_simulation_entrypoint_coverage_sweep('Mode','extended','IncludeBuildingOSM',true,'EnforceCoverage',true)`
  passed with 42 executed cases, 1 capability skip, 5 regions, 8 bands,
  23 modulation configurations, 6 RF impairment/nonlinearity methods, and
  7 antenna/Tx/Rx combinations.
- Final hygiene: `git diff --check` reported only CRLF conversion warnings and
  no whitespace errors. No `csrd_simulation_output` directory was present.
