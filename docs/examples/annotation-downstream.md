# Annotation Downstream Example

Status: Phase 7 validated by `run_csrd_downstream_docs_readiness`.

This example shows how a downstream consumer should read a CSRD annotation
file and optionally export a minimal COCO JSON view. It does not run the
simulator and does not inspect IQ samples.

## Read And Validate Annotation

```matlab
addpath(pwd)

reader = csrd.pipeline.annotation.readAnnotation(annotationPath, ...
    'RequireSources', true, ...
    'RequireRuntimeHeader', true);

disp(reader.Summary)
```

The reader rejects legacy v1 top-level fields and requires populated
`Truth.Design`, `Truth.Execution`, `Truth.Measured`, and `ReceiverView`.

## Interpret Labels

Use these fields for downstream labels:

| Downstream need | Field |
|-----------------|-------|
| Class name / modulation family | `Truth.Design.ModulationFamily` |
| Planned bandwidth | `Truth.Design.PlannedBandwidthHz` |
| Realized clean modulation bandwidth | `Truth.Execution.ModulatedBandwidthHz` |
| Final occupied bandwidth label | `Truth.Measured.SourcePlane.OccupiedBandwidthHz` |
| Receiver-window projection | `ReceiverView.ProjectedCenterOffsetHz` |
| Visibility | `ReceiverView.IsVisible` and `ReceiverView.VisibilityReason` |

Do not infer modulation family from measured spectrum. Do not use planned
bandwidth as the final occupied-bandwidth label when a measured value exists.

## Export Minimal COCO

```matlab
addpath(fullfile(pwd, 'tools'))

coco = convert_csrd_to_coco(annotationPath, outputJsonPath, ...
    'ImageWidth', 1024, ...
    'ImageHeight', 1);
```

The COCO converter uses a receiver-frequency canvas:

- `images[*].width` is the receiver observable frequency axis.
- `images[*].height` is a one-row minimal canvas.
- Category names come from `Truth.Design.ModulationFamily`.
- Bbox center comes from `ReceiverView.ProjectedCenterOffsetHz`.
- Bbox width comes from `Truth.Measured.SourcePlane.OccupiedBandwidthHz`.
- Time occupancy remains metadata because annotation does not persist
  burst start/stop time extents.

Invisible sources are not converted into visible bboxes. They are recorded in
`coco.csrd_export.skipped_sources`.

## Executable Example Function

The repository includes an executable helper:

```matlab
addpath(fullfile(pwd, 'examples'))

summary = read_annotation_downstream(annotationPath, outputJsonPath);
```

The returned `summary` includes frame/source counts and COCO export counts. It
is intended as a downstream integration starting point, not as a replacement for
`readAnnotation`.
