# CSRD Modular Configuration System

## Overview

The CSRD framework supports a modular configuration system that provides configuration inheritance, modular organization, and flexible customization capabilities.

## Quick Start

```matlab
% Load the complete modular configuration
config = csrd.utils.config_loader('csrd2025/csrd2025.m');

% Use in simulation  
simulation(1, 1, 'csrd2025/csrd2025.m');
```

## Directory Structure

```
config/
├── _base_/                           # Base configuration files
│   ├── factories/                    # Factory configurations  
│   │   ├── scenario_factory.m        # Scenario factory config (dual-component, 3.4KB)
│   │   ├── message_factory.m         # Message generation factory config (1.2KB)
│   │   ├── modulation_factory.m      # Modulation factory config (PSK, QAM, OFDM, etc., 6.3KB)
│   │   ├── transmit_factory.m        # Transmitter RF front-end factory config (4.2KB)
│   │   ├── channel_factory.m         # Channel propagation factory config (3.4KB)
│   │   └── receive_factory.m         # Receiver RF front-end factory config (4.1KB)
│   ├── runners/                      # Runner configurations
│   │   ├── default.m                 # Default runner config (2.0KB)
│   │   └── high_performance.m        # High performance config (648B)
│   └── logging/                      # Logging configurations
│       ├── default.m                 # Default logging config (762B)
│       └── debug.m                   # Debug logging config (451B)
└── csrd2025/                         # Example configuration dataset
    └── csrd2025.m                    # Complete modular config example (5.7KB)
```

## Usage

### 1. Basic Usage

```matlab
% Use default configuration  
config = csrd.utils.config_loader();

% Use specific configuration
config = csrd.utils.config_loader('csrd2025/csrd2025.m');
```

### 2. Configuration Inheritance

Configuration files support inheritance through the `baseConfigs` field:

```matlab
function config = my_config()
    % Inherit from multiple base configurations
    config.baseConfigs = {
        '_base_/logging/default.m',
        '_base_/runners/default.m', 
        '_base_/factories/scenario_factory.m'
    };
    
    % Override specific fields
    config.Runner.NumScenarios = 100;
    config.Log.Level = 'DEBUG';
    
    % Add custom metadata
    config.Metadata.CustomNote = 'custom_value';
end
```

### 3. Creating Custom Configurations

#### Creating Complete Configuration

```matlab
function config = my_configuration()
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
    
    % Custom parameters for specific components
    config.Factories.Scenario.Global.NumFramesPerScenario = 20;
    config.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = 6;
    config.Factories.Modulation.SymbolRate.Max = 500e3; % Custom symbol rate
    config.Runner.NumScenarios = 10; % Custom scenario count
end
```

#### Available Base Configurations

**Logging Configurations:**
- `_base_/logging/default.m` - Standard logging setup
- `_base_/logging/debug.m` - Enhanced debug logging

**Runner Configurations:**
- `_base_/runners/default.m` - Standard simulation runner
- `_base_/runners/high_performance.m` - Optimized performance settings

**Factory Configurations:**
- `_base_/factories/scenario_factory.m` - Scenario factory with dual-component architecture
- `_base_/factories/message_factory.m` - Message generation factory 
- `_base_/factories/modulation_factory.m` - Comprehensive modulation schemes
- `_base_/factories/transmit_factory.m` - Transmitter RF front-end models
- `_base_/factories/channel_factory.m` - Channel propagation models
- `_base_/factories/receive_factory.m` - Receiver RF front-end models

### 4. Version Management
- Include version metadata in configurations
- Document configuration changes and their purposes

## Creating New Configurations

To create new modular configurations:

1. **Start with the example**: Use `csrd2025/csrd2025.m` as a template
2. **Choose base configs**: Select appropriate base configurations from `_base_/`
3. **Customize parameters**: Override specific parameters for your use case
4. **Test your config**: Use `csrd.utils.config_loader('your_config.m')`
5. **Use in simulation**: Call `simulation(1, 1, 'your_config.m')`

### Framework Integration

The modular system integrates seamlessly with the CSRD framework:
- All generated configurations follow standard CSRD structure
- Supports existing simulation scripts and workflows
- Full support for all CSRD factories and components

## Using with Simulation

The simulation function uses the modular configuration system:

```matlab
% Use default configuration
simulation();

% Use specific configuration
simulation(1, 1, 'csrd2025/csrd2025.m');

% Use custom configuration file
simulation(1, 1, 'path/to/your_config.m');
```

## Example Configuration

The `csrd2025/csrd2025.m` file provides a complete example of how to create a modular configuration using inheritance and base configurations.

**Key Features of the Example:**
- **Complete Factory Coverage**: Inherits all 6 factory configurations
- **Modular Design**: Organized configuration (5.7KB) with clear inheritance
- **Full CSRD Structure**: Produces complete CSRD framework configuration 
- **Easy Customization**: Override specific parameters while inheriting base configurations

Use `csrd2025/csrd2025.m` as a template for creating your own configurations.

## Key Advantages

1. **Modular Design**: Clean separation of concerns with base configurations
2. **Simplified Interface**: Single `config_loader()` function handles all loading needs
3. **Inheritance System**: Reuse and extend configurations efficiently
4. **Clear Examples**: `csrd2025` provides a complete working example
5. **Easy Maintenance**: Modular organization makes configs easier to understand and modify
6. **Full CSRD Support**: Complete coverage of all framework components and factories 