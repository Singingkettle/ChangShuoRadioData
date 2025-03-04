# ChangShuo Radio Data (CSRD)

A comprehensive MATLAB-based radio communication simulation framework for wireless communication system simulation and analysis. 

## Project Structure

```
csrd/
├── +blocks/             # Core simulation blocks
│   ├── +event/         # Event-based components
│   │   └── +communication/
│   │       └── +wireless/
│   └── +physical/      # Physical layer implementations
│       ├── +environment/
│       │   └── +channel/
│       ├── +message/   # Message generation
│       ├── +modulate/  # Modulation schemes
│       └── +txRadioFront/
├── +collection/        # Data collection utilities
├── utils/             # Utility functions
└── input/             # Input data and configurations
```

## Features

### Physical Layer Components

#### Modulation Schemes
- **Analog Modulation**
  - AM: DSBAM, DSBSCAM, SSBAM, VSBAM
  - FM: Frequency Modulation
  - PM: Phase Modulation

- **Digital Modulation**
  - APSK & DVBS-APSK
  - ASK & OOK
  - CPM: CPFSK, GFSK, GMSK, MSK
  - FSK
  - OFDM
  - OTFS
  - SC-FDMA
  
#### Channel Models
- SISO/MIMO Channel Support
- RayTracing (coming soon)

#### Radio Front-end Simulation
- **Transmitter (TRFSimulator)**
  - IQ Imbalance
  - Phase Noise
  - DC Offset
  - Memory-less Nonlinearity
  - Digital Up-Conversion

- **Receiver (RRFSimulator)**
  - Thermal Noise
  - Frequency Offset
  - Sample Rate Offset
  - Automatic Gain Control

### Event-based Components
- Wireless Communication Event Handling
- Signal Tiling and Scheduling
- Time-Frequency Resource Management

## System Requirements

### Software Requirements
- MATLAB R2021a or later
- Required Toolboxes:
  - Communications Toolbox
  - Signal Processing Toolbox
  - DSP System Toolbox
  - RF Toolbox
  - Antenna Toolbox (for MIMO features)

### Hardware Requirements
- Minimum 8GB RAM (16GB recommended)
- Multi-core processor
- GPU support (optional, for acceleration)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/csrd.git
```

2. Add to MATLAB path:
```matlab
addpath(genpath('/path/to/csrd'));
```

3. Verify installation:
```matlab
cd /path/to/csrd/tutorial
test_runner
```

## Quick Start Guide

### Basic Usage Example

```matlab
% 1. Initialize modulator
ofdmMod = blocks.physical.modulate.digital.OFDM.OFDM(...
    'ModulatorOrder', 16, ...
    'NumTransmitAntennas', 2);

% 2. Generate test data
messageGen = blocks.physical.message.RandomBit();
inputData = messageGen.step(1000, 1e6);

% 3. Modulate signal
modulatedSignal = ofdmMod.step(inputData);

% 4. Configure channel
channel = blocks.physical.environment.channel.MIMO(...
    'NumTransmitAntennas', 2, ...
    'NumReceiveAntennas', 2);

% 5. Process through channel
receivedSignal = channel.step(modulatedSignal);
```

### Advanced Features

```matlab
% Multi-transmitter scenario with frequency tiling
tiling = blocks.event.communication.wireless.Tiling(...
    'IsOverlap', true, ...
    'OverlapRatio', 0.3);

% Configure multiple signals
signals = {signal1, signal2, signal3};
[tiledSignals, info] = tiling.step(signals);
```

## Development and Testing

- Development rules: See `docs/csrd-rule.mdc`
- Run tests: `runtests('csrd/tests')`
- API Reference: `docs/api_reference.md`
- Examples: `tutorial/`

## Performance Optimization

### Memory Management
- Use preallocated arrays
- Process large signals in chunks
- Clear temporary variables

## Troubleshooting

Common issues and solutions:
1. Memory errors
   - Reduce signal length
   - Use chunked processing
   - Clear unused variables

2. Performance issues
   - Enable GPU acceleration
   - Optimize array operations
   - Use parallel processing

## References
- USRP Hardware Driver (UHD)
- DVB-S2 Standards
- IEEE 802.11 Specifications
- Matlab Official Docs

## License

See LICENSE file for details.

## Contact

- Project Lead: [Shuo Chang]
- Technical Support: [changshuo@bupt.edu.cn]
  
## Citation

If you use CSRD in your research, please cite:

```
@software{csrd2024,
  title = {ChangShuo Radio Data},
  author = {Shuo Chang},
  year = {2024},
  url = {https://github.com/Singingkettle/ChangShuoRadioData}
}
```
