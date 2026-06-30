[English](annotation-schema.md) | [中文](annotation-schema.zh-CN.md)

# CSRD 标注 Schema

状态:标注当前契约,已针对场景级 `ScenarioPlan` 生成进行更新。

本文档描述重构后的 CSRD 流水线所使用的冻结标注结构。标注不是面向旧版 v1 字段的兼容层。
消费方应通过 `csrd.pipeline.annotation.readAnnotation` 来读取它。

## 核心规则

每一条导出的标注都必须描述与所生成信号及场景状态相同的事件。

该 schema 按来源对事实进行分离:

| 命名空间 | 含义 | 来源 |
|-----------|---------|--------|
| `Truth.Design` | 来自场景规划的计划事实 | `ScenarioPlan` / 规划阶段 |
| `Truth.Execution` | 来自波形、信道、几何与 RF 执行的已实现构建事实 | 构建阶段 |
| `Truth.Measured` | 在信号生成之后计算得到的测量值 | 测量阶段 |
| `ReceiverView` | 将某一来源投影到某一接收机观测窗口的投影结果 | 接收机视图构建 |

诸如调制族这样的设计事实无需测量。诸如占用带宽这样的取值可能与计划带宽不同,因此最终标签
使用测量字段。

当前生成过程会在每个场景的第一帧之前构建一个冻结的 `ScenarioPlan`。标注头部可能包含
`ScenarioPlan.Frame` 和 `DatasetAccounting`;每个来源的设计事实必须与该计划一致,而
执行与测量事实仍然取自实际生成的数据。

## 根结构

根标注包含 `Frames`。发布制品应带有运行时头部:

```matlab
reader = csrd.pipeline.annotation.readAnnotation(annotationPath, ...
    'RequireSources', true, ...
    'RequireRuntimeHeader', true);
```

`reader.Summary` 报告:

| 字段 | 含义 |
|-------|---------|
| `Schema` | 对于该读取器始终为 `annotation` |
| `NumFrames` | 标注中接收机帧的数量 |
| `NumSources` | 跨帧的可见或隐藏来源记录数量 |
| `NumReceivers` | 唯一接收机 ID 的数量 |
| `ReceiverIDs` | 接收机 ID 列表 |

## 帧字段

每一帧必须包含:

| 字段 | 单位 | 含义 |
|-------|------|---------|
| `FrameId` | 索引 | 帧标识符 |
| `ReceiverID` | 文本 | 拥有该观测的接收机 |
| `Status` | 文本 | 对于 v2 读取器的接受,必须为 `Success` |
| `SignalSources` | 结构体数组 | 该接收机帧中每个来源的记录 |
| `SampleRate` | Hz | 接收机采样率(存在时) |
| `ObservableRange` | Hz | 接收机可观测频率范围 `[low high]`(存在时) |
| `ScenarioPlan` | 结构体 | 所属场景的可选场景计划头部 |
| `DatasetAccounting` | 结构体 | 从 `ScenarioPlan` 复制而来的可选接收机帧记账 |

## 来源字段

每个来源必须包含:

| 字段 | 含义 |
|-------|---------|
| `TxID` | 发射机标识符 |
| `SegmentId` | 帧内的分段标识符 |
| `BurstId` | 用于可复现性与信道种子分离的突发标识符 |
| `Truth` | Design / Execution / Measured 命名空间 |
| `RFImpairments` | 执行期间施加的 RF 损伤 |
| `ReceiverView` | 接收机特定的投影频率视图 |

禁止使用旧版 v1 的顶层字段:`Realized`、`Planned`、`Temporal`、
`Spatial`、`LinkBudget` 和 `Channel`。

## Truth.Design

| 字段 | 单位 | 含义 |
|-------|------|---------|
| `PlannedCenterFrequencyHz` | Hz | 计划的来源中心,作为**接收机基带偏移**(与 `Execution.CenterFrequencyOffsetHz` 和 `ReceiverView.ProjectedCenterOffsetHz` 处于同一坐标系),而非绝对 RF 载波 |
| `PlannedBandwidthHz` | Hz | 蓝图带宽 |
| `PlannedSampleRate` | Hz | 计划采样率 |
| `ModulationFamily` | 文本 | 设计类别,供下游分类器使用 |
| `ModulationOrder` | 标量 | 适用时的调制阶数 |
| `MessageSource` | 文本 | 基带源:`Audio`(模拟)或 `RandomBit`(数字) |
| `IsDigital` | 逻辑值 | 调制族是否为数字 |
| `PayloadLengthBits` | 比特 | 计划载荷长度 |
| `NumTransmitAntennas` | 计数 | 计划发射天线数量 |

