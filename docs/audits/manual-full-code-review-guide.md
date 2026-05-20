# CSRD Manual Full Code Review Guide

> Purpose: this guide is for a human reviewer who wants to read the whole
> project without missing files. It is not a refactoring plan and it should not
> be used as a substitute for understanding the signal-scene-annotation
> contract.

## 0. Review Principle

This project must be reviewed as a simulation pipeline, not as a loose file
tree. For every file, ask one question first:

**Does this code help the generated signal, the scene state, and the annotation
describe the same physical event?**

If the answer is unclear, record it as a review item. Do not silently forgive
ambiguous time, frequency, coordinate, power, random-seed, or annotation logic.

## 1. Ground Rules

- Review only source, config, tests, and durable docs.
- Do not read or rewrite generated output, `artifacts/`, or dataset output under
  `data/`.
- Do not delete or normalize raw map assets under `data/map/`.
- Do not edit code during the first pass. Record findings first, then batch
  fixes later.
- Do not rely on long stress tests to discover design mistakes. Stress tests are
  for confirming high-risk fixes after review.
- Classify every finding as `Blocker`, `Correctness`, `Performance`,
  `Cleanup`, or `Test Gap`.

## 2. Prepare A Review Workspace

Run these commands from the repository root before reading files:

```powershell
git status -sb
rg --files +csrd config tools tests docs | sort > artifacts/review/source-file-list.txt
rg --files +csrd config tools tests docs | Measure-Object
```

If `artifacts/` does not exist, create it manually or redirect the file list to a
temporary location outside the repository. The file list is only a local review
aid and should not be committed.

Create a local note file outside git or under ignored `artifacts/review/` with
this issue template:

```text
ID:
Severity: Blocker | Correctness | Performance | Cleanup | Test Gap
File/function:
Pipeline stage:
Producer fields:
Consumer fields:
Units/shape:
Trigger path:
Risk:
Evidence:
Suggested fix:
Suggested test:
Status: Open | Confirmed | Fixed | Rejected
```

## 3. First Pass: Entry And Configuration Authority

Read these files first, in this order:

1. `AGENTS.md`
2. `README.md`
3. `docs/architecture/source-layout.md`
4. `tools/simulation.m`
5. `+csrd/SimulationRunner.m`
6. `+csrd/+runtime/config_loader.m`
7. `config/_base_/runners/default.m`
8. `config/_base_/runners/high_performance.m`
9. `config/_base_/logging/default.m`
10. `config/_base_/logging/debug.m`
11. `config/csrd2025/*.m`

For each file, check:

- Which configuration fields are authoritative?
- Which fields are derived?
- Which fields are written to output metadata?
- Does any config value get silently replaced by a fallback?
- Does worker splitting preserve global `ScenarioId` and random seed replay?
- Does failure accounting distinguish success, skipped, and failed scenarios?
- Does output path logic ever write source-controlled generated files?

Risk keywords:

```powershell
rg "FixedFrameLength|FrameLength|RandomSeed|ScenarioId|WorkerId|OutputDirectory|fallback|warning\(|catch|skip|Skipped|Failed" tools +csrd/SimulationRunner.m config
```

Minimum tests to inspect:

- `tools/ci/run_csrd_ci_smoke.m`
- `tests/unit/SimulationRunnerScenarioSeedContractTest.m`
- `tests/unit/RuntimeParameterContractTest.m`
- `tests/unit/RuntimeTruthContractTest.m`
- `tests/regression/test_simulation_runner_startup_hooks.m`

## 4. Second Pass: Main Pipeline By Data Flow

Review every production file, but keep this order so producer and consumer
contracts stay adjacent.

### 4.1 Runner And Engine

Files:

- `+csrd/SimulationRunner.m`
- `+csrd/+core/@ChangShuo/ChangShuo.m`
- `+csrd/+core/@ChangShuo/setupImpl.m`
- `+csrd/+core/@ChangShuo/stepImpl.m`
- `+csrd/+core/@ChangShuo/private/*.m`
- `+csrd/+core/@ChangShuo/*.m`

Check:

- `FrameId`, `ScenarioId`, and `FrameWindow` semantics.
- The shape of Tx/Rx signal structs.
- Whether errors are propagated or hidden.
- Whether annotation fields are built from actual execution metadata.
- Whether multi-burst and multi-antenna paths preserve sample-grid timing.

