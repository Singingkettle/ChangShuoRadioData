## TWC Dataset Simulation

This folder contains the MATLAB simulation code used to generate the dataset
for the IEEE Transactions on Wireless Communications paper:
https://ieeexplore.ieee.org/abstract/document/10667001

### Entry Point
- `generate.m` is the main script.

### Usage
```matlab
cd('twc');
generate;
```

### Dataset Check
```matlab
cd('twc');
report = dataset_tools('check');
```

You can also pass a custom root:
```matlab
report = dataset_tools('check', 'D:\path\to\data\ChangShuo');
```

### Quick Visual Check
```matlab
cd('twc');
dataset_tools('visual'); % time/spectrum/constellation for one item
```

### Dataset Statistics
```matlab
cd('twc');
stats = dataset_tools('stats'); % distributions of SNR/modulation/channel
```

### Output
The script writes data under:
`./data/ChangShuo/v{version}/`

- `anno/*.json`: per-signal metadata (center frequency, bandwidth, SNR, etc.)
- `sequence_data/iq/*.mat`: IQ samples

Each IQ `.mat` file contains:
- `signal_data`: `[numSignals x 2 x numSamples]` complex IQ for each sub-signal
- `wideband_data` (when present): `[1 x 2 x numSamples]` wideband composite
  signal with noise added once at the wideband level

### Notes
- Noise is added once at the wideband level to avoid repeated noise stacking
  when multiple sub-signals are combined.
- If you need the true wideband receive signal, use `wideband_data` directly
  instead of summing `signal_data`.
