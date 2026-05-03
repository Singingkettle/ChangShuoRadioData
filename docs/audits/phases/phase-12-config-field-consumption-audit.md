# Phase 12: Config Field Consumption Audit
> Historical snapshot / 历史快照：本文记录当时的审计或交接状态，可能保留旧路径、旧 TODO 或过渡期说明。当前目录结构以 `README.md` 和 `docs/architecture/source-layout.md` 为准。

## Scope

Phase 12 audits configuration fields that remain after the Phase 11 cleanup.
The rule is strict evidence only: a field is removed only when static reference
search, call-chain review, and tests show that it is not consumed by production
code and does not define a public compatibility contract.

## Findings

| Field or area | Consumption evidence | Decision |
| --- | --- | --- |
| `config/_base_/factories/channel_factory.m` | Loaded by `config/csrd2025/csrd2025.m` and passed into `csrd.factories.ChannelFactory` by `ChangShuo.setupImpl`. | Keep the file; it is on the main channel propagation path. |
| `Factories.Channel.ChannelModels.*` | `ChannelFactory.getChannelBlock` resolves handles and applies each model `Config`. | Keep. |
| `Factories.Channel.LinkBudget` | `ChannelFactory` uses it for distance-based SNR, carrier frequency, noise bandwidth, and minimum distance. | Keep. |
| `Factories.Channel.DefaultModels` | `ChannelFactory.resolveChannelModelNameFromConfig` uses it when the scenario requests `Statistical` or an empty model. | Keep. |
| `Factories.Channel.NoValidPathFallback` | `ChannelFactory` forwards it to ray tracing and link metadata. | Keep. |
| `Factories.Channel.Types` | No production consumer; channel choice is scenario `Map.*.ChannelModel` plus `DefaultModels`, not this list. | Remove. |
| `Factories.Channel.SNR.Min/Max` | No production consumer; AWGN SNR is computed from link budget or the model's own `Config.SNRdB`. | Remove. |
| `Factories.Channel.LogDetails` / `Description` | Unlike transmit/receive factories, `ChannelFactory` does not inspect these fields for type discovery or logging policy. | Remove. |
| `Factories.Channel.PreferredType` in regression tests | Tests wrote it, but `ChannelFactory` never read it, so it did not actually pin AWGN/Rayleigh/Rician. | Remove and replace with `Scenario.PhysicalEnvironment.Map.*.ChannelModel`. |
| Baseline cohort channel names | Several cohort names claimed specific statistical channels while the no-op preference meant execution still resolved through defaults. | Apply the cohort preference through the scenario map channel model; rename the 2.4 GHz statistical cohorts away from old RT wording. |
| Other factory metadata fields | `TransmitFactory` / `ReceiveFactory` use `Types` and exclude metadata during type discovery; `ScenarioFactory` consumes scenario `Types`; `MessageFactory` and `ModulationFactory` retain documented metadata patterns. | Defer broad deletion; no strict proof of dead public fields in this pass. |

## Implementation Notes

- Channel-model override now uses existing scenario configuration:
  `Factories.Scenario.PhysicalEnvironment.Map.Statistical.ChannelModel`.
- OSM channel selection continues to use
  `Factories.Scenario.PhysicalEnvironment.Map.OSM.ChannelModel`.
- `ChannelPreference` remains as a blueprint concept in validator tests and
  phase documents; this phase removes only the unused `Factories.Channel`
  preference field.

## Verification Plan

- Static reverse-sample gate:
  `test_no_dead_code_phase12_config_fields`.
- Targeted channel tests:
  `ChannelFactoryNoSilentFallbackTest`, `LinkBudgetNoiseBWTest`,
  `ChannelSeedBurstAwareTest`, `MergeChannelOutputContractTest`.
- Phase and broad gates:
  `phase2`, `phase3`, `phase4`, `phase8`, `phase9`, `unit`,
  `regression`, and the extended `tools/simulation.m` coverage sweep.

## Results

- 2026-04-29: removed the unused `Factories.Channel.Types`,
  `Factories.Channel.SNR`, `Factories.Channel.LogDetails`, and
  `Factories.Channel.Description` defaults from
  `config/_base_/factories/channel_factory.m`.