High-risk files:

- `processScenarioInstantiation.m`
- `generateSingleFrame.m`
- `processSingleTransmitter.m`
- `processTransmitterSegments.m`
- `processSingleSegment.m`
- `processChannelPropagation.m`
- `processReceiverProcessing.m`
- `validateMeasurementCompleteness.m`

### 4.2 Scenario Factory

Files:

- `+csrd/+factories/ScenarioFactory.m`
- `+csrd/+pipeline/+runtime/*.m`
- `+csrd/+pipeline/+scenario/*.m`
- `+csrd/+pipeline/+blueprint/*.m`
- `config/_base_/factories/scenario_factory.m`

Check:

- Only `Factories.Scenario.Global.FrameNumSamples` is the frame-length
  authority.
- `ObservationDuration`, `FrameDuration`, and `NumFramesPerScenario` are
  validation fields, not competing authorities.
- OSM map selection is file-level balanced and does not filter by size.
- Deprecated size-cap fields fail fast.
- RayTracing frequency support is checked before running the channel.
- Map/channel model provenance reaches annotation.

Tests to inspect:

- `tests/unit/FrameRuntimeContractTest.m`
- `tests/unit/ContinuousFrameWindowContractTest.m`
- `tests/unit/ScenarioFactoryOsmUniformCoverageTest.m`
- `tests/unit/ScenarioFactoryOsmNoSizeCapTest.m`
- `tests/unit/ScenarioFactoryMapTypeBalancedRatioTest.m`
- `tests/unit/RayTracingFrequencySupportContractTest.m`

### 4.3 Physical Environment

Files:

- `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/*.m`
- `+csrd/+blocks/+scenario/@PhysicalEnvironmentSimulator/private/*.m`
- `+csrd/+runtime/+map/*.m`

Check:

- Geographic coordinates and Cartesian meter coordinates are never mixed.
- `Position` is meter-space when consumed by mobility, distance, and Doppler.
- `GeoPositionDeg` is the only geographic input for RayTracing site creation.
- Empty OSM uses explicit flat-terrain metadata.
- `building` and `building:part` are both detected.
- Viewers/resources are cleaned up.

Risk keywords:

```powershell
rg "Latitude|Longitude|GeoPositionDeg|Position|Velocity|siteviewer|building:part|Terrain|gmted2010|isvalid|fallback" +csrd/+blocks/+scenario +csrd/+runtime/+map
```

Tests to inspect:

- `tests/unit/OsmCoordinateUnitContractTest.m`
- `tests/unit/FlatTerrainNoOnlineTerrainRegressionTest.m`
- `tests/unit/OsmMapResourceCacheContractTest.m`
- `tests/regression/test_empty_osm_raytracing.m`
- `tests/regression/test_osm_building_raytracing.m`

### 4.4 Communication Behavior

Files:

- `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/*.m`
- `+csrd/+blocks/+scenario/@CommunicationBehaviorSimulator/private/*.m`
- `+csrd/+catalog/+spectrum/*.m`
- `+csrd/+catalog/+profile/**/*.m`

Check:

- Frequency allocation stays inside receiver observable range.
- Default configs do not rely on overlap allocation.
- Planned bandwidth and execution bandwidth stay separate.
- Tx/Rx antenna counts are planner-owned and do not get rewritten downstream.
- Temporal behavior produces clipped active intervals per frame.
- Random helpers do not consume hidden RNG draws that break replay.

Tests to inspect:

- `tests/unit/FrequencyAllocationOverlapContractTest.m`
- `tests/unit/FrequencyAllocationStrategyTest.m`
- `tests/unit/CalculateTransmissionStateTest.m`
- `tests/unit/MultiBurstPerFrameTest.m`
- `tests/unit/ScenarioModulationAntennaCompatibilityTest.m`
- `tests/unit/RegionSpectrumSelectorTest.m`

### 4.5 Message, Modulation, And Tx RF

Files:

- `+csrd/+factories/MessageFactory.m`
- `+csrd/+factories/ModulationFactory.m`
- `+csrd/+factories/TransmitFactory.m`
- `+csrd/+blocks/+physical/+message/*.m`
- `+csrd/+blocks/+physical/+modulate/**/*.m`
- `+csrd/+blocks/+physical/+txRadioFront/TRFSimulator.m`
- `config/_base_/factories/message_factory.m`
- `config/_base_/factories/modulation_factory.m`
- `config/_base_/factories/transmit_factory.m`

