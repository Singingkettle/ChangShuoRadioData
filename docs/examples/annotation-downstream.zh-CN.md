[English](annotation-downstream.md) | [中文](annotation-downstream.zh-CN.md)

# 标注下游使用示例

状态:Phase 7 已通过 `run_csrd_downstream_docs_readiness` 验证。

本示例展示下游使用方应如何读取一个 CSRD 标注文件,并可选地导出一个最小化的 COCO JSON 视图。它不运行仿真器,也不检查 IQ 采样。

## 读取并校验标注

```matlab
addpath(pwd)

reader = csrd.pipeline.annotation.readAnnotation(annotationPath, ...
    'RequireSources', true, ...
    'RequireRuntimeHeader', true);

disp(reader.Summary)
```

该读取器会拒绝旧版 v1 的顶层字段,并要求 `Truth.Design`、`Truth.Execution`、`Truth.Measured` 和 `ReceiverView` 均已填充。

## 解读标签

下游标签请使用以下字段:

| 下游需求 | 字段 |
|-----------------|-------|
| 类别名 / 调制族 | `Truth.Design.ModulationFamily` |
| 规划带宽 | `Truth.Design.PlannedBandwidthHz` |
| 实现的纯净调制带宽 | `Truth.Execution.ModulatedBandwidthHz` |
| 最终占用带宽标签 | `Truth.Measured.SourcePlane.OccupiedBandwidthHz` |
| 接收窗投影 | `ReceiverView.ProjectedCenterOffsetHz` |
| 可见性 | `ReceiverView.IsVisible` 和 `ReceiverView.VisibilityReason` |

不要从实测频谱推断调制族。当存在实测值时,不要把规划带宽用作最终的占用带宽标签。

## 导出最小化 COCO

```matlab
addpath(fullfile(pwd, 'tools'))

coco = convert_csrd_to_coco(annotationPath, outputJsonPath, ...
    'ImageWidth', 1024, ...
    'ImageHeight', 1);
```

COCO 转换器使用一个接收机频率画布:

- `images[*].width` 是接收机可观测的频率轴。
- `images[*].height` 是单行的最小化画布。
- 类别名来自 `Truth.Design.ModulationFamily`。
- 边界框中心来自 `Truth.Measured.SourcePlane.CenterFrequencyHz`。
- 边界框宽度来自 `Truth.Measured.SourcePlane.OccupiedBandwidthHz`。
- 时间占用仍保留为元数据,因为标注并不持久化突发的起止时间范围。

不可见的源不会被转换为可见的边界框。它们被记录在 `coco.csrd_export.skipped_sources` 中。

## 可执行示例函数

仓库中包含一个可执行的辅助函数:

```matlab
addpath(fullfile(pwd, 'examples'))

summary = read_annotation_downstream(annotationPath, outputJsonPath);
```

返回的 `summary` 包含帧/源计数以及 COCO 导出计数。它旨在作为下游集成的起点,而非 `readAnnotation` 的替代品。