所有标注频率都以接收机为中心:载波 `RealCarrierFrequency`
有意从不进入基带/波形生成(它仅驱动路径损耗、
天线方向图和多普勒)。因此 `PlannedCenterFrequencyHz` 是相对于接收机调谐中心的基带
偏移,与 Execution 和 Measured 的中心字段处于同一坐标系——尽管沿用了历史上的
"CenterFrequency" 名称。需要绝对 RF 中心的消费方必须加上所属接收机的
`RealCarrierFrequency`;将该字段当作绝对载波来读取会错出约一个
调谐频率的量级。

`Truth.Design.ModulationFamily` 是 COCO 转换的类别标签来源。
它不是从 IQ 推断出来的。

消息源是调制族的确定性函数,而非
自由选择:模拟族(FM/PM/AM 变体)由 `Audio` 驱动,数字
族(PSK/QAM/FSK/...)由 `RandomBit` 驱动。读取器会拒绝任何
其 `MessageSource`/`IsDigital` 与 `ModulationFamily` 不一致的标注
(`CSRD:Annotation:MessageSourceModulationMismatch` /
`CSRD:Annotation:IsDigitalModulationMismatch`)。

## Truth.Execution

| 字段 | 单位 | 含义 |
|-------|------|---------|
| `ModulatedBandwidthHz` | Hz | 在干净的调制器输出上测得的带宽 |
| `CenterFrequencyOffsetHz` | Hz | 以接收机为中心坐标下的已实现来源偏移 |
| `SampleRate` | Hz | 已执行的来源采样率 |
| `ChannelModel` | 文本 | 实际使用的信道模型 |
| `PathLossDB` | dB | 施加的路径损耗 |
| `AnalyticalSNRdB` | dB | 链路预算分析 SNR |
| `AppliedSNRdB` | dB | 施加的 SNR 元数据 |
| `DopplerShiftHz` | Hz | 使用外部多普勒时所施加的多普勒频移 |
| `RadialVelocityMps` | m/s | 链路径向速度 |
| `GeometrySnapshot` | 结构体 | Tx/Rx 位置、速度以及以米为单位的距离 |
| `MapProfile` | 结构体 | 可选的 RayTracing/OSM 执行地图配置 |
| `RayCount` | 计数 | 可选的 RayTracing 返回射线路径数量 |
| `ChannelFallback` | 文本 | 可选的 RayTracing 所使用的显式回退,例如平地自由空间衰减 |

`GeometrySnapshot` 包含 `TxPositionM`、`TxVelocityMps`、`RxPositionM`、
`RxVelocityMps` 和 `LinkDistanceM`。`RadialVelocityMps` 由相对速度
`TxVelocityMps - RxVelocityMps` 投影到 Tx 到 Rx 视线方向上计算得出,
因此仅接收机的移动性会同时体现在 IQ 与标签中。

当使用 OSM RayTracing 时,`MapProfile` 会记录此次运行使用的是
`OSMBuildings` 还是 `FlatTerrain`、是否存在建筑物,以及
所执行的 `ChannelModel`。空的/无建筑的 OSM 情形必须暴露任何
`ChannelFallback`,而不是悄悄宣称使用了比实际运行更丰富的路径。

## Truth.Measured

`Truth.Measured` 包含 `SourcePlane` 和 `FramePlane`。

| 平面 | 含义 |
|-------|---------|
| `SourcePlane` | 经过信道之后、进入接收机 RF 链路之前的孤立来源 |
| `FramePlane` | 进入接收机 RF 链路之前的合成接收机帧 |

两个平面都携带占用带宽、中心频率、时间占用、
频率占用以及 `MeasurementSemantics`。`SourcePlane` 还携带
`SNRdB`。

必需语义:

| 字段 | 必需取值 |
|-------|----------------|
| `SourcePlane.MeasurementSemantics` | `receiver_view_isolated` |
| `FramePlane.MeasurementSemantics` | `post_rx_combined_pre_rfchain` |

## ReceiverView

接收机视图字段是按来源、按接收机分别给出的:

| 字段 | 单位 | 含义 |
|-------|------|---------|
| `ReceiverId` | 文本 | 接收机 ID |
| `ProjectedCenterOffsetHz` | Hz | 投影到该接收机窗口中的来源中心 |
| `ProjectedLowerEdgeHz` | Hz | 投影后的下边沿 |
| `ProjectedUpperEdgeHz` | Hz | 投影后的上边沿 |
| `IsVisible` | 逻辑值 | 该来源在接收机窗口中是否可见 |
| `VisibilityReason` | 文本 | 原因,例如 `InBand` 或 `OutOfBand` |

COCO 最小导出使用 `Truth.Measured.SourcePlane.CenterFrequencyHz` 作为
bbox 中心(测得的、含多普勒的中心),并使用
`Truth.Measured.SourcePlane.OccupiedBandwidthHz` 作为 bbox 宽度——二者均
来自 Measured 平面,因此该框反映的是已实现的 RX 信号,而非计划的
`ReceiverView.ProjectedCenterOffsetHz`。不可见的来源会被跳过,并
在 `csrd_export.skipped_sources` 中报告。
