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

### `Header.Runtime.MeasurementContract`

本文件中测量标注**代表什么量**,在一处说清,使消费方永远不必从字段名去推断。设置
`RequireRuntimeHeader` 时必需;reader 会拒绝没有它的标注,也会拒绝自己未实现的版本。

| 字段 | 含义 |
|-------|---------|
| `ContractVersion` | 整数。当发布的量、测量点或估计器发生使新旧数据不可比的变化时递增。当前为 2。 |
| `BandwidthDefinition` | 量的定义,例如 `ITU-R SM.328 occupied bandwidth (99% power)` |
| `BandwidthEstimator` | 计算它的函数 |
| `BandwidthMeasurePoint` | 测量缓冲的取样位置:`post_channel_pre_noise_per_emitter_per_antenna` |
| `NoiseFreeMeasurement` | 测量缓冲是否无噪。reader **拒绝** `false`:功率积分定义的占用带宽在含噪缓冲上是未定义的。 |
| `PerEmitterPerAntenna` | 是否逐发射机、逐天线分离。reader **拒绝** `false`:对独立衰落的天线副本求和,报出的是副本之间的干涉图样,不是任何发射机真正发出的带宽。 |

`MeasurementContract` **缺失**本身也是有意义的:它标识出在"测量前移到注噪之前"这一改动
之前写出的标注——那时 `OccupiedBandwidthHz` 装的是在含噪、天线求和缓冲上测得的
peak-relative 主瓣宽度。那与同名字段现在的量不是一回事,所以这类文件会被拒绝,而不是
被静默混入当前数据。版本 1 追溯地指那个时代,并且没有任何文件带这个标记,因为当时它
还不存在。

不要为"让测量更接近同一个既定定义"的修复递增 `ContractVersion` —— 那是
`BandwidthDefinition` 该表达的事情。

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
| `PlannedBandwidthHz` | Hz | 蓝图带宽:规划器分配的**额度**,即一个上限,不是对测得宽度的预测 |
| `PlannedSampleRate` | Hz | 计划采样率 |
| `PlannedSymbolRateHz` | Hz | 规划器选定的符号率;无此概念的族取 `NaN` |
| `PlannedRolloffFactor` | 标量 | 规划器选定的脉冲成形滚降;不适用处取 `NaN` |
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
| `SourcePlane.MeasurementSemantics` | `receiver_view_isolated_pre_noise` |
| `FramePlane.MeasurementSemantics` | `post_rx_combined_pre_noise` |

两个字符串都带 `_pre_noise`,因为标注可用的前提正是"无噪"这一性质,而旧名
(`receiver_view_isolated` / `post_rx_combined_pre_rfchain`)对此一字未提。
`_pre_noise` 蕴含 pre-RF-chain:延迟注噪器在接收 RF 链之前运行,所以在注噪之前
测得的缓冲必然也在热噪声与 ADC 之前。

reader 硬拒其它取值(`CSRD:AnnotationV2:UnexpectedSemantics`),因此改名自带
版本判别:在"测量前移到注噪之前"这一改动之前写出的标注会被直接拒绝,而不是被
静默混入新数据。这是刻意的——那些旧文件里的占用带宽是在含噪缓冲上用
peak-relative 估计器测出的,与同名字段现在的量不是一回事,而这种混合恰恰是绝
不能进入训练集的。

### `OccupiedBandwidthHz` 是什么量,在什么条件下测得

`OccupiedBandwidthHz` 是 **ITU-R SM.328 / 无线电规则 No. 1.153 的占用带宽**:
两侧各排除总平均功率 0.5% 后的频带。它**不是** x dB 下降宽度;ITU-R SM.443 要求
x 约 26 dB 时后者才近似前者。量的定义与产出它的估计器随值一起发布,使消费方
永远不必猜标注遵循哪种口径:

| 字段 | 含义 |
|-------|---------|
| `BandwidthDefinition` | 量的定义,例如 `ITU-R SM.328 occupied bandwidth (99% power)` |
| `BandwidthEstimator` | 产出该值的函数 |

