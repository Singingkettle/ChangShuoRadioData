![Citybuster Studio Logo](assets/logo.svg)

# ChangShuo Radio Data (CSRD)

ChangShuo Radio Data is a MATLAB-based wireless spectrum simulation system.
Its core purpose is to generate synthetic radio monitoring data where the
received signal, scene state, and annotation describe the same physical and
communication event.

ChangShuo Radio Data 是一个基于 MATLAB 的无线频谱数据仿真项目。当前主线的目标不是
简单生成波形，而是保证 **信号、场景状态、标注三者一致**，用于频谱感知、占用分析和
下游模型训练/评估。

## Current Status / 当前状态

The repository is now on the post-Phase-18 refactored architecture. The old
JSAC-era behavior is still available from the stable historical tag:

稳定旧版本仍保留在：

https://github.com/Singingkettle/ChangShuoRadioData/tree/a6d09a4b264894b76f852ce33bfd82adc7b270b5

The current main branch has moved through the audit/refactor phases documented
under `docs/audits/`. Those audit files are historical records. For the current
source layout and usage, start from this README and `docs/architecture/source-layout.md`.

当前 `main` 已完成 Phase 18 运行真值合同硬化。`docs/audits/` 中的长文档主要是历史审计
记录；查看当前目录和入口时，请以本文件和 `docs/architecture/source-layout.md` 为准。

## Main Entry Points / 主要入口

| Purpose / 用途 | Entry / 入口 | Notes / 说明 |
| --- | --- | --- |
| Public simulation run / 公开仿真入口 | `tools/simulation.m` | Loads config, initializes logging, runs workers. |
| Config loader / 配置加载 | `csrd.runtime.config_loader` | Loads modular configs and applies runtime contract normalization. |
| Runner / 批量运行器 | `+csrd/SimulationRunner.m` | Multi-scenario orchestration, data save, annotation validation. |
| Scenario engine / 单场景引擎 | `+csrd/+core/@ChangShuo` | Per-frame signal generation, propagation, receiver processing, annotation. |
| Full validation / 全覆盖验证 | `csrd.support.validation.runFullCoverageValidation` | Used by Phase 13/16/18 validation profiles. |

Minimal run:

```matlab
addpath(pwd)
addpath(fullfile(pwd, 'tools'))
simulation(1, 1, 'csrd2025/csrd2025.m')
```

Load a config directly:

```matlab
cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
runner = csrd.SimulationRunner('RunnerConfig', cfg.Runner);
runner.FactoryConfigs = cfg.Factories;
runner(1, 1);
```

## Pipeline / 主链路

The production pipeline should be read as:

```text
SimulationRunner
  -> ChangShuo
    -> ScenarioFactory
      -> PhysicalEnvironmentSimulator
      -> CommunicationBehaviorSimulator
    -> MessageFactory
    -> ModulationFactory
    -> TransmitFactory
    -> ChannelFactory
    -> ReceiveFactory
    -> annotation v2 export
```

The key architectural rule is separation between planning and execution.
Scenario blocks plan entities, timing, spectrum, and receiver views. Factories
and physical blocks execute that plan. Annotation records design, execution, and
measurement as separate truth planes.

核心规则是“规划”和“执行”分开：场景层负责规划 Tx/Rx、时间、频率和 receiver view；
工厂和物理模块负责执行；annotation v2 分别记录 `Truth.Design`、`Truth.Execution`
和 `Truth.Measured`。

## Current Source Layout / 当前目录职责

| Path | Responsibility |
| --- | --- |
| `+csrd/+blocks` | Scenario, RF, modulation, message, and channel System objects. |
| `+csrd/+catalog` | Regulatory spectrum catalogs and reusable profile data. |
| `+csrd/+core` | `ChangShuo` scenario engine and frame-processing helpers. |
| `+csrd/+factories` | Factory objects that instantiate execution blocks from planned config. |
| `+csrd/+pipeline` | Cross-module contract helpers for annotation, blueprint, runtime, link budget, measurement, scenario, and signal gating. |
| `+csrd/+runtime` | Config loading, logging, toolbox checks, system info, RF capabilities, map probes. |
| `+csrd/+support` | Validation, documentation, hashing, path, random, and optimization support utilities. |
| `+csrd/+test_support` | Test-only helpers and failing stubs; not production code. |
| `config/` | Modular runtime configurations. |
| `docs/` | Current docs plus historical audits. |
| `examples/` | Downstream usage examples. |
| `tests/` | Unit and regression tests. |
| `tools/` | Public CLI-style MATLAB entry points and maintenance utilities. |
| `data/` | Ignored generated datasets and validation outputs. |
| `artifacts/` | Ignored diagnostics, visual checks, generated configs, and audit manifests. |

