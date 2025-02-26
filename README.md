# ChangShuoRadioData (CSRD)

## Overview

ChangShuoRadioData is a comprehensive MATLAB-based framework for simulating, generating, and processing wireless communication signals. It supports a wide variety of modulation schemes, signal processing techniques, and radio frequency (RF) behaviors, enabling realistic simulation of complex wireless communication systems.


## Features

- Multiple modulation schemes support (analog and digital)
- MIMO capability
- Frequency and time domain signal tiling
- Configurable signal overlap
- Phase noise simulation
- Channel modeling
- RF front-end simulation
- Ray tracing capabilities

## System Requirements

- MATLAB R2020b or newer
- Required MATLAB Toolboxes:
  - Communications Toolbox
  - Signal Processing Toolbox
  - DSP System Toolbox
  - RF Toolbox
  - Antenna Toolbox (for MIMO features)
- Minimum 8GB RAM (16GB recommended for complex simulations)
- GPU support (optional, for acceleration)

## Installation

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/ChangShuoRadioData.git
   ```

2. Add the project to your MATLAB path:
   ```matlab
   addpath(genpath('/path/to/ChangShuoRadioData'));
   ```

3. Verify installation by running the demo:
   ```matlab
   cd /path/to/ChangShuoRadioData/tutorial
   demo
   ```

## Project Structure

```
ChangShuoRadioData/
├── csrd/                    # Core library code
│   ├── +blocks/             # Signal processing blocks
│   │   ├── +event/          # Event-based components
│   │   ├── +physical/       # Physical layer components
│   │   └── ...
│   ├── +collection/         # Collection of runners and processors
│   ├── utils/               # Utility functions
│   └── input/               # Input data handlers
├── config/                  # Configuration files
│   └── _base_/              # Base configurations
└── tutorial/                # Tutorial and example files
    ├── demo.m               # Main demonstration file
    ├── test_am.m            # Amplitude modulation example
    ├── test_fm.m            # Frequency modulation example
    ├── test_ofdm.m          # OFDM modulation example
    └── ...                  # Other modulation and feature examples
```

## Usage Guide

### Basic Usage

1. Start by exploring the tutorial examples:

```matlab
% Run the general demo
demo

% Test specific modulation types
test_am        % Amplitude modulation
test_fm        % Frequency modulation
test_ofdm      % OFDM modulation
test_qam       % QAM modulation
```

2. Create a custom simulation:

```matlab
% Basic simulation setup example
% 1. Initialize a modulator
qamMod = csrd.blocks.physical.modulate.QAMModulator(...
    'ModulatorOrder', 16, ...
    'SampleRate', 1e6, ...
    'NumTransmitAntennas', 1);

% 2. Create input data
inputData = struct('data', randi([0 1], 10000, 1));

% 3. Modulate the data
modulatedSignal = qamMod.step(inputData);

% 4. Configure frequency tiling for multiple signals
tiling = csrd.blocks.event.communication.wireless.Tiling(...
    'IsOverlap', true, ...
    'OverlapRadio', 0.2);

% 5. Apply tiling to signals
signalSets = {{modulatedSignal}};  % Single transmitter example
[positionedSignals, txInfo, clockRate, bandWidth] = tiling.step(signalSets);

% 6. Visualize the results
% ... (visualization code would go here)
```

### Advanced Usage

For more complex simulations, explore the test files in the tutorial directory. These demonstrate:
- Multi-antenna (MIMO) configurations
- Channel modeling
- Phase noise effects
- Ray tracing
- Hardware impairments

## Key Components

### Modulation Schemes

The framework supports numerous modulation types including:
- Analog: AM, FM, PM
- Digital: ASK, FSK, PSK, QAM, APSK, DVBS-APSK
- Advanced: OFDM, SC-FDMA, OTFS, CPM, GMSK, GFSK, MSK

### Signal Processing Blocks

- **Tiling Module**: Arranges signals in frequency/time domains
- **BaseModulator**: Foundation class for all modulation schemes
- **DigitalUpConverter/DigitalDownConverter**: Frequency conversion
- **PhaseNoise**: Simulates oscillator phase noise
- **RayTrace**: Models signal propagation

### Simulation Framework

The collection module provides runner classes to execute complete simulations with:
- Configurable scenarios
- Progress tracking
- Result collection
- Performance measurement

## Potential Vulnerabilities

1. **Memory Management Issues**:
   - Large signal arrays may cause out-of-memory errors
   - No explicit memory usage monitoring

2. **Computational Performance**:
   - Inefficient implementations for large-scale simulations
   - Limited GPU acceleration support
   - Potential bottlenecks in multi-antenna configurations

3. **Input Validation**:
   - Insufficient validation of user inputs
   - Potential for unexpected behavior with malformed inputs

4. **Error Handling**:
   - Limited robust error handling mechanisms
   - Some edge cases may not be properly handled

5. **Compatibility Issues**:
   - Some functions may depend on specific MATLAB versions
   - Potential compatibility issues between different components

6. **Signal Processing Limitations**:
   - Frequency tiling algorithm may produce suboptimal results in dense signal environments
   - Phase noise modeling may not accurately reflect real-world hardware
   - Random number generation dependencies may lead to reproducibility issues

7. **Documentation Gaps**:
   - Incomplete documentation for some advanced features
   - Limited guidance for extending the framework

## Troubleshooting

### Common Issues

1. **"Index exceeds matrix dimensions" error**:
   - Ensure signal arrays are correctly formatted
   - Check for empty or malformed signal structures

2. **"Out of memory" errors**:
   - Reduce simulation size or complexity
   - Process signals in smaller batches

3. **GPU acceleration issues**:
   - Verify GPU availability with `gpuDeviceCount > 0`
   - Ensure compatible CUDA/GPU drivers
   - Implement fallback to CPU processing

### Performance Optimization

1. **Reduce sample rates** where possible
2. **Pre-allocate arrays** for large signal processing
3. **Use smaller frame sizes** for complex modulations
4. **Optimize visualization** settings for large datasets

## Contributing

Contributions to ChangShuoRadioData are welcome! To contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure your code follows the project's style guidelines and includes appropriate tests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- MATLAB and MathWorks for the underlying platform and toolboxes
- The wireless communications research community
- Contributors to the ChangShuoRadioData project

---

For more information, bug reports, or feature requests, please contact the project maintainers.
