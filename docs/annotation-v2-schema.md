# CSRD Annotation V2 Schema

Status: Annotation v2 current contract, updated for scenario-level
`ScenarioPlan` generation.

This document describes the frozen annotation v2 shape used by the refactored
CSRD pipeline. Annotation v2 is not a compatibility layer for legacy v1 fields.
Consumers should read it through `csrd.pipeline.annotation.readAnnotationV2`.

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
reader = csrd.pipeline.annotation.readAnnotationV2(annotationPath, ...
    'RequireSources', true, ...
    'RequireRuntimeHeader', true);
```

`reader.Summary` reports:

| Field | Meaning |
|-------|---------|
| `Schema` | Always `annotation-v2` for this reader |
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
| `PlannedCenterFrequencyHz` | Hz | Blueprint center frequency |
| `PlannedBandwidthHz` | Hz | Blueprint bandwidth |
| `PlannedSampleRate` | Hz | Planned sample rate |
| `ModulationFamily` | text | Design category, used by downstream classifiers |
| `ModulationOrder` | scalar | Modulation order when applicable |
| `PayloadLengthBits` | bits | Planned payload length |
| `NumTransmitAntennas` | count | Planned transmit antenna count |

`Truth.Design.ModulationFamily` is the class label source for COCO conversion.
It is not inferred from IQ.

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

COCO v2 minimal export uses `ReceiverView.ProjectedCenterOffsetHz` for bbox
center and `Truth.Measured.SourcePlane.OccupiedBandwidthHz` for bbox width.
Invisible sources are skipped and reported in `csrd_export.skipped_sources`.