Check:

- Per-segment message length comes from the clipped segment duration.
- Modulator output is `[samples x antennas]`.
- Modulator output reports actual sample rate and bandwidth.
- No missing bandwidth/sample-rate/antenna field is silently filled.
- TRF resampling uses exact enough rate conversion and preserves timing.
- Matrix multi-antenna processing does not collapse the antenna axis.

Tests to inspect:

- `tests/unit/MessageFactoryNoLengthFallbackTest.m`
- `tests/unit/ModulationFactoryNoExecutionFallbackTest.m`
- `tests/unit/ModulationFactoryRegistryFailFastTest.m`
- `tests/unit/TransmitFactoryRequiresReceiverSampleRateTest.m`
- `tests/unit/TRFSimulatorTest.m`
- `tests/unit/TRFExactResampleContractTest.m`
- `tests/unit/TRFMatrixResampleContractTest.m`
- `tests/unit/OFDMMimoModeTest.m`

### 4.6 Channel

Files:

- `+csrd/+factories/ChannelFactory.m`
- `+csrd/+blocks/+physical/+channel/*.m`
- `+csrd/+blocks/+physical/+channel/+impairments/*.m`
- `+csrd/+runtime/+capabilities/*.m`
- `+csrd/+pipeline/+linkbudget/*.m`
- `config/_base_/factories/channel_factory.m`

Check:

- Channel seed requires non-empty `BurstId`.
- Carrier frequency authority comes from receiver runtime info.
- RayTracing only handles supported frequencies.
- No internal RayTracing/material/siteviewer type error is disguised as
  `NoValidPaths`.
- NoValidPaths fallback is explicit and reflected in metadata.
- Distance/path loss uses meters consistently.
- Noise bandwidth resolution is explicit and source-traced.

Tests to inspect:

- `tests/unit/ChannelSeedRequiresBurstIdTest.m`
- `tests/unit/ChannelSeedBurstAwareTest.m`
- `tests/unit/CarrierFrequencyAuthorityTest.m`
- `tests/unit/ChannelPropagationFailFastTest.m`
- `tests/unit/ChannelFactoryNoSilentFallbackTest.m`
- `tests/unit/ChannelFactoryNoWarningDowngradeTest.m`
- `tests/unit/NoiseBandwidthNoFallbackTest.m`
- `tests/unit/RayTracingMaterialPolicyTest.m`
- `tests/unit/RayTracingBatchEquivalenceTest.m`
- `tests/unit/BaseChannelDistanceTest.m`

### 4.7 Rx RF, Receive, Measurement, Annotation

Files:

- `+csrd/+factories/ReceiveFactory.m`
- `+csrd/+blocks/+physical/+rxRadioFront/RRFSimulator.m`
- `+csrd/+pipeline/+measurement/*.m`
- `+csrd/+pipeline/+annotation/*.m`
- `+csrd/+pipeline/+signal/*.m`
- `config/_base_/factories/receive_factory.m`

Check:

- Receiver sample rate and observable range are mandatory.
- RRF does not rebuild/release System objects unless needed.
- Empty/clipped-out sources are explicitly marked `NoSignal`.
- Live measured fields are finite; NaN is not silently emitted.
- `Truth.Execution.StartTimeSec` and `EndTimeSec` equal actual sample-grid
  insertion times.
- JSON sanitization does not hide live measurement failures.

Tests to inspect:

- `tests/unit/ReceiveFactoryFailFastTest.m`
- `tests/unit/RRFSimulatorTest.m`
- `tests/unit/RRFSimulatorLifecyclePerformanceTest.m`
- `tests/unit/MeasurementEnvelopeShortFrameTest.m`
- `tests/unit/MeasurementFailureVisibilityTest.m`
- `tests/unit/MeasurementCompletenessHookTest.m`
- `tests/unit/AnnotationExecutionSampleGridContractTest.m`
- `tests/unit/BuildSourceAnnotationV2Test.m`
- `tests/unit/SignalGatingTest.m`
- `tests/unit/SanitizeForJson*.m`

## 5. Third Pass: Support, Runtime, Tools, And Docs

After the main pipeline, review support code by category.

### 5.1 Runtime Services

Files:

