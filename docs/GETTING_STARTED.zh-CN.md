[English](GETTING_STARTED.md) | [中文](GETTING_STARTED.zh-CN.md)

# 快速上手 — 生成你的第一个数据集

本指南将带你从一次全新克隆走到在磁盘上生成出一个 CSRD 数据集。CSRD
(ChangShuo Radio Data) 是一个 MATLAB 频谱感知数据生成器:它生成基带 IQ
信号,并附带标注,这些标注针对每一帧中每一个辐射源,描述了**计划**、**执行**
和**测量**到的内容。

如果你只想读取一个已经生成好的数据集,可以直接跳到
[读取输出](#5-读取输出)和
[`annotation-schema.md`](annotation-schema.zh-CN.md)。

---

## 1. 前置条件

### MATLAB
- **MATLAB R2025a** 或更新版本。
- 必需的工具箱(运行时会在启动阶段进行校验,若缺少任一项则立即报错失败 ——
  见 `+csrd/+runtime/+toolbox/validateRequiredToolboxes.m`):
  - **Communications Toolbox** —— 调制、信道模型、射频损伤。
  - **Signal Processing Toolbox** —— 滤波、频谱测量。
  - **Phased Array System Toolbox** —— 用于 OSM 射线追踪的 `txsite`/`rxsite`/`raytrace`。
  - **Antenna Toolbox** —— 射线追踪所用的天线几何。
  - Parallel Computing Toolbox 为**可选**(仅用于多 worker 运行)。

### Python(仅用于下载 OSM 地图数据 —— 见步骤 1)
- **Python 3.6+**,并安装 `requests` 包:`pip install requests`。
- 生成或读取数据**不**需要 Python;它仅被 OSM 下载辅助脚本
  `tools/download_osm.py` 使用。(COCO 导出器
  `tools/convert_csrd_to_coco.m` 是纯 MATLAB 实现。)

### 磁盘
- 一套完整的 OSM 地图集(`tools/download_osm.py`)约为数百 MB。生成的
  数据集会随场景/帧的数量增长。

---

## 2. 获取地图数据 (OSM) —— 默认配置必需

**为什么这很重要:** 默认的 `csrd2025` 配置会从 **OSM 射线追踪**信道抽取约
90% 的场景,从统计信道抽取约 10%
(`config/_base_/factories/scenario_factory.m`:`Map.Types = {'Statistical','OSM'}`,
`Map.Ratio = [0.1, 0.9]`)。OSM 场景从 `data/map/osm/` 读取真实的 OpenStreetMap
建筑几何。**如果该目录为空,生成会立即报错失败**,抛出
`CSRD:Scenario:MissingOSMFile`(`+csrd/+factories/ScenarioFactory.m`)。

任选其一:

### 选项 A —— 下载 OSM 数据(推荐,用于真实的射线追踪)
```bash
pip install requests
python tools/download_osm.py
```
该脚本查询公开的 Overpass API,并在 `data/map/osm/<Category>/` 下写入
`.osm` 文件(例如 `Dense_Urban_High_Rise/`、`Urban_Canyon/` 等)。
下载完整的默认集较慢(有速率限制;请预留时间);你可以提前停止 ——
任何已经写入的 `.osm` 文件都可以使用。

### 选项 B —— 仅使用统计信道(不下载 OSM)
若想在没有外部数据的情况下快速完成首次运行,可在你的配置中将信道限制为
统计模型:
```matlab
config.Factories.Scenario.PhysicalEnvironment.Map.Types = {'Statistical'};
config.Factories.Scenario.PhysicalEnvironment.Map.Ratio = 1;
```
(编辑 `config/csrd2025/csrd2025.m` 的一份副本 —— 见[自定义](#6-自定义运行)。)

> 模拟调制(FM/AM/PM)所用的音频已**随仓库一并打包**
> (`+csrd/+blocks/+physical/+message/audio/*.wav`,公有领域的 NASA 片段)——
> 无需下载。

---

## 3. 生成数据

在仓库根目录下,于 MATLAB 中:

```matlab
addpath(pwd)
addpath(fullfile(pwd, 'tools'))
simulation(1, 1, 'csrd2025/csrd2025.m')
```

`simulation(worker_id, num_workers, config_name)`(`tools/simulation.m`)会加载
配置、校验工具箱,并运行分配给该 worker 的场景。三个参数全部可选;上面的
调用是显式的单 worker 形式(等价于 `simulation()`)。

无界面 / 批处理(例如 CI、脚本化):
```bash
matlab -batch "addpath(pwd); addpath(fullfile(pwd,'tools')); simulation(1, 1, 'csrd2025/csrd2025.m')"
```

多 worker(每个 worker 是一个独立的 MATLAB 进程;对场景进行轮询分配):
```bash
matlab -batch "addpath(pwd); addpath(fullfile(pwd,'tools')); simulation(1, 4, 'csrd2025/csrd2025.m')"   # worker 1 of 4
# ... 在并行进程中以 2、3、4 of 4 重复执行
```

---

## 4. 一次运行会做什么

对于每个场景,引擎会构建一个**冻结的 `ScenarioPlan`**,随后针对每一帧
实例化发射机/接收机、生成调制信号、使其在信道中传播、施加接收机射频损伤,
并记录接收机帧。每个辐射源都会在三个真值平面上被标注 ——
`Design`(计划)、`Execution`(已实现的解析状态)以及 `Measured`
(从已实现的 RX 信号中测量得到,即数据集的真值)。

---

## 5. 读取输出

数据会落在一个带时间戳的会话目录下:

```
data/CSRD2025/session_YYYYMMDD_HHMMSS/
├── scenarios/    scenario_000001_data.mat   (IQ 信号缓冲区,变量:scenarioData)
├── annotations/  scenario_000001_annotation.json   (逐帧、逐辐射源的真值)
└── logs/         CSRD_YYYYMMDD_HHMMSS.log
```

- `Runner.Data.OutputDirectory`(默认 `CSRD2025`)设置 `data/` 下的文件夹。
- 每个场景对应一个标注 JSON,其中包含 `Frames[*]` → `SignalSources[*]`,带有
  `Truth.Design` / `Truth.Execution` / `Truth.Measured`,以及接收机信息和
  射频损伤。逐字段含义见
  [`annotation-schema.md`](annotation-schema.zh-CN.md);一个下游读取示例
  (含 COCO 导出)见
  [`examples/annotation-downstream.md`](examples/annotation-downstream.zh-CN.md)。

在 MATLAB 中可用 `csrd.pipeline.annotation.readAnnotation` 读取一份标注。

---

## 6. 自定义运行

将 `config/csrd2025/csrd2025.m` 复制为 `config/csrd2025/` 下的一个新文件,
并把它的路径传给 `simulation(...)`。常用的调节项:

| 目标 | 字段 | 默认值 |
| --- | --- | --- |
| 场景数量 | `Runner.NumScenarios` | 4 |
| 可复现的运行 | `Runner.RandomSeed` | `'shuffle'`(设为一个整数) |
| 每个场景的帧数 | `Factories.Scenario.FramePolicy.NumFramesPerScenario.{Min,Max}` | 4–10 |
| 帧大小(采样点数) | `Factories.Scenario.FramePolicy.FrameNumSamples.Values` | `[1024 2048 4096]` |
| 目标 SNR 范围 (dB) | `Factories.Channel.LinkBudget.TargetSnrRangeDb` | `[-10, 30]` |
| 信道混合(统计/OSM) | `Factories.Scenario.PhysicalEnvironment.Map.{Types,Ratio}` | `{'Statistical','OSM'}`、`[0.1,0.9]` |

配置通过 `baseConfigs` 列表从 `config/_base_/` 继承;完整的契约见
[`configuration.md`](configuration.zh-CN.md)。

---

## 7. 验证你的安装

快速冒烟测试(一个基线场景,跳过繁重的 Phase-4 套件):
```matlab
addpath(pwd); addpath(fullfile(pwd, 'tools', 'ci'))
run_csrd_ci_smoke('IncludePhase4', false, 'BaselineScenarios', 1)
```
完整的 CI 冒烟测试(GitHub Actions 所运行的)是 `run_csrd_ci_smoke()`
(`.github/workflows/csrd-ci-smoke.yml`)。单元测试:
```matlab
addpath(pwd); addpath(fullfile(pwd, 'tests'))
run_all_tests('unit')
```

---

## 8. 故障排查

| 现象 | 原因与修复 |
| --- | --- |
| `CSRD:Scenario:MissingOSMFile` | `data/map/osm/` 为空,但配置需要 OSM。请完成步骤 1(下载,或切换为仅统计信道)。 |
| 启动时出现工具箱缺失错误 | 某个必需工具箱(Communications / Signal Processing / Phased Array System / Antenna)未安装或未授权。 |
| `CSRD:Message:NoAudioClips` | `+csrd/+blocks/+physical/+message/audio/` 下打包的音频丢失 —— 请从仓库恢复。 |
| 输出为空 / 无输出 | 检查会话的 `logs/` 中的立即失败错误;CSRD 不会静默跳过 —— 一个失败的场景会使整次运行失败。 |

---

另见:[文档索引](README.zh-CN.md) · [配置](configuration.zh-CN.md) ·
[标注模式](annotation-schema.zh-CN.md) · [源码布局](architecture/source-layout.zh-CN.md)。
