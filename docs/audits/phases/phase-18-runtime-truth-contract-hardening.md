# Phase 18 Runtime Truth Contract Hardening

## Summary

Phase 18 extends the Phase 17 frame/time contract into the runtime facts that
most often split signal, scene state, and annotation:

- receiver sample rate and observable window;
- RF carrier frequency;
- planned versus execution bandwidth;
- Tx power and link-budget noise bandwidth;
- receiver-view projection;
- TRF sample-rate conversion;
- annotation measurement visibility.

The guiding rule is strict: production code must not invent runtime facts from
downstream outputs or magic defaults. If a required fact is absent, the pipeline
fails before writing misleading data.

## Contract Matrix

| Parameter | Authority | Derived / Execution Fields | Annotation Fields | Forbidden Fallback |
|---|---|---|---|---|
| Frame samples | `Factories.Scenario.Global.FrameNumSamples` | `FrameDuration = samples / Receiver.SampleRate` | `FrameLengthSamples`, `FrameDurationSec` | `Global.FrameLength`, `Runner.FixedFrameLength` |
| Receiver sample rate | `Receiver.Observation.SampleRate` / `rxInfo.SampleRate` | TRF target rate, fixed Rx frame length | `FrameData.SampleRate`, `Truth.Execution.SampleRate` | modulator output backfill |
| Observable range | `rxInfo.ObservableRange` | receiver-view window, observable bandwidth | `ObservableRange`, `Measured.*.FrequencyOccupancy` | unified fallback range |
| Carrier frequency | `rxInfo.RealCarrierFrequency` | channel FSPL wavelength and link metadata | `Truth.Execution.ChannelInfo.CarrierFrequency` when emitted | independent `LinkBudget.CarrierFrequency` drift |
| Planned bandwidth | `txScenario.Spectrum.PlannedBandwidth` | placement / regulatory design truth | `Truth.Design.PlannedBandwidthHz` | execution bandwidth replacement |
| Execution bandwidth | modulator/channel measured output | `ModulatedBandwidthHz` | `Truth.Execution.ModulatedBandwidthHz` | analytical or planned bandwidth fallback |
| Tx power | planner hardware power / `txInfo.Power` | link-budget SNR | `Truth.Execution.AnalyticalSNRdB` | default `20 dBm` |
| Noise bandwidth | explicit link-budget, receiver observable BW, or segment BW | link-budget SNR | SNR provenance through execution truth | `50e6` magic fallback |
| Channel model | map/profile selected model plus registry default | channel block selection | `Truth.Execution.ChannelModel` | arbitrary registry key or AWGN rescue |
| Measurement status | actual measurement call result | source/frame measured fields | `MeasurementStatus` | silent NaN for live signal |

## Implemented Changes

- Added `csrd.pipeline.runtime.validateRuntimeTruthContracts`.
- `normalizeRuntimeContracts` now stamps `Metadata.RuntimeContracts.RuntimeTruth`.
- `SimulationRunner.setupImpl` and direct `ChangShuo.FactoryConfigs` setup both
  normalize and validate the same runtime contracts.
- `ChannelFactory` now errors when block config, distance, link-info, antenna, or
  seed assignment fails.
- `ChannelFactory` requires receiver carrier frequency and validates any
  configured link-budget carrier against it.
- Link-budget SNR requires `txInfo.Power`, link-budget thermal-noise fields, and
  a resolvable positive noise bandwidth.
- `resolveNoiseBandwidth` no longer accepts or invents a fallback bandwidth.
- `ReceiveFactory` throws on missing type, missing handle, and instantiation
  failure instead of returning `Error` structs.
- `ModulationFactory` throws on missing registry/type/handle execution facts,
  requires explicit `SymbolRate`, and no longer infers it from `TargetBandwidth`.
- `TransmitFactory` requires `transmitterScenarioConfig.Spectrum.ReceiverSampleRate`
  for `TargetSampleRate`.
- `projectReceiverViews` requires every receiver to carry its own observable range.
- `TRFSimulator` uses strict rational sample-rate conversion and fails if the
  target rate cannot be reached within `1e-9` relative error.
- Annotation execution truth validates sample-grid equations:
  `StartTimeSec = FrameStartSample / SampleRate`,
  `EndTimeSec = FrameEndSample / SampleRate`,
  `DurationSec = FrameSampleCount / SampleRate`.
- Live measurement failures now raise `CSRD:Measurement:*`; empty or clipped-out
  sources publish `MeasurementStatus='NoSignal'`.

## Tests Added Or Updated

- `RuntimeTruthContractTest`
- `CarrierFrequencyAuthorityTest`
- `NoiseBandwidthNoFallbackTest`
- `ChannelFactoryNoWarningDowngradeTest`
- `ReceiveFactoryFailFastTest`
- `ModulationFactoryRegistryFailFastTest`
- `TransmitFactoryRequiresReceiverSampleRateTest`
- `ReceiverViewObservableRangeContractTest`
- `TRFExactResampleContractTest`
- `AnnotationExecutionSampleGridContractTest`
- `MeasurementFailureVisibilityTest`
- `test_no_dead_code_phase18_runtime_truth_contracts`

Existing fallback-oriented tests were updated to expect hard failures.

## Nightly Validation

`tools/ci/run_phase18_nightly_validation.m` is the intended 69-case full
validation entry point. It writes logs under ignored `data/` and treats the
first hard failure as the item to fix; warnings or skips are not success.

## Remaining Watch Items

- OSM empty/building fallback policy is intentionally preserved, but metadata
  visibility remains part of the regression suite.
- Compatibility aliases such as `SeedValue`, `SegmentID`, and `TypeID` are not
  deleted in this phase, but they are not allowed to become new runtime
  authorities.
