# Phase 17 运行配置合同总审计与单一权威收口

## 目标

Phase 17 处理的不是单个 `FrameLength` 字段，而是一类系统性问题：同一运行事实被 Runner、Scenario、执行 block、annotation 多处保存，且部分路径有静默 fallback。本阶段的规则是：

- 配置只允许写入运行事实的唯一权威字段。
- 派生字段只能由归一化/执行层计算并校验，不能反向成为权威。
- 旧别名和旧 fallback 直接 fail-fast，不再作为兼容入口保留。
- annotation 只能记录 design / execution / measured 三个 truth plane 的真实来源，不互相补值。

## 合同矩阵

| 类别 | 唯一权威 | 允许派生/输出 | 禁止项 |
| --- | --- | --- | --- |
| Frame samples | `Factories.Scenario.Global.FrameNumSamples` | `FrameDuration = FrameNumSamples / Receiver.SampleRate`; `ObservationDuration = FrameDuration * NumFramesPerScenario`; annotation `FrameLengthSamples` | `Runner.FixedFrameLength`; `Factories.Scenario.Global.FrameLength`; 由 `FrameDuration` 或 `ObservationDuration` 反推 `FrameNumSamples` |
| Frame count | `Factories.Scenario.Global.NumFramesPerScenario` | blueprint `NumFrames`; temporal pattern `NumFrames` | 缺配置 fallback 到 1 帧 |
| Receiver sample rate | `Factories.Scenario.CommunicationBehavior.Receiver.SampleRate` | annotation `Truth.Design.PlannedSampleRate`; execution output `SampleRate` | 从 modulator output 回填 planned sample rate |
| Carrier frequency | receiver plan / regulatory allocation | channel link-budget carrier frequency; annotation execution carrier fields | receiver/channel/ray tracing carrier 独立漂移 |
| Bandwidth | planner `PlannedBandwidth` / placement `TargetBandwidth`; modulator execution `Bandwidth` | annotation `PlannedBandwidthHz`, `ModulatedBandwidthHz`, `OccupiedBandwidthHz` | `ModulationFactory` 缺 `Bandwidth` 时用 planned 值回填 |
| Tx antennas | planner `Hardware.NumAntennas` -> segment `Modulation.NumTransmitAntennas` | modulator output `NumTransmitAntennas`; annotation design antenna count | 执行期根据最后一个 segment 回写 TxInfo；缺配置默认 1 |
| Message length | per-segment clipped placement duration + symbol/bits contract | `Message.Length` and payload bits | `Length=1024`; `SymbolRate=100e3`; `SegmentID`; `SeedValue` |
| Channel seed | non-empty `SignalSources(k).BurstId` plus Tx/Rx ids | deterministic channel seed | missing BurstId fallback to `frame_<id>` |
| Channel model | map profile/channel selection | `Truth.Execution.ChannelModel`; fallback metadata | missing OSM file silently switching to Statistical |
| Physical time resolution | `PhysicalEnvironment.Config.TimeResolution` | physical update cadence | missing value fallback to `0.1` |

## 本阶段实现

- 新增 `csrd.pipeline.runtime.resolveFrameRuntimeContract` 与 `normalizeRuntimeContracts`。
- `config_loader` 在配置加载后立即解析 frame contract 并写入派生字段。
- `SimulationRunner` 拒绝 `Runner.FixedFrameLength`，运行帧形状只从 scenario global contract 解析。
- `processReceiverProcessing` 使用固定 frame shape，把 receiver 输出裁剪/补零到 canonical `FrameNumSamples`。
- `getFramesPerScenarioFromConfig` 删除 silent 1-frame fallback。
- `ModulationFactory` 删除执行元数据回填：缺 `Bandwidth`、`SampleRate`、`NumTransmitAntennas` 直接报错；调制器异常不再吞成 `ModulatorBlockStepFailed`。
- `MessageFactory` 删除 `Length=1024`、`SymbolRate=100e3` fallback，并拒绝 `SegmentID` / `SeedValue` 旧别名。
- `ChannelFactory` 要求非空 `BurstId`，不再用 frame id 参与 seed key。
- 删除生产天线回写路径 `updateTransmitterAntennaConfig` / `applyAntennaConfigFromSegments`。
- `ScenarioFactory` 在 OSM 选中但文件缺失时 fail-fast；`PhysicalEnvironmentSimulator` 缺 `TimeResolution` fail-fast。
- Coverage/generated configs 写出完整 frame 四元组，避免继承 base 派生字段造成 stale `FrameDuration`。
- 删除未被生产代码消费的 `TemporalBehavior.Scheduled.FrameLength` 死配置。

## 外部依据

- MathWorks `comm.OFDMModulator` 文档将 `NumTransmitAntennas` 定义为输入第三维的 transmit streams，且必须不超过物理 Tx 天线数。因此执行层不能在缺 planner 天线数时默认 1，否则 OFDM/MIMO 维度会与硬件合同分叉。
- MathWorks System object 文档说明非 tunable 属性在 object 开始处理后不能随意改变，必须 `release` 后才能更改。这支持本阶段的做法：在 setup/step 前完成配置校验，而不是在执行期根据 segment 输出回写 TxInfo。

参考：

- https://www.mathworks.com/help/comm/ref/comm.ofdmmodulator-system-object.html
- https://www.mathworks.com/help/matlab/matlab_prog/system-design-in-matlab-using-system-objects.html
- https://www.mathworks.com/help/matlab/ref/matlab.system.releasesystemobject.html

## 测试证据

已运行并通过：

- `FrameRuntimeContractTest`
- `RuntimeParameterContractTest`
- `MessageFactoryNoLengthFallbackTest`
- `ModulationFactoryNoExecutionFallbackTest`
- `ChannelSeedRequiresBurstIdTest`
- `AntennaAuthorityContractTest`
- `ChannelSeedBurstAwareTest`
- `MessageFactorySeedAliasTest`
- `SegmentIdContractTest`
- `SignalGatingTest`
- `MultiBurstPerFrameTest`
- `ConstructionFailFastTest`
- `test_no_dead_code_phase17_config_contracts`
- `OFDMMimoModeTest`
- `TRFSimulatorTest`
- `BuildSourceAnnotationV2Test`
- `MeasurementCompletenessHookTest`
- `test_phase16_osm_raytracing_validation_config`: dry-run built 69 cases.
- `test_phase16_spectrogram_overlay_renderer`

Phase 16 high-resolution special case evidence:

- Case: `osm_rt_building_multi_tx_multi_burst_visual`
- Selected index: 29
- Result: `CasesPassed=1`, `CasesFailed=0`
- Rx samples: `262144`
- Rx duration: `0.0131072 s`
- Sources: `9`
- Tx burst counts: `[3 3 3]`
- `BurstId`: all non-empty
- Execution time min/max: `[0.0010486, 0.01232075]`, inside frame
- Spectrogram overlay: `1` image, `9` GT rectangles

## 保留风险

- Full 69-case non-dry run remains expensive. Current evidence covers the dry-run matrix plus the deterministic high-resolution special case.
- Existing resampling warnings in `TRFSimulator` still deserve a separate RF-front-end numerical audit; they are not introduced by the Phase 17 contract changes.