The legacy catch-all utility package is intentionally absent. Use `+runtime`,
`+catalog`, `+pipeline`, or `+support` according to responsibility.

当前不再保留生产用的泛化工具包。新增代码必须按职责进入 `+runtime`、`+catalog`、
`+pipeline` 或 `+support`。

## Runtime Contracts / 运行合同

The current runtime contracts intentionally fail fast when core facts are
missing or contradictory:

- Frame length authority: `Factories.Scenario.Global.FrameNumSamples`.
- Receiver sample-rate authority: receiver observation plan and `rxInfo.SampleRate`.
- Carrier-frequency authority: receiver RF plan and `rxInfo.RealCarrierFrequency`.
- Planned bandwidth, execution bandwidth, and measured bandwidth stay separate.
- `BurstId` is required for live signal sources and channel seed derivation.
- Live `Truth.Execution` times must match actual receiver sample-grid insertion.
- Downstream blocks must not backfill missing runtime facts from defaults.

当前运行合同会对核心事实缺失或冲突直接报错，不再用旧默认值悄悄补齐。这样做是为了保证
信号、场景和标注描述的是同一个事件。

See `docs/configuration.md` and `docs/audits/phases/phase-18-runtime-truth-contract-hardening.md`.

## Configuration / 配置

The default example config is:

```matlab
cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
```

Full validation profiles are separate from the default steady-state config:

- `config/csrd2025/csrd2025_full_coverage_validation.m`
- `config/csrd2025/csrd2025_osm_raytracing_validation.m`

Configuration guide: `docs/configuration.md`.

## Tests And Validation / 测试与验证

Run targeted suites from MATLAB:

```matlab
addpath(pwd)
addpath(fullfile(pwd, 'tests'))

run_all_tests('unit')
run_all_tests('regression')
run_all_tests('all', 'verbose', true)
```

Important validation entry points:

```matlab
addpath(fullfile(pwd, 'tools', 'ci'))
run_csrd_ci_smoke()
run_phase18_nightly_validation()
```

Some full validation runs can be expensive and write ignored outputs under
`data/` or `artifacts/`.

部分完整验证耗时较长，会在 ignored 的 `data/` 或 `artifacts/` 下写出结果。

## Documentation Map / 文档地图

- `docs/README.md`: documentation index.
- `docs/architecture/source-layout.md`: current package layout and ownership.
- `docs/configuration.md`: modular config and runtime contract guide.
- `docs/annotation-v2-schema.md`: annotation schema for downstream users.
- `docs/README_Weather.md`: weather configuration guide.
- `docs/README_Refactoring.md`: current refactor status index.
- `docs/audits/`: historical audit records and handover notes.

## Development Rules / 开发规则

Read `AGENTS.md` before changing production code. The most important invariant:

> The generated signal, scene state, and annotation must describe the same
> underlying event.

核心不变量：

> 生成信号、场景状态和标注必须描述同一个底层事件。

## Citation / 引用

```bibtex
@software{chang_shuo_2025_10667001,
  author       = {Chang, Shuo},
  title        = {ChangShuoRadioData: A Comprehensive MATLAB-based Radio Communication Simulation Framework},
  month        = mar,
  year         = 2025,
  publisher    = {ChangShuoLab},
  version      = {v1.0.0},
  url          = {https://github.com/Singingkettle/ChangShuoRadioData}
}

@ARTICLE{10667001,
  author={Xing, Huijun and Zhang, Xuhui and Chang, Shuo and Ren, Jinke and Zhang, Zixun and Xu, Jie and Cui, Shuguang},
  journal={IEEE Transactions on Wireless Communications},
  title={Joint Signal Detection and Automatic Modulation Classification via Deep Learning},
  year={2024},
  volume={23},
  number={11},
  pages={17129-17142},
  doi={10.1109/TWC.2024.3450972}
}
```

All rights of interpretation for this project belong to Citybuster Studio.