- Replaced executable regression writes to the unused
  `Factories.Channel.PreferredType` field with the existing scenario channel
  selection fields:
  `Factories.Scenario.PhysicalEnvironment.Map.Statistical.ChannelModel` and
  `Factories.Scenario.PhysicalEnvironment.Map.OSM.ChannelModel`.
- Updated baseline cohorts so Rayleigh/Rician-named cohorts actually request
  Rayleigh/Rician through the scenario map channel model. The 2.4 GHz
  statistical cohorts were renamed away from the older ray-tracing wording.
- Added `tests/regression/test_no_dead_code_phase12_config_fields.m` to prevent
  the removed channel fields and no-op preference field from returning in
  executable MATLAB sources.

## 2026-04-30 Hotfix: Channel Model Propagation

Follow-up inspection found a real implementation gap, not a documentation-only
issue. `ScenarioFactory` could write `Map.Statistical.ChannelModel` into
`PhysicalEnvironment.Environment.ChannelModel`, but
`PhysicalEnvironmentSimulator.initializeStatisticalMap` still hard-coded
`MapProfile.ChannelModel = 'Statistical'`. Because `ChannelFactory` resolves
`Statistical` through `DefaultModels.Statistical`, Rayleigh/Rician-named
cohorts were still executing as the statistical default instead of the requested
model.

The hotfix changes the production path:

- `initializeStatisticalMap` now resolves the configured channel model from
  `Environment.ChannelModel` or `Map.Statistical.ChannelModel`, defaulting only
  when neither is provided.
- `initializeStatisticalMap` writes the resolved model back into
  `mapData.MapProfile.ChannelModel`, `Config.Map.MapProfile.ChannelModel`,
  `Config.Environment.MapProfile.ChannelModel`, and
  `Config.Environment.ChannelModel`.
- `initializeOSMMap` applies the same propagation rule for
  `Map.OSM.ChannelModel`, preserving `RayTracing` as the default and keeping
  explicit non-ray-tracing requests visible in metadata.
- `ChannelFactory` now backfills `AppliedSNRdB` from the computed link-budget
  SNR when a channel block omits it. This was exposed by the first Phase 4
  retest after Rayleigh/Rician began executing for real: measured source-plane
  SNR coverage dropped to 50%, proving that the prior tests had not fully
  exercised the intended model path.

Additional guards were added:

- `tests/unit/ScenarioMapChannelModelPropagationTest.m` verifies that
  statistical and OSM map channel choices reach `Environment.Map.MapProfile`.
- `tests/unit/ChannelFactoryAppliedSNRTest.m` verifies that Rayleigh MIMO output
  carries `AppliedSNRdB` consistently with computed SNR.
- `tests/regression/test_phase12_channel_model_pipeline.m` verifies through a
  small pipeline run that Rayleigh/Rician configuration reaches
  `Truth.Execution.ChannelModel`.
- `test_no_dead_code_phase12_config_fields` now also checks that
  `initializeStatisticalMap` consumes `Environment.ChannelModel` and stamps the
  resolved model into `MapProfile`.

Verification passed:

- `test_no_dead_code_phase12_config_fields`
- `ChannelFactoryNoSilentFallbackTest`, `LinkBudgetNoiseBWTest`,
  `ChannelSeedBurstAwareTest`, `MergeChannelOutputContractTest` (24 cases)
- `ScenarioMapChannelModelPropagationTest`: 2 / 2 passed
- `ChannelFactoryAppliedSNRTest`: 1 / 1 passed
- `test_phase12_channel_model_pipeline`: Rayleigh and Rician both reached
  `Truth.Execution.ChannelModel`
- `run_all_tests('phase2')`: 9 / 9 passed
- `run_all_tests('phase3')`: 9 / 9 passed
- `run_all_tests('phase4')`: 10 / 10 passed
- `run_all_tests('phase8')`: 10 / 10 passed
- `run_all_tests('phase9')`: 2 / 2 passed
- `run_all_tests('unit')`: 53 / 53 passed
- `run_all_tests('regression')`: 28 / 28 passed
- `test_simulation_entrypoint_coverage_sweep('Mode','extended', ...
  'IncludeBuildingOSM',true,'EnforceCoverage',true)`: 42 passed, 1
  intentional skip, 5 regions, 8 bands, 23 modulation configurations, 6 RF
  methods, and 7 antenna combinations covered
