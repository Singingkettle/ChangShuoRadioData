[English](annotation-schema.md) | [中文](annotation-schema.zh-CN.md)

# CSRD Annotation Schema

Status: Annotation current contract, updated for scenario-level
`ScenarioPlan` generation.

This document describes the frozen annotation shape used by the refactored
CSRD pipeline. Annotation is not a compatibility layer for legacy v1 fields.
Consumers should read it through `csrd.pipeline.annotation.readAnnotation`.

## Core Rule

Every exported annotation must describe the same event as the generated signal
and scene state.

The schema separates facts by source:

| Namespace | Meaning | Source |
|-----------|---------|--------|
| `Truth.Design` | Planned facts that come from the scenario plan | `ScenarioPlan` / planning stage |
| `Truth.Execution` | Realized construction facts from waveform, channel, geometry, and RF execution | Construction stage |
| `Truth.Measured` | Measurements computed after signal generation | Measurement stage |
| `ReceiverView` | Projection of one source into one receiver observation window | Receiver-view construction |

Design facts such as modulation family do not need to be measured. Values such
as occupied bandwidth may differ from the planned bandwidth, so the final label
uses measured fields.

Current generation builds a frozen `ScenarioPlan` before the first frame of each
scenario. Annotation headers may include `ScenarioPlan.Frame` and
`DatasetAccounting`; per-source design facts must agree with that plan, while
execution and measured facts are still taken from actual generated data.

## Root Shape

The root annotation contains `Frames`. A runtime header is expected for release
artifacts:

```matlab
reader = csrd.pipeline.annotation.readAnnotation(annotationPath, ...
    'RequireSources', true, ...
    'RequireRuntimeHeader', true);
```

`reader.Summary` reports:

| Field | Meaning |
|-------|---------|
| `Schema` | Always `annotation` for this reader |
| `NumFrames` | Number of receiver frames in the annotation |
| `NumSources` | Number of visible or hidden source records across frames |
| `NumReceivers` | Unique receiver IDs |
| `ReceiverIDs` | Receiver ID list |

## Frame Fields

Each frame must contain:

| Field | Unit | Meaning |
|-------|------|---------|
| `FrameId` | index | Frame identifier |
| `ReceiverID` | text | Receiver that owns this observation |
| `Status` | text | Must be `Success` for v2 reader acceptance |
| `SignalSources` | struct array | Per-source records in this receiver frame |
| `SampleRate` | Hz | Receiver sample rate, when present |
| `ObservableRange` | Hz | Receiver observable frequency range `[low high]`, when present |
| `ScenarioPlan` | struct | Optional scenario plan header for the owning scenario |
| `DatasetAccounting` | struct | Optional receiver-frame accounting copied from `ScenarioPlan` |

## Source Fields

Each source must contain:

| Field | Meaning |
|-------|---------|
| `TxID` | Transmitter identifier |
| `SegmentId` | Segment identifier within the frame |
| `BurstId` | Burst identifier used for reproducibility and channel seed separation |
| `Truth` | Design / Execution / Measured namespaces |
| `RFImpairments` | RF impairments applied during execution |
| `ReceiverView` | Receiver-specific projected frequency view |

Legacy v1 top-level fields are forbidden: `Realized`, `Planned`, `Temporal`,
`Spatial`, `LinkBudget`, and `Channel`.

## Truth.Design

| Field | Unit | Meaning |
|-------|------|---------|
| `PlannedCenterFrequencyHz` | Hz | Planned source center as a **receiver-baseband offset** (same frame as `Execution.CenterFrequencyOffsetHz` and `ReceiverView.ProjectedCenterOffsetHz`), not an absolute RF carrier |
| `PlannedBandwidthHz` | Hz | Blueprint bandwidth: the ALLOCATION the planner assigned, i.e. a ceiling, not a prediction of the measured width |
| `PlannedSampleRate` | Hz | Planned sample rate |
| `PlannedSymbolRateHz` | Hz | Symbol rate the planner chose, `NaN` for families that have none |
| `PlannedRolloffFactor` | scalar | Pulse-shaping roll-off the planner chose, `NaN` where inapplicable |
| `ModulationFamily` | text | Design category, used by downstream classifiers |
| `ModulationOrder` | scalar | Modulation order when applicable |
| `MessageSource` | text | Baseband source: `Audio` (analog) or `RandomBit` (digital) |
| `IsDigital` | logical | Whether the modulation family is digital |
| `PayloadLengthBits` | bits | Planned payload length |
| `NumTransmitAntennas` | count | Planned transmit antenna count |

