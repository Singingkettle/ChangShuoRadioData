# 📡 ChangShuo Radio Data (CSRD)

A comprehensive MATLAB-based radio communication simulation framework for wireless communication system simulation and analysis. 

## 🔍 Project Structure

```
csrd/
├── +blocks/             # Core simulation blocks
│   ├── +event/         # Event-based components
│   │   └── +communication/ # Wireless communication event handling
│   ├── +physical/      # Physical layer implementations
│   │   ├── +environment/ # Channel and propagation models
│   │   ├── +message/   # Message and waveform generation
│   │   ├── +modulate/  # Modulation and demodulation schemes
│   │   ├── +txRadioFront/ # Transmitter radio front-end components
│   │   └── +rxRadioFront/ # Receiver radio front-end components
│   └── +link/          # Link-level simulation components
├── +collection/        # Data collection and management utilities
├── utils/             # General utility functions
└── input/             # Input data, configurations, and map files
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
- MATLAB R2024b or later
- Required Toolboxes:
  - Communications Toolbox
  - Signal Processing Toolbox
  - DSP System Toolbox
  - RF Toolbox
  - Antenna Toolbox (for MIMO features)

### 🖥️ Hardware Requirements
- Minimum 64GB RAM (128GB recommended)
- Minimum 20TB of free disk space (for 1000000 Frames)
- Multi-core processor
- GPU support (optional, for acceleration)

## 📦 Dataset Simulation

This section outlines the basic workflow for generating a dataset using the CSRD framework.

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/yourusername/csrd.git 
    cd csrd 
    ```

2.  **Download OSM Files (for Ray Tracing):**
    If you plan to use ray tracing for channel modeling, download the OpenStreetMap data. This script requires Python and the `requests` library.

    *   **Setup Python Environment (Recommended):**
        It's recommended to use a Python virtual environment to manage dependencies.
        ```bash
        # Example: Create and activate a virtual environment
        python -m venv .venv
        # On Windows: .venv\Scripts\activate
        # On Linux/macOS: source .venv/bin/activate
        
        pip install requests
        ```

    *   **Run the script:**
        ```bash
        cd tools
        python download_osm.py
        cd .. 
        ```
    This will save `.osm` files into the `appdata/map/osm` directory.

3.  **Configure Simulation Parameters:**
    Simulation scenarios, signal parameters, channel models, and other settings are typically defined in configuration files located within the `config/` directory. You may need to modify or create new configuration files in `config/` (potentially using files from `config/_base_/` as templates) to define your desired dataset parameters before running a simulation.

4.  **Run the Simulation:**

    *   **Single Simulation (Serial Execution):**
        For a basic simulation run or for debugging, you can execute the main simulation script directly in MATLAB:
        ```matlab
        % Navigate to the 'tools' directory in MATLAB
        cd tools;
        
        % Run the simulation (example: worker 1 of 1)
        % Ensure your simulation parameters are set in the appropriate config files.
        simulation(1, 1); 
        ```

    *   **Parallel Simulation (Multiple Workers):**
        For generating larger datasets, parallel execution is recommended. Use the provided scripts based on your operating system. These scripts will launch multiple MATLAB instances.

        *   **Windows:**
            Open a command prompt, navigate to the `tools` directory, and run:
            ```batch
            cd tools
            multi_simulation.bat
            ```
            You will be prompted to enter the number of workers.

        *   **Linux / macOS:**
            Open a terminal, navigate to the `tools` directory, and run:
            ```bash
            cd tools
            chmod +x multi_simulation.sh # Ensure the script is executable
            ./multi_simulation.sh
            ```
            You will be prompted to enter the number of workers.

        Logs for parallel simulations can be found in the `tools/logs` directory.

5.  **Convert Data to COCO Format:**
    After the simulation generates the raw signal data, you will typically need to process this data and convert it into the COCO (Common Objects in Context) dataset format. This format is widely used for object detection tasks, which in this context applies to signal localization and recognition.
    *(Further details or specific scripts for this conversion step should be added here if available.)*

## 🛠️ Tools

### OpenStreetMap (OSM) Data Downloader (`tools/download_osm.py`)

This Python script is provided to download OpenStreetMap data required for raytracing simulations. It queries the Overpass API for specific geographical scenes defined within the script and saves the results as `.osm` files.

**Dependencies:**

*   Python 3.x (It is highly recommended to use a virtual environment).
*   `requests` library. Install using pip: `pip install requests`.

**Usage:**

1.  Ensure you have Python and the `requests` library installed.
2.  Navigate to the `tools` directory in your terminal:
    ```bash
    cd tools
    ```
3.  Run the script:
    ```bash
    python download_osm.py
    ```
4.  The script will download OSM data for predefined scenes (e.g., Dense Urban, Historical City Center) and save them into categorized subdirectories within `appdata/map/osm`.

**Note:** The script includes predefined scene coordinates and categories. You can modify the `scenes` dictionary within `download_osm.py` to download data for different locations or adjust the `BOX_SIZE_KM` and other parameters as needed. Please be mindful of the Overpass API usage policy and the delay implemented in the script to avoid overloading the server.

## ⚡ Performance Optimization

### 🔧 Memory Management
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