两个平面都测量**干净、逐发射机、逐天线、注噪之前**的缓冲。逐发射机逐天线很重要:
同一发射机的各天线副本经历独立衰落,先求和会报出副本之间的干涉图样,而不是任何
发射机真正发出的带宽。注噪之前也很重要:功率积分定义在含噪缓冲上不只是不精确,
而是**未定义**——噪声在整个频带贡献功率,而 ECC/REC/(06)01 要求峰值至少高出噪声
底 30 dB 才能测 99% 占用带宽。`SNRdB` 仍然描述**被保存下来**的那一帧所携带的噪声
水平;它和带宽描述同一次投递的不同侧面,不是同一个缓冲的两个属性。

### 测量条件(`SourcePlane`)

一个孤立的数值不足以规定一个测得量(JCGM 200:2012 VIM 2.3)。同一个 15 MHz 读数
在 32768 样本缓冲上和在 64 样本突发上含义完全不同,因为持续时间为 T 的硬门控突发
在 99% 功率口径下确实占据约 10/T ——这是关于"一个本不该那样被构造出来的信号"的
真陈述,不是测量错误。下列字段让消费方能区分这两种情况:

| 字段 | 单位 | 含义 |
|-------|------|---------|
| `BandwidthResolutionHz` | Hz | 该答案实际的分辨率:取"分析栅格"与 `SampleRate / ActiveSampleCount` 中**更粗**的一个,因为零填充只是对频谱插值,从不增加信息 |
| `BandwidthResolutionCells` | 个 | `OccupiedBandwidthHz / BandwidthResolutionHz`。ITU-R SM.443 认为可用的测量 RBW 应为宽度的 1–3%,即 33 格以上;低于约 8 时,该值是被突发长度而非发射机量化的 |
| `ActiveSampleCount` | 个 | 携带能量的样本数,它决定分辨率下限 |
| `HalfPowerSpanHz` | Hz | 由同一次累积行走得到的、容纳中间 50% 功率的跨度 |
| `SpectralConcentrationRatio` | 比值 | `OccupiedBandwidthHz / HalfPowerSpanHz`。任何行为良好的分布都约为 2——干净根升余弦 2.18、白噪声 1.99(平坦谱给出 0.99·Fs / 0.5·Fs)。只有"窄主瓣压在宽底噪上"时才会增大;超过约 8 时,报出的宽度描述的是底噪而不是发射机 |

`SpectralConcentrationRatio` 之所以必需,是因为 `BandwidthResolutionCells` **结构上**
无法发现这种情况:那个字段是"报出的宽度 ÷ 分析分辨率",所以一个**被膨胀**的读数反而得到
**很高**的格数、看起来分辨良好。浓度比拿的是**同一个分布的两个宽度**,因此它测的是形状而
不是大小。

它捕捉的情况是真实的,而且报出的带宽是**正确**的:延迟 1 µs 的两抽头信道频响每 1 MHz 一个
零点、最小值 10.7 dB,所以一个零点落在约 1 MHz 的发射机上会把主瓣压低约 10 dB,而几乎不
触碰硬门控与 PA 再生长留下的宽带底。那个被切槽波形的 ITU 99% 带宽确实是几十 MHz。本数据集
就含有这样一簇——一个 FM 发射机报出 15 MHz,而一半功率在 625 kHz 之内、浓度 24——它以
77 格通过了分辨率检查。需要"标注描述发射机自身带宽"的消费方应按此字段筛选。

这些字段描述测量本身而非标注值,所以与测得的标量不同,对退化缓冲可以合法取 `NaN`。
`BandwidthResolutionCells` 偏低是**精度陈述,不是缺陷**:50 MHz 采样下 512 样本突发
里的 286 kHz 发射机本来就不可能测得比 98 kHz 更细。代表性扫描中约 43% 的源低于
8 格,需要精细宽度的消费方应按该字段筛选。

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

当某个来源的测量平面**明确**报告非 `Measured` 的 `MeasurementStatus` 时(例如静默缓冲:
某发射机的突发与本帧不重叠),该来源同样会被跳过。此时 `NaN` 是诚实的带宽值,而一个这样的
来源不应中止整个数据集导出。每条跳过都带 `skip_reason`,计数汇总在
`csrd_export.skip_reason_counts` 中,并会打印明细——这样系统性的测量故障会表现为一个被
报告的原因,而不是一个安静地变小的数据集。

而一个声称 `Measured`(或什么都不说)却携带 `NaN` 带宽的平面是**自相矛盾**、不是缺失,
仍然**致命**(`CSRD:Tools:CocoMissingFiniteScalar`)。缺失不该换来宽容,否则管线缺陷会
变成一个更小的数据集而不是一个错误。