All annotation frequencies are receiver-centered: the carrier `RealCarrierFrequency`
deliberately never enters baseband/waveform generation (it drives only path loss,
antenna pattern, and Doppler). `PlannedCenterFrequencyHz` is therefore a baseband
offset relative to the receiver tuned center, in the same frame as the Execution
and Measured center fields — despite the historical "CenterFrequency" name. A
consumer that needs an absolute RF center must add the owning receiver's
`RealCarrierFrequency`; reading this field as an absolute carrier is wrong by ~the
tuned frequency.

`Truth.Design.ModulationFamily` is the class label source for COCO conversion.
It is not inferred from IQ.

`PlannedSymbolRateHz` and `PlannedRolloffFactor` are published because they, not
the allocation, are what predicts a measured occupied bandwidth from published
theory. For a root-raised-cosine single carrier the ITU 99 % OBW is a fixed
multiple of the symbol rate that rises with the roll-off — 1.01922 / 1.10307 /
1.26801 times `Rs` at beta = 0.1 / 0.25 / 0.5 (closed form; ITU-R SM.853-2
Table 2). Checking a measurement against `PlannedBandwidthHz` cannot do that job:
it is an allocation the planner may also snap onto the receiver sample grid, so
`PlannedBandwidthHz = (1 + beta) * Rs` does not hold for narrow channels.

Two cautions on comparing measured widths against `PlannedBandwidthHz`:

- The ratio has a hard `<= 1` ceiling ONLY for strictly bandlimited families —
  RRC-shaped linear single carrier, and AM/SSB with a bandlimited message. It does
  NOT generalise. Rectangular-windowed OFDM has sinc-squared tails and
  legitimately reaches 1.86x its occupied-subcarrier span at 12 subcarriers,
  crossing below 1.0 only near 65; 4-ary CPFSK at h = 1 legitimately reaches 3.4x;
  FM reaches 1.09x of its Carson bandwidth.
- A weakly modulated AM carrier legitimately collapses. With a single tone at
  modulation index below 0.142 both sidebands fall inside the ITU 0.5 % edge
  exclusion, so the occupied bandwidth is the carrier line alone and the ratio
  tends to zero. That is the definition behaving correctly, not a measurement
  failure.

The message source is a deterministic function of the modulation family, not a
free choice: analog families (FM/PM/AM variants) are driven by `Audio`, digital
families (PSK/QAM/FSK/...) by `RandomBit`. The reader rejects any annotation
whose `MessageSource`/`IsDigital` disagree with `ModulationFamily`
(`CSRD:Annotation:MessageSourceModulationMismatch` /
`CSRD:Annotation:IsDigitalModulationMismatch`).

## Truth.Execution

| Field | Unit | Meaning |
|-------|------|---------|
| `ModulatedBandwidthHz` | Hz | Bandwidth measured on clean modulator output |
| `CenterFrequencyOffsetHz` | Hz | Realized source offset in receiver-centered coordinates |
| `SampleRate` | Hz | Executed source sample rate |
| `ChannelModel` | text | Channel model actually used |
| `PathLossDB` | dB | Applied path loss |
| `AnalyticalSNRdB` | dB | Link-budget analytical SNR |
| `AppliedSNRdB` | dB | Applied SNR metadata |
| `DopplerShiftHz` | Hz | Applied Doppler shift if external Doppler is used |
| `RadialVelocityMps` | m/s | Link radial velocity |
| `GeometrySnapshot` | struct | Tx/Rx positions, velocities, and distance in meters |
| `MapProfile` | struct | Optional RayTracing/OSM execution map profile |
| `RayCount` | count | Optional number of ray paths returned by RayTracing |
| `ChannelFallback` | text | Optional explicit fallback used by RayTracing, such as flat-terrain free-space attenuation |

`GeometrySnapshot` contains `TxPositionM`, `TxVelocityMps`, `RxPositionM`,
`RxVelocityMps`, and `LinkDistanceM`. `RadialVelocityMps` is computed from the
relative velocity `TxVelocityMps - RxVelocityMps` projected onto the Tx-to-Rx
line of sight, so receiver-only mobility is represented in both IQ and labels.

When OSM RayTracing is used, `MapProfile` records whether the run used
`OSMBuildings` or `FlatTerrain`, whether buildings were present, and the
executed `ChannelModel`. Empty/no-building OSM cases must expose any
`ChannelFallback` rather than silently claiming a richer path than was run.

## Truth.Measured

`Truth.Measured` contains `SourcePlane` and `FramePlane`.

