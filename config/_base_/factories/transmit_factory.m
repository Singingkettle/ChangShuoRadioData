function config = transmit_factory()
    % transmit_factory - Transmitter factory configuration
    %
    % Contains IMPLEMENTATION details for transmitter instantiation:
    %   - Class handles for different transmitter types
    %   - RF impairment model configurations (how to apply impairments)
    %
    % NOTE: Parameter RANGES (power, antennas, etc.) for scenario generation
    %       are now defined in scenario_factory.m under CommunicationBehavior.
    %
    % Structure:
    %   config.Factories.Transmit
    %   ├── Types                        % Available transmitter types
    %   ├── Simulation                   % Simulation-based transmitter
    %   │   ├── handle                   % Class handle
    %   │   ├── DCOffset                 % DC offset range
    %   │   ├── IQImbalance              % IQ imbalance ranges
    %   │   ├── PhaseNoise               % Phase noise ranges
    %   │   └── Nonlinearity             % Nonlinearity model configurations
    %   ├── Real                         % Real hardware (future placeholder)
    %   ├── LogDetails
    %   └── Description

    %% ========== AVAILABLE TRANSMITTER TYPES ==========
    config.Factories.Transmit.Types = {'Simulation'};

    %% ========== SIMULATION TRANSMITTER ==========
    config.Factories.Transmit.Simulation.handle = 'csrd.blocks.physical.txRadioFront.TRFSimulator';
    config.Factories.Transmit.Simulation.Description = 'Simulation-based transmitter with configurable RF impairments';

    % --- DCOffset: DC offset range ---
    config.Factories.Transmit.Simulation.DCOffset = [-60, -40]; % dB

    % --- IQImbalance: IQ imbalance ranges ---
    config.Factories.Transmit.Simulation.IQImbalance.Amplitude = [0, 5]; % dB
    config.Factories.Transmit.Simulation.IQImbalance.Phase = [0, 5];     % degrees

    % --- PhaseNoise: Phase noise configuration ---
    % Multi-point specification at standard frequency offsets
    % FrequencyOffset must be large enough relative to SampleRate to avoid
    % enormous internal buffers in comm.PhaseNoise
    config.Factories.Transmit.Simulation.PhaseNoise.Level = [-80, -130];              % dBc/Hz (range for randomization)
    config.Factories.Transmit.Simulation.PhaseNoise.FrequencyOffsets = [1e3, 10e3, 100e3]; % Hz (fixed multi-point)

    % --- Nonlinearity: Memory-less nonlinearity model configurations ---
    config.Factories.Transmit.Simulation.Nonlinearity.Methods = { ...
        'Cubic polynomial', 'Hyperbolic tangent', 'Saleh model', ...
        'Ghorbani model', 'Modified Rapp model'};

    % Cubic polynomial model
    config.Factories.Transmit.Simulation.Nonlinearity.CubicPolynomial.LinearGain = [0, 10];
    config.Factories.Transmit.Simulation.Nonlinearity.CubicPolynomial.TOISpecification = { ...
        'IIP3', 'OIP3', 'IP1dB', 'OP1dB', 'IPsat', 'OPsat'};
    config.Factories.Transmit.Simulation.Nonlinearity.CubicPolynomial.IIP3 = [20, 40];
    config.Factories.Transmit.Simulation.Nonlinearity.CubicPolynomial.OIP3 = [20, 40];
    config.Factories.Transmit.Simulation.Nonlinearity.CubicPolynomial.IP1dB = [20, 40];
    config.Factories.Transmit.Simulation.Nonlinearity.CubicPolynomial.OP1dB = [20, 40];
    config.Factories.Transmit.Simulation.Nonlinearity.CubicPolynomial.IPsat = [20, 40];
    config.Factories.Transmit.Simulation.Nonlinearity.CubicPolynomial.OPsat = [20, 40];
    config.Factories.Transmit.Simulation.Nonlinearity.CubicPolynomial.AMPMConversion = [10, 20];
    config.Factories.Transmit.Simulation.Nonlinearity.CubicPolynomial.PowerLowerLimit = 10;
    config.Factories.Transmit.Simulation.Nonlinearity.CubicPolynomial.PowerUpperLimit = Inf;

    % Hyperbolic tangent model
    config.Factories.Transmit.Simulation.Nonlinearity.HyperbolicTangent.LinearGain = [0, 10];
    config.Factories.Transmit.Simulation.Nonlinearity.HyperbolicTangent.IIP3 = [20, 40];
    config.Factories.Transmit.Simulation.Nonlinearity.HyperbolicTangent.AMPMConversion = [10, 20];
    config.Factories.Transmit.Simulation.Nonlinearity.HyperbolicTangent.PowerLowerLimit = 10;
    config.Factories.Transmit.Simulation.Nonlinearity.HyperbolicTangent.PowerUpperLimit = Inf;

    % Saleh model
    config.Factories.Transmit.Simulation.Nonlinearity.SalehModel.InputScaling = [-1, 1];
    config.Factories.Transmit.Simulation.Nonlinearity.SalehModel.AMAMParametersLeft = [2.157, 2.159];
    config.Factories.Transmit.Simulation.Nonlinearity.SalehModel.AMAMParametersRight = [1.151, 1.152];
    config.Factories.Transmit.Simulation.Nonlinearity.SalehModel.AMPMParametersLeft = [4.003, 4.004];
    config.Factories.Transmit.Simulation.Nonlinearity.SalehModel.AMPMParametersRight = [9.103, 9.105];
    config.Factories.Transmit.Simulation.Nonlinearity.SalehModel.OutputScaling = [-1, 1];

    % Ghorbani model
    config.Factories.Transmit.Simulation.Nonlinearity.GhorbaniModel.InputScaling = [-1, 1];
    config.Factories.Transmit.Simulation.Nonlinearity.GhorbaniModel.AMAMParametersLeft1 = [8.1075, 8.1085];
    config.Factories.Transmit.Simulation.Nonlinearity.GhorbaniModel.AMAMParametersLeft2 = [1.541, 1.542];
    config.Factories.Transmit.Simulation.Nonlinearity.GhorbaniModel.AMAMParametersRight1 = [6.52, 6.521];
    config.Factories.Transmit.Simulation.Nonlinearity.GhorbaniModel.AMAMParametersRight2 = [-0.071, -0.072];
    config.Factories.Transmit.Simulation.Nonlinearity.GhorbaniModel.AMPMParametersLeft1 = [4.664, 4.665];
    config.Factories.Transmit.Simulation.Nonlinearity.GhorbaniModel.AMPMParametersLeft2 = [2.096, 2.097];
    config.Factories.Transmit.Simulation.Nonlinearity.GhorbaniModel.AMPMParametersRight1 = [10.8, 10.9];
    config.Factories.Transmit.Simulation.Nonlinearity.GhorbaniModel.AMPMParametersRight2 = [-0.002, -0.004];
    config.Factories.Transmit.Simulation.Nonlinearity.GhorbaniModel.OutputScaling = [-1, 1];

    % Modified Rapp model
    config.Factories.Transmit.Simulation.Nonlinearity.ModifiedRappModel.LinearGain = [0, 10];
    config.Factories.Transmit.Simulation.Nonlinearity.ModifiedRappModel.Smoothness = [0.4, 0.6];
    config.Factories.Transmit.Simulation.Nonlinearity.ModifiedRappModel.PhaseGainRadian = [-0.45, 0];
    config.Factories.Transmit.Simulation.Nonlinearity.ModifiedRappModel.PhaseSaturation = [0.8, 0.9];
    config.Factories.Transmit.Simulation.Nonlinearity.ModifiedRappModel.PhaseSmoothness = [3.2, 3.6];
    config.Factories.Transmit.Simulation.Nonlinearity.ModifiedRappModel.OutputSaturationLevel = [0.9, 1.1];

    %% ========== REAL HARDWARE TRANSMITTER (FUTURE) ==========
    config.Factories.Transmit.Real.SDR.handle = '';
    config.Factories.Transmit.Real.SDR.Description = 'SDR-based transmitter (not implemented)';
    config.Factories.Transmit.Real.SDR.Supported = false;

    %% ========== METADATA ==========
    config.Factories.Transmit.LogDetails = true;
    config.Factories.Transmit.Description = 'Transmitter factory configuration (RF impairment models)';
end
