# CSRD Configuration And Runtime Plans

This document describes the current configuration contract. It replaces older
notes that treated frame length or observation duration as global resolved
fields.

Core rule: raw config stores authorities and sampling policies only. Each
scenario receives its concrete construction plan from `ScenarioPlan` before
execution starts.

## Layers

| Layer | Owner | Contains | Must not contain |
| --- | --- | --- | --- |
| Raw config | `config/*.m` | User intent, authorities, stochastic policies | Derived frame duration, observation duration, legacy aliases |
| `RuntimePlan` | `csrd.pipeline.runtime.buildRuntimePlan` | Run-level policies and config fingerprint | Scenario-resolved frame facts |
| `ScenarioPlan` | `csrd.pipeline.runtime.buildScenarioPlan` | Concrete facts for one scenario | Values re-sampled during frame execution |
| Execution metadata | RF/channel/receiver blocks | Actual sample-grid and model execution facts | Design guesses used as measured values |
| Annotation v2 | annotation pipeline | Design, execution, measured truth planes | Silent fallback or unlabeled NaN |

## Raw Config Authorities

Common top-level fields:

- `Runner.NumScenarios`: number of scenarios in the run.
- `Runner.RandomSeed`: root seed for deterministic replay.
- `Runner.Data.OutputDirectory`: dataset output root.
- `Logging.Policy`: logging policy such as `Standard` or `LargeMC`.

Frame diversity is configured through `Factories.Scenario.FramePolicy`.

Fixed frame shape:

```matlab
config.Factories.Scenario.FramePolicy.FrameNumSamples.Mode = 'Fixed';
config.Factories.Scenario.FramePolicy.FrameNumSamples.Value = 262144;
config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Mode = 'Fixed';
config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Value = 1;
```

Scenario-level diversity:

```matlab
config.Factories.Scenario.FramePolicy.FrameNumSamples.Mode = 'Choice';
config.Factories.Scenario.FramePolicy.FrameNumSamples.Values = [1024 4096 16384];
config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Mode = 'IntegerRange';
config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Min = 1;
config.Factories.Scenario.FramePolicy.NumFramesPerScenario.Max = 8;
```

Receiver sample rate and carrier are receiver authorities, not channel
backfills:

```matlab
config.Factories.Scenario.CommunicationBehavior.Receiver.SampleRate = 50e6;
config.Factories.Scenario.CommunicationBehavior.Receiver.RealCarrierFrequency = 2.45e9;
```

## ScenarioPlan

Before each scenario starts, `ScenarioFactory.planScenario` resolves:

- `ScenarioId`
- `Frame.FrameNumSamples`
- `Frame.NumFramesPerScenario`
- `Frame.SampleRateHz`
- `Frame.FrameDurationSec`
- `Frame.ObservationDurationSec`
- map selection and channel model
- transmitter and receiver plans
- communication transmission schedule
- `DatasetAccounting.NumReceiverFrames`

Once this plan is built, the frame loop must only consume it. If a module needs
to change a scenario-level fact, that change belongs in plan construction, not
inside `generateSingleFrame`.

## Annotation Sources

- `Truth.Design`: values copied from `ScenarioPlan` and design-time block plans.
- `Truth.Execution`: facts from actual waveform insertion, RF, channel, map, and
  sample-grid execution.
- `Truth.Measured`: measurements computed from generated signals.

Measured fields for a live source must be finite. Empty or clipped-out sources
may use NaN only when explicitly marked with `MeasurementStatus='NoSignal'`.

## OSM Policy

OSM selection is file-level balanced coverage. There is no default size cap and
no large-map tier in current production behavior.

- `Map.Types` and `Map.Ratio` decide whether a scenario uses OSM or another map
  type.
- OSM candidates are sorted and shuffled deterministically by seed and scenario
  schedule.
- `SpecificFile` pins an exact file for a validation or smoke configuration.
- `MaxFileSizeMB` is rejected; slow large maps are a performance fact, not a
  filtering rule.

## Rejected Legacy Fields

The following fields are configuration errors:

- `Runner.FixedFrameLength`
- `Runner.Log`
- top-level `Log`
- `Factories.Scenario.Global.FrameLength`
- `Factories.Scenario.Global.FrameNumSamples`
- `Factories.Scenario.Global.NumFramesPerScenario`
- `Factories.Scenario.Global.FrameDuration`
- `Factories.Scenario.Global.ObservationDuration`
- raw `TimeResolution` used as frame timing authority
- `Channel.LinkBudget.CarrierFrequency`
- `Map.OSM.MaxFileSizeMB`
- compatibility aliases such as `SeedValue` and `SegmentID` in new production
  configs

## Validation

```matlab
cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
assert(isfield(cfg, 'RuntimePlan'));

run_csrd_ci_smoke('IncludePhase4', false, 'BaselineScenarios', 1)
run_phase34_boundary_quality_audit('StopOnFailure', true, 'StressCount', 6)
```