| Plane | Meaning |
|-------|---------|
| `SourcePlane` | Isolated source after channel and before receiver RF chain |
| `FramePlane` | Combined receiver frame before receiver RF chain |

Both planes carry occupied bandwidth, center frequency, time occupancy,
frequency occupancy, and `MeasurementSemantics`. `SourcePlane` also carries
`SNRdB`.

Required semantics:

| Field | Required value |
|-------|----------------|
| `SourcePlane.MeasurementSemantics` | `receiver_view_isolated` |
| `FramePlane.MeasurementSemantics` | `post_rx_combined_pre_rfchain` |

### What `OccupiedBandwidthHz` is, and under what conditions

`OccupiedBandwidthHz` is the **ITU-R SM.328 / Radio Regulations No. 1.153 occupied
bandwidth**: the band excluding 0.5 % of the total mean power at each edge. It is
NOT an x-dB-down width; ITU-R SM.443 requires x around 26 dB before an x-dB-down
width approximates it. The definition and the estimator that produced the number
travel with it, so a consumer never has to guess which convention a label follows:

| Field | Meaning |
|-------|---------|
| `BandwidthDefinition` | The quantity definition, e.g. `ITU-R SM.328 occupied bandwidth (99% power)` |
| `BandwidthEstimator` | The function that produced it |

Both planes measure **clean, per-emitter, per-antenna buffers before noise
injection**. Per emitter and per antenna matters: the antenna copies of one
emitter are independently faded, so summing them first would report the
interference pattern between the copies rather than a bandwidth any transmitter
emitted. Before noise matters because a power-integral definition is not merely
imprecise on a noisy buffer, it is undefined — noise contributes power across the
whole band, and ECC/REC/(06)01 requires the peak at least 30 dB above the noise
floor to measure 99 % OBW at all. `SNRdB` still describes the noise in the frame
that was SAVED; it and the bandwidth describe different sides of one delivery, not
two properties of one buffer.

### Measurement conditions (`SourcePlane`)

A bare number is not a sufficient specification of a measured quantity
(JCGM 200:2012 VIM 2.3). The same 15 MHz reading means one thing on a
32768-sample buffer and something else on a 64-sample burst, because a hard-gated
burst of duration T genuinely occupies about 10/T at the 99 % power level — a true
statement about a signal that should not have been built that way, not a
measurement error. These fields let a consumer tell the two apart:

| Field | Unit | Meaning |
|-------|------|---------|
| `BandwidthResolutionHz` | Hz | Resolution the answer was produced at: the COARSER of the analysis grid and `SampleRate / ActiveSampleCount`, because zero padding interpolates a spectrum and never adds information |
| `BandwidthResolutionCells` | count | `OccupiedBandwidthHz / BandwidthResolutionHz`. ITU-R SM.443 puts a usable measurement RBW at 1–3 % of the width, i.e. 33 cells or more; below about 8 the value is quantised by the burst length rather than by the emitter |
| `ActiveSampleCount` | count | Samples carrying energy, which is what sets the resolution floor |

These describe the measurement rather than being labels themselves, so unlike the
measured scalars they may legitimately be `NaN` for a degenerate buffer. A low
`BandwidthResolutionCells` is a precision statement, NOT a defect: a 286 kHz
emitter carried in a 512-sample burst at 50 MHz cannot be measured more finely
than 98 kHz. About 43 % of sources in a representative sweep fall below 8 cells,
so a consumer that needs finely defined widths should filter on this field.

## ReceiverView

Receiver-view fields are per source per receiver:

| Field | Unit | Meaning |
|-------|------|---------|
| `ReceiverId` | text | Receiver ID |
| `ProjectedCenterOffsetHz` | Hz | Source center projected into this receiver window |
| `ProjectedLowerEdgeHz` | Hz | Projected lower edge |
| `ProjectedUpperEdgeHz` | Hz | Projected upper edge |
| `IsVisible` | logical | Whether the source is visible in the receiver window |
| `VisibilityReason` | text | Reason such as `InBand` or `OutOfBand` |

COCO minimal export uses `Truth.Measured.SourcePlane.CenterFrequencyHz` for the
bbox center (the measured, Doppler-inclusive center) and
`Truth.Measured.SourcePlane.OccupiedBandwidthHz` for the bbox width -- both from
the Measured plane so the box reflects the realized RX signal, not the planned
`ReceiverView.ProjectedCenterOffsetHz`. Invisible sources are skipped and
reported in `csrd_export.skipped_sources`.