- `+csrd/+runtime/**/*.m`
- `+csrd/+support/**/*.m`
- `+csrd/+test_support/*.m`

Check:

- Logger hot paths do not call expensive stack formatting when the level is
  filtered.
- Persistent state is intentional, scoped, and resettable.
- Tooling does not write generated output into tracked paths.
- Hash/random helpers are deterministic under fixed seed.

### 5.2 Tools

Files:

- `tools/**/*.m`
- `tools/**/*.ps1`
- `tools/**/*.bat`
- `tools/**/*.sh`
- `tools/**/*.py`

Check:

- Public simulation still enters through `tools/simulation.m`.
- Audit and massive-run tools only write ignored `artifacts/` or `data/`.
- Watchdogs do not mark hard failures as success.
- Cleanup scripts never delete `data/map/`.
- CI scripts represent real pipeline risks, not only shallow string checks.

### 5.3 Tests

Files:

- `tests/unit/*.m`
- `tests/regression/*.m`
- `tests/helpers/*.m`
- `tests/run_all_tests.m`
- `tests/README.md`

For every production subsystem already reviewed, record:

- Which tests cover direct unit behavior?
- Which tests touch the true main pipeline path?
- Which tests only check strings or dead-code gates?
- Which expected failure modes are missing?

Mark missing pipeline coverage as `Test Gap`, even if helper tests are green.

### 5.4 Documentation

Files:

- `README.md`
- `docs/README.md`
- `docs/architecture/*.md`
- `docs/annotation-v2-schema.md`
- `docs/examples/*.md`
- `docs/release/*.md`
- `docs/audits/**/*.md`

Check:

- Current docs do not advertise deleted paths.
- Historical audit docs are clearly historical snapshots.
- New runtime behavior is documented near the config or code path that owns it.
- Fallback behavior names trigger, fallback model, and exported metadata.

## 6. Mandatory Risk Searches

Run these searches before closing review. For each hit, decide whether it is
valid, legacy-only, test-only, or a finding.

### Silent fallback and error swallowing

```powershell
rg "fallback|warning\(|try|catch|NaN|TODO|FIXME|persistent|global" +csrd config tools tests
```

### Time, sample, and frequency contract

```powershell
rg "FrameLength|FrameNumSamples|FrameWindow|ObservationDuration|FrameDuration|SampleRate|CarrierFrequency|RealCarrierFrequency|Bandwidth|ObservableRange|BurstId" +csrd config tests
```

### OSM and RayTracing

```powershell
rg "siteviewer|raytrace|txsite|rxsite|propagationModel|GeoPositionDeg|Latitude|Longitude|Terrain|gmted2010|NoValidPaths|building:part" +csrd config tools tests
```

### Signal shape and RF processing

```powershell
rg "NumTransmitAntennas|NumReceiveAntennas|size\\(|reshape|transpose|resample|release\\(|gpuArray|obw" +csrd tests
```

### Generated files and unsafe paths

```powershell
rg "artifacts|data\\\\|data/|save\\(|jsonencode|fopen|delete\\(|rmdir|copyfile|movefile" +csrd tools tests
```

## 7. Per-File Review Checklist

Use this checklist for every file you open:

- What pipeline stage does this file belong to?
- Is it production, test, tool, config, support, or historical documentation?
- What inputs does it trust?
- What outputs does it produce?
- Are units stated or inferable?
- Are shapes stated or inferable?
- Does it mutate shared state?
- Does it consume RNG?
- Does it catch errors?
- Does it issue warnings instead of failing?
- Does it write files?
- Does it create external resources or viewers?
- Does annotation or metadata depend on it?
- Which test proves its most important behavior?
- Which failure mode is not tested?

If any answer is "unknown", record a note. Unknown units and unknown shapes are
not harmless in this project.

## 8. Severity Guide

### Blocker

Use `Blocker` when a bug can make generated data physically or semantically
false, or when a hard failure is hidden as success.

Examples:

- Signal is generated at one time/frequency but annotation says another.
- Latitude/longitude is used as meters.
- RayTracing failed but metadata claims RayTracing succeeded.
- Measurement failure becomes NaN on a live signal.
- A scenario fails but is counted as success.

### Correctness

Use `Correctness` when behavior is wrong or fragile but does not necessarily
corrupt every generated sample.

Examples:

- A fallback is explicit but too broad.
- A config field is accepted but ignored.
- Seed replay is likely stable in serial but not under workers.
- Frame or bandwidth validation permits ambiguous values.

### Performance

Use `Performance` only when profile or code structure shows wasted work without
changing the physical model.

Examples:

- Recreating `siteviewer`, `raytrace` inputs, System objects, or resampling
  filters inside a loop with stable parameters.
- Recomputing the same PSD for OBW, centroid, and envelope.
- Formatting debug stack messages when debug logging is disabled.

### Cleanup

Use `Cleanup` for dead paths, stale names, duplicated comments, or misleading
docs that do not directly alter generated truth.

### Test Gap

Use `Test Gap` when the code looks correct but there is no meaningful test for
the contract.

## 9. Review Log Format

Keep a running subsystem summary:

```text
Subsystem:
Files reviewed:
Main producers:
Main consumers:
Critical fields:
Tests inspected:
Findings:
Residual risk:
Next subsystem:
```

For each finding:

```text
[Correctness] RX-001
File/function:
Trigger path:
Observed behavior:
Why it matters:
Suggested fix:
Suggested test:
Reviewer decision:
```

## 10. Suggested Review Sessions

Do not try to finish the whole project in one sitting. A realistic sequence is:

1. Session A: entry, config loader, runner, CI smoke.
2. Session B: `ChangShuo` engine and frame processing.
3. Session C: scenario factory and runtime contracts.
4. Session D: physical environment and OSM/map handling.
5. Session E: communication behavior and spectrum catalogs.
6. Session F: message/modulation/TRF.
7. Session G: channel and RayTracing.
8. Session H: receive/RRF/measurement/annotation.
9. Session I: tools, watchdogs, performance/audit helpers.
10. Session J: tests and documentation cross-check.

At the end of every session, write:

- files completed;
- open questions;
- new findings;
- tests that should be run later;
- whether any code path must be revisited after reading a downstream consumer.

## 11. Minimal Validation After A Review Round

Review itself should be read-only. After you later fix a batch of findings, use
the smallest validation that matches the affected subsystem.

Entry/config:

```matlab
addpath(fullfile(pwd, 'tools', 'ci'));
run_csrd_ci_smoke();
```

Signal and annotation:

```matlab
addpath(fullfile(pwd, 'tests'));
results = runtests({'tests/unit/BuildSourceAnnotationV2Test.m', ...
                    'tests/unit/MeasurementCompletenessHookTest.m', ...
                    'tests/unit/SignalGatingTest.m'});
assertSuccess(results);
```

TRF/RRF:

```matlab
addpath(fullfile(pwd, 'tests'));
results = runtests({'tests/unit/TRFSimulatorTest.m', ...
                    'tests/unit/RRFSimulatorTest.m'});
assertSuccess(results);
```

OSM/RayTracing:

```matlab
addpath(fullfile(pwd, 'tests'));
results = runtests({'tests/unit/RayTracingMaterialPolicyTest.m', ...
                    'tests/unit/OsmCoordinateUnitContractTest.m', ...
                    'tests/unit/FlatTerrainNoOnlineTerrainRegressionTest.m'});
assertSuccess(results);
```

Default pipeline smoke:

```matlab
addpath(fullfile(pwd, 'tools'));
simulation(1, 1, 'csrd2025/csrd2025.m');
```

## 12. Done Criteria

A full manual review pass is complete only when:

- every file from `rg --files +csrd config tools tests docs` has been marked
  reviewed, skipped as generated/historical, or explicitly deferred;
- every production file has an identified pipeline role;
- every cross-module struct field has a producer, consumer, unit, and shape
  note;
- every accepted fallback is visible in metadata or annotation;
- every `catch` has a documented reason;
- every live-signal measured NaN path is rejected or explicitly proven
  impossible;
- every high-risk subsystem has at least one pipeline-level test;
- all open findings have severity, evidence, and suggested tests.

## 13. Final Review Report Skeleton

When the manual pass is finished, write a report with this structure:

```text
Title:
Date:
Reviewer:
Commit reviewed:

Scope:
Files reviewed:
Files deferred:

Blockers:
Correctness findings:
Performance findings:
Cleanup findings:
Test gaps:

Most important contracts verified:
Residual risks:
Recommended fix order:
Recommended regression suite:
```

Keep this report separate from historical audit snapshots until the findings are
fixed and validated.
