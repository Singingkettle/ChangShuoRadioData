![Citybuster Studio Logo](assets/logo.svg)

# 📡 ChangShuo Radio Data (CSRD)

A comprehensive MATLAB-based radio communication simulation framework for wireless communication system simulation and analysis. 

---

## ⚠️ **IMPORTANT NOTICE / 重要提示**

### 🔄 **Code Refactoring Status / 代码重构状态**

**English:**
> ⚠️ **The v0.4 multi-stage refactor is frozen as of 2026-04-27.** The Blueprint / Construction / Measurement contracts now have Phase 0-5 audit and regression evidence, but no new public release has been cut yet; use the v1 stable tag below if you need the exact JSAC-era behavior.
>
> The original drivers for the refactor:
>
> 1. **Ray Tracing Stability Issues**: The original implementation has problems that cause instability in ray tracing, especially when OSM files do not contain buildings, which leads to exceptions. While patches can be applied, the author believes this is not a good approach and is addressing it properly during the refactoring (see `tests/regression/test_empty_osm_raytracing.m`).
>
> 2. **Module Design Confusion**: The original modules confused planning with execution. The refactor enforces a strict split: scenario blocks (`PhysicalEnvironmentSimulator`, `CommunicationBehaviorSimulator`) **plan** what every Tx/Rx should do; factories (`ScenarioFactory`, `ModulationFactory`, `MessageFactory`, `TransmitFactory`, `ChannelFactory`, `ReceiveFactory`) **execute** those plans and write the realized values into annotations.
>
> **Note**: The author is a junior faculty member (青椒) and is the sole maintainer of this project. Updates land only when time permits. **If you need a known-good revision for running experiments today, use the v1 stable tag**:
>
> **Stable Version (v1, JSAC paper)**: [https://github.com/Singingkettle/ChangShuoRadioData/tree/a6d09a4b264894b76f852ce33bfd82adc7b270b5](https://github.com/Singingkettle/ChangShuoRadioData/tree/a6d09a4b264894b76f852ce33bfd82adc7b270b5)

**中文：**
> ⚠️ **v0.4 多阶段重构已于 2026-04-27 冻结。** Blueprint / Construction / Measurement 三层契约已有 Phase 0-5 审计与回归证据，但尚未切新的公开稳定 release；如果需要 JSAC 论文时代的完全一致行为，请继续使用下方 v1 稳定 tag。
>
> 重构的两个原始驱动力：
>
> 1. **Ray Tracing 稳定性问题**：原始实现在 raytracing 上不稳定，尤其当 OSM 中不存在建筑物时会异常。打补丁不是好办法，我们在重构里把这条路彻底走通（回归测试见 `tests/regression/test_empty_osm_raytracing.m`）。
>
> 2. **模块设计混乱**：原版本里"规划"和"执行"混在一起。重构强制二者分离：场景层（`PhysicalEnvironmentSimulator` + `CommunicationBehaviorSimulator`）**只负责规划**每个 Tx/Rx 应该怎么发什么；工厂层（`ScenarioFactory` 等 6 个 Factory）**只负责执行**规划，并把"真实兑现的值"写回标注。
>
> **说明**：作者是青椒，独自维护这个项目，只能抽空更新。**如果您今天就需要稳定可用的版本来跑实验，请用 v1 稳定 tag**：
>
> **稳定版本（v1，对应 JSAC 论文）**：[https://github.com/Singingkettle/ChangShuoRadioData/tree/a6d09a4b264894b76f852ce33bfd82adc7b270b5](https://github.com/Singingkettle/ChangShuoRadioData/tree/a6d09a4b264894b76f852ce33bfd82adc7b270b5)

### 🚦 v0.4 phased refactor — **Phase 0-5 Frozen 2026-04-27**

The audit pass below (review/spectrum-sim-audit) finished v0.3 of the refactor. The current track is **v0.4**, organised into 6 phases (audit document: [`docs/audits/2026-04-spectrum-blueprint-construction-refactor.md`](docs/audits/2026-04-spectrum-blueprint-construction-refactor.md), §17.2).

| Phase | Title | Status |
|------:|------|:--:|
| 0 | Baseline + foundations (toolbox check, log policy, JSON sanitization, baseline sweep) | ✅ **Frozen 2026-04-24** ([`docs/audits/phases/phase-0-baseline.md`](docs/audits/phases/phase-0-baseline.md)) |
| 1 | Dataflow + exception contract (signal struct schema, channel seed, mergeChannelOutput) | ✅ **Frozen 2026-04-25** ([`docs/audits/phases/phase-1-dataflow.md`](docs/audits/phases/phase-1-dataflow.md)) |
| 2 | Blueprint layer skeleton (profile libraries, BlueprintHash, validator) | ✅ **Frozen 2026-04-25** ([`docs/audits/phases/phase-2-blueprint.md`](docs/audits/phases/phase-2-blueprint.md)) |
| 3 | Construction layer rigorisation (silent-fallback removal, ReceiverViews, provenance dataflow) | ✅ **Frozen 2026-04-25** ([`docs/audits/phases/phase-3-construction.md`](docs/audits/phases/phase-3-construction.md)) |
| 4 | Measurement layer + Doppler + annotation v2 | ✅ **Frozen 2026-04-26** ([`docs/audits/phases/phase-4-measurement.md`](docs/audits/phases/phase-4-measurement.md)) |
| 5 | Large-scale MC + CI hooks + final hardening | ✅ **Frozen 2026-04-27** ([`docs/audits/phases/phase-5-mc-validation.md`](docs/audits/phases/phase-5-mc-validation.md)) |

Phase 5 outcome (from `docs/baselines/2026-04-final-v04.json`): 1000 scenarios, **BlueprintAcceptanceRate = 1.0**, **ChannelFactoryFailureRate = 0**, **ExecutionVsMeasuredBwAbsRelDiffP95 = 0.022217530072084515**, **JsonNanCount = 0**, **JsonInfinityCount = 0**. Operator MC wallclock is recorded as diagnostic metadata; CI smoke remains the hard runtime gate.

### 🧭 v0.5 next track — **Phase 6 Draft 2026-04-27**

The next stage is release hardening, not a rewrite of the frozen truth model. Phase 6 is documented in [`docs/audits/phases/phase-6-release-hardening.md`](docs/audits/phases/phase-6-release-hardening.md) and focuses on release readiness, annotation v2 reader/export tooling, COCO v2 conversion, performance diagnostics, and CI hardening. S1-S5 are now landed: the v2 reader, release readiness gate, and minimal receiver-frequency COCO v2 converter are available. Phase 6 explicitly does **not** reintroduce annotation v1 compatibility or change the Blueprint / Construction / Measurement contract.

Phase 6 release readiness check:

```matlab
addpath(fullfile(pwd, 'tools', 'release'))
run_csrd_release_readiness()                % read-only final-v04 readiness gate

addpath(fullfile(pwd, 'tests'))
run_all_tests('phase6')                     % v2 reader + COCO converter + readiness

addpath(fullfile(pwd, 'tools'))
coco = convert_csrd_to_coco(annotationPath, outputJsonPath);
% annotationPath must point to a CSRD annotation v2 JSON file with populated
% Truth.Design and Truth.Measured.SourcePlane fields.
```

Phase 0 quick start (no real simulation needed):

```matlab
cd('c:\Users\lenovo\ChangShuoRadioData')
addpath(pwd)
addpath(fullfile(pwd, 'tests'))
run_all_tests('phase0')                    % 6 unit tests + 2 regression tests
```

The Phase 4 baseline sweep defaults to a 12-scenario smoke run; the canonical 210-scenario sweep is operator-driven:

```matlab
addpath(fullfile(pwd, 'tests', 'regression'))
test_baseline_sweep_200(210, 'Mode', 'full')
% writes docs/baselines/2026-04-baseline-v0.json
```

Phase 5 final verification uses a local CI smoke entry point and an operator-driven 1000-scenario MC wrapper:

```matlab
addpath(fullfile(pwd, 'tools', 'ci'))
run_csrd_ci_smoke()                         % static gates + phase4 + MC smoke

addpath(fullfile(pwd, 'tools', 'phase5'))
run_phase5_mc_validation()                  % writes docs/baselines/2026-04-final-v04.json
```

### 🛠️ Recent audit pass (review/spectrum-sim-audit, merged into `main`)

This branch landed an end-to-end review and 18 fix commits across five stages. Key things that changed:

- **Physical correctness**
  - `BaseChannel.fspl` distance is now in **meters** end-to-end (was silently treated as km — a 60 dB error per 100 m).
  - `TRFSimulator` writes IIP3 to the IIP3 property (not OIP3); RRFSimulator class doc now reflects only the actually-wired stages.
  - Antenna upgrade (SISO → MIMO) is propagated back to `TxInfo` instead of dying inside a value-passed struct.
- **Annotation truthfulness**
  - Per-source annotation is now split into `Truth.Design`, `Truth.Execution`, and `Truth.Measured`. Design facts come from the blueprint; execution and measured facts record what the generator actually realized and observed.
  - RayTracing path loss is recorded as `AppliedPathLoss`; the analytical FSPL the planner reasoned about is recorded separately as `AnalyticalPathLoss`.
  - Link-budget noise bandwidth is now `min(rxFs, txOccupiedBW, configured)` so narrow-band signals stop carrying pessimistic SNR labels.
- **Exception contract**
  - Scenario-skip identifiers (`SkipScenario`, `NoBuildingData`, `NoValidPaths`) are classified by a single helper (`csrd.utils.scenario.isScenarioSkipException`) and propagate cleanly all the way up to `SimulationRunner.runScenario`, instead of being smothered by `ChannelFactory.stepImpl`.
- **Testing**
  - 11 unit suites (52 cases) and 7 regression scripts now run green via `run_all_tests('unit'|'regression'|'all')`. `'all'` finally sweeps all three categories instead of aliasing to `'regression'`.
- **Development discipline**
  - Five Cursor rule files at `.cursor/rules/csrd-{physics,architecture,matlab,testing,workflow}.mdc` codify the conventions enforced during the audit.

---

## 🌟 What's New in 2025

### 🔄 Revolutionary Frequency Translation System
- **Complex Exponential Translation**: Replaced traditional DUC with efficient complex exponential multiplication
- **Receiver-Centric Design**: Frequency allocation based on receiver observable range [-Fs/2, +Fs/2]
- **Negative Frequency Support**: Full spectrum utilization including negative frequency offsets
- **AI/ML Optimized**: Clean time-frequency representations without mirror interference

### 🏗️ Modular Architecture
- **Scenario-First Approach**: Scenarios generate specific Tx/Rx instances with parameters
- **Factory Pattern**: Unified configuration system with dedicated factory classes
- **Modular Configuration**: Inheritance-based configuration with base components (22KB total)
- **Comprehensive Testing**: Advanced MATLAB unit testing framework with parameterized tests

## 📁 Project Structure

```
ChangShuoRadioData/
├── +csrd/                                        # Core CSRD package
│   ├── SimulationRunner.m                       # Top-level multi-worker orchestrator
│   ├── +core/                                   # Core simulation engine
│   │   └── @ChangShuo/                         # Central per-scenario engine (class folder)
│   │       └── private/                         # Per-frame helpers
│   │           ├── generateSingleFrame.m
│   │           ├── processSingleTransmitter.m
│   │           ├── processSingleSegment.m
│   │           ├── processTransmitImpairments.m
│   │           ├── processChannelPropagation.m
│   │           ├── processReceiverProcessing.m  # Truth.Design/Execution/Measured annotation builder
│   │           └── updateTransmitterAntennaConfig.m
│   ├── +factories/                              # Factory pattern (executors of the plan)
│   │   ├── ScenarioFactory.m                   # Scenario instantiation
│   │   ├── ModulationFactory.m                 # 22 modulation types
│   │   ├── MessageFactory.m                    # Message generation (Seed/SeedValue alias)
│   │   ├── TransmitFactory.m                   # Tx front-end
│   │   ├── ChannelFactory.m                    # Channel orchestration + link budget
│   │   └── ReceiveFactory.m                    # Rx front-end
│   ├── +blocks/                                 # Simulation building blocks
│   │   ├── +scenario/                          # Planners (no execution side effects)
│   │   │   ├── @PhysicalEnvironmentSimulator/  # Map / entities / mobility / weather
│   │   │   └── @CommunicationBehaviorSimulator/# Tx-Rx links, freq plan, time pattern
│   │   └── +physical/                          # Physical layer (executors)
│   │       ├── +txRadioFront/TRFSimulator.m    # Complex-exp frequency translation, IIP3, IQI, PN
│   │       ├── +rxRadioFront/RRFSimulator.m    # LNA → ThermalNoise → IQImbalance → SampleShifter
│   │       ├── +modulate/+digital/             # 16 digital modulators
│   │       ├── +modulate/+analog/              # 6 analog modulators
│   │       ├── +channel/                       # BaseChannel, AWGN, MIMO, RayTracing
│   │       └── +message/                       # RandomBit (Seed-driven), Audio
│   ├── +test_support/                          # Test-only stubs (kept out of production)
│   │   └── ThrowingChannelBlock.m              # Channel block that injects errors for tests
│   └── +utils/                                  # Utility packages
│       ├── config_loader.m
│       ├── +logger/                            # Centralised logging
│       ├── +scenario/
│       │   ├── isScenarioSkipException.m       # Single source of truth for skip-tokens
│       │   └── checkTransmissionInterval.m
│       ├── +linkbudget/
│       │   └── resolveNoiseBandwidth.m         # min(rxFs, txOccupiedBW, configured)
│       ├── +core/
│       │   └── applyAntennaConfigFromSegments.m# SISO→MIMO writeback helper
│       └── +sysinfo/
├── config/                                      # Modular configuration system
│   ├── _base_/                                 # Base configs (factories/runners/logging)
│   ├── csrd2025/csrd2025.m                     # Example end-to-end config
│   └── README.md
├── tests/                                       # Comprehensive test suite
│   ├── run_all_tests.m                         # 'unit' | 'regression' | 'integration' | 'all'
│   ├── unit/                                   # matlab.unittest classes (52 cases)
│   │   ├── AWGNChannelTest.m
│   │   ├── BaseChannelDistanceTest.m
│   │   ├── CalculateTransmissionStateTest.m
│   │   ├── ChannelExceptionPropagationTest.m
│   │   ├── LinkBudgetNoiseBWTest.m
│   │   ├── MessageFactorySeedAliasTest.m
│   │   ├── RandomBitSeedTest.m
│   │   ├── RRFSimulatorTest.m
│   │   ├── SegmentIdContractTest.m
│   │   ├── TRFSimulatorTest.m
│   │   └── UpdateAntennaConfigTest.m
│   ├── regression/                             # End-to-end functions (test_*.m)
│   │   ├── test_bandwidth_consistency.m
│   │   ├── test_channel_exception_propagation.m
│   │   ├── test_empty_osm_raytracing.m         # OSM-with-no-buildings skip path
│   │   ├── test_entity_snapshot_consistency.m
│   │   ├── test_map_config_validation.m
│   │   ├── test_osm_building_raytracing.m
│   │   └── test_refactoring.m                  # 18 sub-cases over 5 multi-Tx scenarios
│   └── integration/                            # (placeholder; populated as needed)
├── docs/                                        # Documentation (Refactoring / Weather / etc.)
├── examples/                                    # Usage examples
├── tools/                                       # Simulation entry & helpers
│   ├── simulation.m
│   ├── multi_simulation.bat / .sh
│   ├── download_osm.py
│   └── convert_csrd_to_coco.m
├── .cursor/rules/                              # Cursor AI development rules (tracked in git)
│   ├── csrd-physics.mdc
│   ├── csrd-architecture.mdc
│   ├── csrd-matlab.mdc
│   ├── csrd-testing.mdc
│   └── csrd-workflow.mdc
└── AGENTS.md                                    # Human-readable contributor rules (mirror of mdc)
```

## ✨ Key Features

### 🔄 Advanced Frequency Translation
- **Complex Exponential Method**: `y = x .* exp(1j * 2 * π * fc * t)`
- **No Interpolation Overhead**: Direct frequency shift without DUC interpolation
- **Flexible Sample Rates**: Resample only when needed to target rate
- **Full Spectrum Access**: Support for negative frequency allocations

### ⚙️ Modular Configuration System
- **Inheritance-Based**: Base configurations with component inheritance
- **Factory Coverage**: Complete factory configurations for all 6 components
- **Size Efficient**: Modular config (5.7KB) with 22KB of reusable base components
- **Easy Customization**: Override specific parameters while inheriting base settings

### 📊 Comprehensive Modulation Support

#### 🔢 Digital Modulation (16 Types)
- **Phase Shift Keying**: PSK, OQPSK
- **Amplitude Modulation**: ASK, OOK, QAM, Mill88QAM
- **Frequency Modulation**: CPFSK, GFSK, GMSK, MSK, FSK
- **Advanced Schemes**: APSK, DVBSAPSK
- **Multi-Carrier**: OFDM, OTFS, SC-FDMA

#### 📻 Analog Modulation (6 Types)
- **Amplitude Modulation**: DSBAM, DSBSCAM, SSBAM, VSBAM
- **Angle Modulation**: FM, PM

**Total**: 22 modulation schemes (16 digital + 6 analog)

### 🎯 Receiver-Centric Design
- **Observable Range**: All transmitters allocated within [-Fs/2, +Fs/2]
- **Dynamic Allocation**: Frequency ranges automatically adapt to receiver sample rate
- **Collision Detection**: Support for overlapping and non-overlapping strategies
- **Spectrum Efficiency**: Optimal utilization including negative frequencies

### 🧪 Professional Testing Framework
- **MATLAB unittest**: Proper test class inheritance and fixtures
- **Parameterized Tests**: Test multiple scenarios with TestParameter properties
- **Coverage Analysis**: Code coverage reporting and CI/CD integration
- **Advanced Runner**: Parallel execution, multiple output formats

## 🚀 Quick Start

### 1. Basic Usage
```matlab
% Default simulation (uses csrd2025/csrd2025.m)
addpath('tools');
simulation();

% Custom configuration
simulation(1, 1, 'csrd2025/my_custom_config.m');

% Multi-worker simulation
simulation(2, 4, 'csrd2025/csrd2025.m'); % Worker 2 of 4

% Direct configuration loading
masterConfig = csrd.utils.config_loader('csrd2025/csrd2025.m');
runner = csrd.SimulationRunner('RunnerConfig', masterConfig.Runner);
runner.FactoryConfigs = masterConfig.Factories;
runner(1, 1);
```

### 2. Advanced Frequency System Example
```matlab
% See complete example in examples/use_new_frequency_system.m
use_new_frequency_system();
```

### 3. Run Test Suite
```matlab
cd tests
results = run_all_tests();                       % regression suite (default)
results = run_all_tests('unit');                 % matlab.unittest classes only
results = run_all_tests('regression');           % top-level test_*.m only
results = run_all_tests('all');                  % regression + unit + integration
results = run_all_tests('all', 'verbose', true); % include extended error reports
```

> The selector `'all'` previously aliased to `'regression'`, which silently hid every unit and integration suite. After the audit pass it really sweeps all three categories. See `tests/run_all_tests.m`.

## ⚙️ System Requirements

### 🔧 Software Requirements
- **MATLAB**: R2019b or later (for unittest framework)
- **Required Toolboxes**:
  - Communications Toolbox
  - Signal Processing Toolbox
  - DSP System Toolbox
- **Optional Toolboxes**:
  - Parallel Computing Toolbox (for parallel testing)
  - RF Toolbox (for advanced RF modeling)

### 💻 Hardware Requirements
- **Memory**: Minimum 16GB RAM (64GB recommended for large datasets)
- **Storage**: Minimum 1TB free space
- **Processor**: Multi-core processor recommended
- **GPU**: Optional, for acceleration

## 🔧 Modular Configuration System

The CSRD framework features a comprehensive modular configuration system with inheritance and component separation.

### Configuration Architecture
```matlab
% Load complete configuration with inheritance
masterConfig = csrd.utils.config_loader('csrd2025/csrd2025.m');

% Configuration structure:
masterConfig = {
  Runner: {                    % Simulation execution parameters
    NumScenarios: 4,          % Number of scenarios to execute
    FixedFrameLength: 1024,   % Consistent frame size
    RandomSeed: 'shuffle',    % Reproducibility control
    Data: {                   % Data storage configuration
      OutputDirectory: 'CSRD2025',
      SaveFormat: 'mat',
      CompressData: true
    },
    Engine: {                 % ChangShuo engine configuration
      Handle: 'csrd.core.ChangShuo',
      ResetBetweenScenarios: true
    }
  },
  
  Log: {                       % Independent logging configuration
    Level: 'INFO',            % Log level control
    SaveToFile: true,         % File logging
    DisplayInConsole: true    % Console output
  },
  
  Factories: {                 % Factory configurations for all components
    Scenario: {               % Dual-component scenario factory
      Global: {               % Global scenario parameters
        SampleRate: 1e6,      % Base sample rate
        NumFramesPerScenario: 5,  % Frames per scenario
        FrequencyBand: [900e6, 2.4e9]  % Operating frequency range
      },
      PhysicalEnvironment: {...},    % Physical world modeling
      CommunicationBehavior: {...}   % Communication behavior modeling
    },
    Modulation: {             % 22 modulation schemes
      Types: ['PSK', 'QAM', 'OFDM', 'OTFS', ...],
      digital: {...},         % Digital modulation configs
      analog: {...}           % Analog modulation configs
    },
    Message: {...},           % Message generation (RandomBit, Audio)
    Transmit: {...},          % RF front-end impairment models
    Channel: {...},           % Channel propagation models
    Receive: {...}            % Receiver front-end models
  },
  
  Metadata: {                  % Configuration metadata
    Version: '2025.1.0',
    Architecture: 'Scenario-Driven',
    Description: 'CSRD Framework Master Configuration'
  }
}
```

### Configuration Inheritance
```matlab
% Example: Create custom configuration
function config = my_custom_config()
    % Inherit from base configurations
    config.baseConfigs = {
        '_base_/logging/default.m',
        '_base_/runners/default.m',
        '_base_/factories/scenario_factory.m',
        '_base_/factories/message_factory.m',
        '_base_/factories/modulation_factory.m',
        '_base_/factories/transmit_factory.m',
        '_base_/factories/channel_factory.m',
        '_base_/factories/receive_factory.m'
    };
    
    % Override specific parameters
    config.Runner.NumScenarios = 10;
    config.Log.Level = 'DEBUG';
    config.Factories.Scenario.Global.NumFramesPerScenario = 20;
end
```

### Configuration Components

**Base Configurations (`_base_/`):**
- **Logging**: `default.m`, `debug.m` - Logging system configurations
- **Runners**: `default.m`, `high_performance.m` - Simulation execution settings  
- **Factories**: Complete factory configurations for all CSRD components
  - `scenario_factory.m` - Dual-component scenario factory (3.4KB)
  - `message_factory.m` - Message generation factory (1.2KB)
  - `modulation_factory.m` - 22 modulation schemes (6.3KB)
  - `transmit_factory.m` - RF front-end impairment models (4.2KB)
  - `channel_factory.m` - Channel propagation models (3.4KB)
  - `receive_factory.m` - Receiver front-end models (4.1KB)

**Usage Examples:**
```matlab
% Load default configuration
config = csrd.utils.config_loader();

% Load specific configuration  
config = csrd.utils.config_loader('csrd2025/csrd2025.m');

% Use in simulation (with tools/ added to path)
addpath('tools');
simulation(1, 1, 'csrd2025/csrd2025.m');
```

## 🎯 Technical Highlights

### Complex Exponential Frequency Translation

```
% Traditional DUC approach (removed)
% y = dsp.DigitalUpConverter(...)

% New complex exponential approach
t = (0:length(x)-1)' / sampleRate;
freqShift = exp(1j * 2 * pi * targetFreq * t);
y = x .* freqShift;
```

### Advantages:
- ✅ **No Mirror Signals**: Eliminates negative frequency waste
- ✅ **Computational Efficiency**: Direct multiplication vs. interpolation
- ✅ **AI/ML Friendly**: Clean spectrograms without mirror interference  
- ✅ **Flexible Allocation**: Support for negative frequency offsets
- ✅ **Receiver-Centric**: Automatic range adaptation

## 📖 Documentation

- **[Modular Configuration System](config/README.md)**: Complete configuration system guide
- **[Refactoring Notes](docs/README_Refactoring.md)** and **[Communication Behavior Notes](docs/README_CommunicationBehavior.md)**: Design notes for the in-flight refactor
- **[Test Suite Guide](tests/README.md)**: Test layout and conventions
- **[Usage Examples](examples/)**: Practical implementation examples
- **[Contributor / AI rules (`AGENTS.md`)](AGENTS.md)**: Human-readable mirror of `.cursor/rules/*.mdc`
- **[TWC Dataset Simulation](twc/README.md)**: Dataset generator for the TWC paper ([IEEE Xplore](https://ieeexplore.ieee.org/abstract/document/10667001)). Note: `twc/` is **outside** the current refactoring scope.

## 🧷 Development Standards (refactor-era contract)

This refactor enforces a small set of non-negotiable conventions. They are codified in
`.cursor/rules/csrd-{physics,architecture,matlab,testing,workflow}.mdc` (auto-loaded by
Cursor) and mirrored in `AGENTS.md` for non-Cursor contributors. Headlines:

- **Units are explicit and never silently converted**: distance is meters, frequency is Hz, power is dBm. Helpers that need other units (`fogpl` km, etc.) must be wrapped with a clearly named adapter.
- **Planning vs execution stays separated**: scenario blocks plan; factories execute. Factories must NOT inject random parameters at execution time to fill in missing plan fields — that is a planner bug.
- **Annotations cannot fabricate design facts from execution facts**: `Truth.Design` comes from the blueprint, while `Truth.Execution` and `Truth.Measured` record realized and observed generator facts.
- **`SampleRate` always comes from the producer**: missing or non-positive `SampleRate` raises `CSRD:Core:MissingSampleRate`. No `length(Signal)/Duration` reverse derivation, no hard-coded `200e3` fallbacks.
- **Scenario-skip exceptions propagate**: any `try/catch` that may need to distinguish "skip this scenario, keep going" from "abort the run" must consult `csrd.utils.scenario.isScenarioSkipException` and rethrow on match.
- **Every fix ships with a test**: a fix without a test that would have caught the bug does not land. Tests live only under `tests/{unit,regression,integration}/` — never in the repo root or `examples/`.

## 🧪 Testing and Validation

### Test Categories
- **Unit Tests**: Individual component validation
- **Integration Tests**: End-to-end system verification
- **Performance Tests**: Efficiency and spectrum utilization analysis

### Test Execution
```matlab
% Quick smoke check of the test infrastructure (no production code path)
cd tests
quick_test_example()

% Full test suite (unit + regression + integration), verbose error reports
results = run_all_tests('all', 'verbose', true);

% Specific test categories
results = run_all_tests('unit');         % matlab.unittest classes (52 cases)
results = run_all_tests('regression');   % end-to-end test_*.m functions
results = run_all_tests('integration');  % cross-block integration suites
```

> The legacy `'outputFormat'` parameter (JUnit XML, etc.) has been removed during the audit pass. If you need machine-readable output for CI, wrap `runtests` directly with `XMLPlugin` from `matlab.unittest.plugins`. We can add this back as a flag if there is demand.

## 📊 Performance & Efficiency

### Spectrum Utilization
- **Traditional**: ~50% efficiency (positive frequencies only)
- **CSRD 2025**: ~90%+ efficiency (full spectrum including negative frequencies)

### Computational Performance
- **Complex Exponential**: 3-5x faster than DUC interpolation
- **Memory Efficiency**: Reduced intermediate buffer requirements
- **Parallel Support**: Multi-worker simulation execution

## 🛠️ Development Tools

### Configuration Management
- **Modular Design**: Inheritance-based configuration with base components
- **Single Interface**: Unified `csrd.utils.config_loader()` function
- **Complete Coverage**: All 6 factory configurations (Scenario, Message, Modulation, Transmit, Channel, Receive)
- **Easy Customization**: Override specific parameters while inheriting base configurations

### Code Standards
- **MATLAB Style**: Official MATLAB coding standards compliance
- **Function Documentation**: Complete header comments with examples
- **Variable Naming**: Clear, descriptive, and consistent naming
- **English Only**: All comments and documentation in English

### Continuous Integration
- **Automated Testing**: `tests/run_all_tests.m` returns a structured `results` struct (`Success`, `TotalTests`, `Passed`, `Failed`, `Records`) suitable for shell-driven CI gating. JUnit-style XML output is intentionally not bundled today; if you need it, add `matlab.unittest.plugins.XMLPlugin` around `runtests` in your wrapper.
- **Performance Monitoring**: per-suite and per-case wall-clock duration is captured in `results.Records.DurationSeconds`.

## 🔗 Related Projects

- **[ChangShuoRadioRecognition](https://github.com/Singingkettle/ChangShuoRadioRecognition)**: Deep learning for radio signal classification
- **Research Paper**: ["Joint Signal Detection and Automatic Modulation Classification via Deep Learning"](https://arxiv.org/abs/2405.00736)

## 📄 License

This project is licensed under the terms specified in the [LICENSE](LICENSE) file.

## 🙏 Acknowledgments

- Advanced frequency translation system designed for modern AI/ML applications
- Comprehensive modulation library supporting 22 different schemes
- Professional MATLAB development practices and testing frameworks
- Optimized for time-frequency analysis and CNN feature extraction

## 📝 Citation

If you use CSRD in your research, please cite:

```
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
  keywords={Feature extraction;Signal detection;Frequency modulation;Time-frequency analysis;Signal to noise ratio;Industries;Deep learning;Automatic modulation classification;dataset design;hierarchical classification head},
  doi={10.1109/TWC.2024.3450972}}
```

All rights of interpretation for this project belong to Citybuster Studio.

## Key Advantages

1. **Modular Design**: Clean separation of concerns with base configurations
2. **Simplified Interface**: Single `config_loader()` function handles all loading needs
3. **Inheritance System**: Reuse and extend configurations efficiently
4. **Clear Examples**: `csrd2025` provides a complete working example
5. **Easy Maintenance**: Modular organization makes configs easier to understand and modify
6. **Full CSRD Support**: Complete coverage of all framework components and factories

## 🏗️ Architecture Simplification

The CSRD framework has been simplified by removing legacy compatibility code:

- **Single Configuration System**: Only modular configuration system is supported
- **Modern API**: Clean, consistent interfaces without legacy workarounds
- **Reduced Complexity**: No compatibility layers or format conversions
- **Better Performance**: Direct data flow without legacy format translations
- **Easier Maintenance**: Single codebase path, no dual-system support

This architectural simplification makes the framework:
- **Faster**: No legacy format conversions
- **Cleaner**: No compatibility workarounds
- **Simpler**: Single code path for all operations
- **More Maintainable**: Consistent modern architecture throughout
