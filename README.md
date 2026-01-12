![Citybuster Studio Logo](assets/logo.svg)

# 📡 ChangShuo Radio Data (CSRD)

A comprehensive MATLAB-based radio communication simulation framework for wireless communication system simulation and analysis. 

---

## ⚠️ **IMPORTANT NOTICE / 重要提示**

### 🔄 **Code Refactoring in Progress / 代码重构进行中**

**English:**
> ⚠️ **The codebase is currently undergoing extensive refactoring.** The refactoring is driven by two main reasons:
> 
> 1. **Ray Tracing Stability Issues**: The original implementation has problems that cause instability in ray tracing, especially when OSM files do not contain buildings, which leads to exceptions. While patches can be applied, the author believes this is not a good approach and will address this properly during the refactoring.
> 
> 2. **Module Design Confusion**: The current module design is somewhat chaotic, and the refactored version will address this issue.
> 
> **Note**: The author is a junior faculty member (青椒) and is the sole maintainer of this project. Due to busy schedules, updates can only be made when time permits. **If you need to run the code, please refer to a previous stable version**:
> 
> **Stable Version**: [https://github.com/Singingkettle/ChangShuoRadioData/tree/a6d09a4b264894b76f852ce33bfd82adc7b270b5](https://github.com/Singingkettle/ChangShuoRadioData/tree/a6d09a4b264894b76f852ce33bfd82adc7b270b5)

**中文：**
> ⚠️ **代码库目前正在进行大规模重构。** 重构主要基于两方面的原因：
> 
> 1. **Ray Tracing 稳定性问题**：原来的实现存在一些问题，导致基于 raytracing 实现不稳定，尤其是当 OSM 文件中不存在 buildings 时候，会有异常。当然可以进行打补丁解决，但是作者认为这个方法并不好，我们会在重构中进行考虑。
> 
> 2. **模块设计混乱**：模块的设计还是有点混乱，在重构代码的版本对这块会有修改。
> 
> **说明**：本人是一名青椒，目前整个项目的维护只有一个人在维护，平时太忙了，只能抽空进行必要的更新。**大家要想运行的话可以翻看历史的版本**：
> 
> **稳定版本**：[https://github.com/Singingkettle/ChangShuoRadioData/tree/a6d09a4b264894b76f852ce33bfd82adc7b270b5](https://github.com/Singingkettle/ChangShuoRadioData/tree/a6d09a4b264894b76f852ce33bfd82adc7b270b5)

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
├── +csrd/                           # Core CSRD package
│   ├── SimulationRunner.m          # Main simulation execution engine
│   ├── +core/                      # Core simulation components
│   │   └── ChangShuo.m             # Central simulation engine
│   ├── +factories/                 # Factory pattern implementations
│   │   ├── ScenarioFactory.m       # Scenario instantiation strategies
│   │   ├── ModulationFactory.m     # 22 modulation types support
│   │   ├── MessageFactory.m        # Message generation
│   │   ├── TransmitFactory.m       # Transmitter configuration
│   │   ├── ChannelFactory.m        # Channel models
│   │   └── ReceiveFactory.m        # Receiver configuration
│   ├── +blocks/                    # Simulation building blocks
│   │   ├── +scenario/              # Scenario planning and allocation
│   │   │   └── ParameterDrivenPlanner.m  # Receiver-centric frequency planner
│   │   └── +physical/              # Physical layer implementations
│   │       ├── +txRadioFront/      # Advanced transmitter front-end
│   │       │   └── TRFSimulator.m  # Complex exponential frequency translation
│   │       ├── +rxRadioFront/      # Receiver front-end
│   │       │   └── RRFSimulator.m  # Receiver-centric processing
│   │       ├── +modulate/          # Comprehensive modulation library
│   │       │   ├── +digital/       # 16 digital modulation schemes
│   │       │   └── +analog/        # 6 analog modulation schemes
│   │       ├── +channel/           # Channel models
│   │       └── +message/           # Message generation utilities
│   └── +utils/                     # Utility functions and system tools
│       ├── config_loader.m         # Modular configuration loader
│       ├── DocumentationGenerator.m # Automated documentation generation
│       ├── +logger/                # Logging system components
│       └── +sysinfo/               # System information utilities
├── config/                         # Modular configuration system
│   ├── _base_/                     # Base configuration files
│   │   ├── factories/              # Factory configurations (scenario, modulation, etc.)
│   │   ├── runners/                # Runner configurations (default, high_performance)
│   │   └── logging/                # Logging configurations (default, debug)
│   ├── csrd2025/                   # Example configuration dataset
│   │   └── csrd2025.m              # Complete modular config example (5.7KB)
│   └── README.md                   # Configuration system documentation
├── tests/                          # Comprehensive test suite
│   ├── run_all_tests.m            # Advanced test runner
│   ├── unit/                      # Unit tests with MATLAB unittest framework
│   │   ├── TRFSimulatorTest.m     # Frequency translation system tests
│   │   └── ParameterDrivenPlannerTest.m  # Scenario planning tests
│   └── integration/               # End-to-end integration tests
│       └── FrequencyTranslationSystemTest.m  # Complete system validation
├── docs/                          # Documentation
│   └── frequency_translation_system_upgrade.md  # Technical details
├── examples/                      # Usage examples
│   └── use_new_frequency_system.m  # Complete system demonstration
└── tools/                         # Development and simulation tools
    ├── simulation.m               # Main simulation entry point (15KB)
    ├── multi_simulation.bat       # Windows batch simulation script
    ├── multi_simulation.sh        # Unix shell simulation script
    ├── download_osm.py            # OSM map data downloader
    └── convert_csrd_to_coco.m     # COCO dataset format converter
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
results = run_all_tests();                  % All tests
results = run_all_tests('unit');            % Unit tests only
results = run_all_tests('verbose', true);   % Verbose output
```

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
    Message: {...},           % Message generation (RandomBits, CustomPattern)
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
- **[Frequency Translation System Upgrade](docs/frequency_translation_system_upgrade.md)**: Complete technical details
- **[Test Suite Guide](tests/README.md)**: Comprehensive testing documentation
- **[Usage Examples](examples/)**: Practical implementation examples

## 🧪 Testing and Validation

### Test Categories
- **Unit Tests**: Individual component validation
- **Integration Tests**: End-to-end system verification
- **Performance Tests**: Efficiency and spectrum utilization analysis

### Test Execution
```matlab
% Quick validation
cd tests
quick_test_example()

% Full test suite
results = run_all_tests('all', 'verbose', true, 'outputFormat', 'junit');

% Specific test categories
results = run_all_tests('unit');        % Unit tests only
results = run_all_tests('integration'); % Integration tests only
```

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
- **Automated Testing**: JUnit XML output for CI/CD integration
- **Code Coverage**: Comprehensive coverage reporting
- **Performance Monitoring**: Execution time and memory tracking

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