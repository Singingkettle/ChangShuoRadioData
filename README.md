# 📡 ChangShuo Radio Data (CSRD)

A comprehensive MATLAB-based radio communication simulation framework for wireless communication system simulation and analysis. 

## 🔍 Project Structure

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

## 🚀 What's New

V1.0.0 was released in 26/03/2025, please open `tools/simulation.m` to see the basic usage. 

## 📜 History

V0.0.0 was released in 23/01/2024, which was located in history/DataSimulationTool. you can run generate.m to simulate wireless data, and can use [ChangShuoRadioRecognition](https://github.com/Singingkettle/ChangShuoRadioRecognition) to do a joint DL model for radio detection and modulation classification. This dataset is used in the TWC paper["Joint Signal Detection and Automatic Modulation Classification via Deep Learning"](https://arxiv.org/abs/2405.00736)


## ✨ Features

### 📊 Physical Layer Components

#### 📲 Modulation Schemes
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
  
#### 📡 Channel Models
- SISO/MIMO Channel Support
- RayTracing (coming soon)

#### 🔌 Radio Front-end Simulation
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

### ⏱️ Event-based Components
- Wireless Communication Event Handling
- Signal Tiling and Scheduling
- Time-Frequency Resource Management

## 💻 System Requirements

### 🔧 Software Requirements
- MATLAB R2021a or later
- Required Toolboxes:
  - Communications Toolbox
  - Signal Processing Toolbox
  - DSP System Toolbox
  - RF Toolbox
  - Antenna Toolbox (for MIMO features)

### 🖥️ Hardware Requirements
- Minimum 8GB RAM (16GB recommended)
- Multi-core processor
- GPU support (optional, for acceleration)

## 📥 Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/csrd.git
```

2. Add to MATLAB path:
```matlab
cd tools;
simulation(1, 1);
```

## ⚡ Performance Optimization

### 🧠 Memory Management
- Use preallocated arrays
- Process large signals in chunks
- Clear temporary variables

## 🔍 Troubleshooting

Common issues and solutions:
1. 🚫 Memory errors
   - Reduce signal length
   - Use chunked processing
   - Clear unused variables

2. ⏱️ Performance issues
   - Optimize array operations
   - Use parallel processing

## 📚 References
- USRP Hardware Driver (UHD)
- DVB-S2 Standards
- IEEE 802.11 Specifications
- Matlab Official Docs

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## 📞 Contact

- Project Lead: Shuo Chang
- Technical Support: changshuo@bupt.edu.cn

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