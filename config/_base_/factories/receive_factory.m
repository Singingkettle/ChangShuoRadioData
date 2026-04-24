function config = receive_factory()
    % receive_factory - Receiver factory configuration
    %
    % DESIGN PRINCIPLE:
    %   - Scenario config: Selects receiver TYPE and scenario-level params (SampleRate, NumAntennas)
    %   - This config: Defines DETAILS for each type (RF impairments, hardware params)
    %
    % Structure:
    %   config.Factories.Receive
    %   ├── Types                        % Available receiver types
    %   ├── Simulation                   % Simulation-based receiver
    %   │   ├── handle                   % Class handle
    %   │   ├── Parameters               % Hardware parameter ranges (NoiseFigure, etc.)
    %   │   ├── Antenna                  % Antenna type configurations
    %   │   ├── DCOffset                 % DC offset range
    %   │   ├── IQImbalance              % IQ imbalance ranges
    %   │   ├── ThermalNoise             % Thermal noise ranges
    %   │   └── Nonlinearity             % Nonlinearity model configurations
    %   ├── Real                         % Real hardware (future placeholder)
    %   └── Description

    %% ========== AVAILABLE RECEIVER TYPES ==========
    config.Factories.Receive.Types = {'Simulation'};

    %% ========== SIMULATION RECEIVER ==========
    config.Factories.Receive.Simulation.handle = 'csrd.blocks.physical.rxRadioFront.RRFSimulator';
    config.Factories.Receive.Simulation.Description = 'Simulation-based receiver with configurable RF impairments';

    % --- Hardware Parameters (Detail-level, not scenario-level) ---
    config.Factories.Receive.Simulation.Parameters.NoiseFigure.Min = 3;      % dB
    config.Factories.Receive.Simulation.Parameters.NoiseFigure.Max = 10;     % dB
    config.Factories.Receive.Simulation.Parameters.Sensitivity.Min = -110;   % dBm
    config.Factories.Receive.Simulation.Parameters.Sensitivity.Max = -80;    % dBm
    config.Factories.Receive.Simulation.Parameters.AntennaGain.Min = 0;      % dBi
    config.Factories.Receive.Simulation.Parameters.AntennaGain.Max = 20;     % dBi

    % --- Antenna: Antenna type configurations ---
    config.Factories.Receive.Simulation.Antenna.Types = {'Omni', 'Parabolic', 'Array'};
    config.Factories.Receive.Simulation.Antenna.Omni.Gain = [0, 6];
    config.Factories.Receive.Simulation.Antenna.Omni.Height = [5, 30];
    config.Factories.Receive.Simulation.Antenna.Parabolic.Diameter = [0.3, 5.0];
    config.Factories.Receive.Simulation.Antenna.Parabolic.Efficiency = [0.45, 0.7];
    config.Factories.Receive.Simulation.Antenna.Parabolic.Gain = [20, 40];
    config.Factories.Receive.Simulation.Antenna.Array.NumElements = [2, 8];
    config.Factories.Receive.Simulation.Antenna.Array.ElementSpacing = [0.4, 0.6];
    config.Factories.Receive.Simulation.Antenna.Array.Geometry = {'ULA', 'URA'};

    % --- DCOffset: DC offset range ---
    config.Factories.Receive.Simulation.DCOffset = [-60, -40];

    % --- IQImbalance: IQ imbalance ranges ---
    config.Factories.Receive.Simulation.IQImbalance.Amplitude = [0, 5];
    config.Factories.Receive.Simulation.IQImbalance.Phase = [0, 5];

    % --- ThermalNoise: Thermal noise configuration ---
    config.Factories.Receive.Simulation.ThermalNoise.NoiseFigure = [10, 20];

    % --- Nonlinearity: Memory-less nonlinearity model configurations ---
    config.Factories.Receive.Simulation.Nonlinearity.Methods = { ...
        'Cubic polynomial', 'Hyperbolic tangent', 'Saleh model', ...
        'Ghorbani model', 'Modified Rapp model'};

    % Cubic polynomial model
    config.Factories.Receive.Simulation.Nonlinearity.CubicPolynomial.LinearGain = [0, 10];
    config.Factories.Receive.Simulation.Nonlinearity.CubicPolynomial.TOISpecification = { ...
        'IIP3', 'OIP3', 'IP1dB', 'OP1dB', 'IPsat', 'OPsat'};
    config.Factories.Receive.Simulation.Nonlinearity.CubicPolynomial.IIP3 = [20, 40];
    config.Factories.Receive.Simulation.Nonlinearity.CubicPolynomial.OIP3 = [20, 40];
    config.Factories.Receive.Simulation.Nonlinearity.CubicPolynomial.IP1dB = [20, 40];
    config.Factories.Receive.Simulation.Nonlinearity.CubicPolynomial.OP1dB = [20, 40];
    config.Factories.Receive.Simulation.Nonlinearity.CubicPolynomial.IPsat = [20, 40];
    config.Factories.Receive.Simulation.Nonlinearity.CubicPolynomial.OPsat = [20, 40];
    config.Factories.Receive.Simulation.Nonlinearity.CubicPolynomial.AMPMConversion = [10, 20];
    config.Factories.Receive.Simulation.Nonlinearity.CubicPolynomial.PowerLowerLimit = 10;
    config.Factories.Receive.Simulation.Nonlinearity.CubicPolynomial.PowerUpperLimit = Inf;

    % Hyperbolic tangent model
    config.Factories.Receive.Simulation.Nonlinearity.HyperbolicTangent.LinearGain = [0, 10];
    config.Factories.Receive.Simulation.Nonlinearity.HyperbolicTangent.IIP3 = [20, 40];
    config.Factories.Receive.Simulation.Nonlinearity.HyperbolicTangent.AMPMConversion = [10, 20];
    config.Factories.Receive.Simulation.Nonlinearity.HyperbolicTangent.PowerLowerLimit = 10;
    config.Factories.Receive.Simulation.Nonlinearity.HyperbolicTangent.PowerUpperLimit = Inf;

    % Saleh model
    config.Factories.Receive.Simulation.Nonlinearity.SalehModel.InputScaling = [-1, 1];
    config.Factories.Receive.Simulation.Nonlinearity.SalehModel.AMAMParametersLeft = [2.157, 2.159];
    config.Factories.Receive.Simulation.Nonlinearity.SalehModel.AMAMParametersRight = [1.151, 1.152];
    config.Factories.Receive.Simulation.Nonlinearity.SalehModel.AMPMParametersLeft = [4.003, 4.004];
    config.Factories.Receive.Simulation.Nonlinearity.SalehModel.AMPMParametersRight = [9.103, 9.105];
    config.Factories.Receive.Simulation.Nonlinearity.SalehModel.OutputScaling = [-1, 1];

    % Ghorbani model
    config.Factories.Receive.Simulation.Nonlinearity.GhorbaniModel.InputScaling = [-1, 1];
    config.Factories.Receive.Simulation.Nonlinearity.GhorbaniModel.AMAMParametersLeft1 = [8.1075, 8.1085];
    config.Factories.Receive.Simulation.Nonlinearity.GhorbaniModel.AMAMParametersLeft2 = [1.541, 1.542];
    config.Factories.Receive.Simulation.Nonlinearity.GhorbaniModel.AMAMParametersRight1 = [6.52, 6.521];
    config.Factories.Receive.Simulation.Nonlinearity.GhorbaniModel.AMAMParametersRight2 = [-0.071, -0.072];
    config.Factories.Receive.Simulation.Nonlinearity.GhorbaniModel.AMPMParametersLeft1 = [4.664, 4.665];
    config.Factories.Receive.Simulation.Nonlinearity.GhorbaniModel.AMPMParametersLeft2 = [2.096, 2.097];
    config.Factories.Receive.Simulation.Nonlinearity.GhorbaniModel.AMPMParametersRight1 = [10.8, 10.9];
    config.Factories.Receive.Simulation.Nonlinearity.GhorbaniModel.AMPMParametersRight2 = [-0.002, -0.004];
    config.Factories.Receive.Simulation.Nonlinearity.GhorbaniModel.OutputScaling = [-1, 1];

    % Modified Rapp model
    config.Factories.Receive.Simulation.Nonlinearity.ModifiedRappModel.LinearGain = [0, 10];
    config.Factories.Receive.Simulation.Nonlinearity.ModifiedRappModel.Smoothness = [0.4, 0.6];
    config.Factories.Receive.Simulation.Nonlinearity.ModifiedRappModel.PhaseGainRadian = [-0.45, 0];
    config.Factories.Receive.Simulation.Nonlinearity.ModifiedRappModel.PhaseSaturation = [0.8, 0.9];
    config.Factories.Receive.Simulation.Nonlinearity.ModifiedRappModel.PhaseSmoothness = [3.2, 3.6];
    config.Factories.Receive.Simulation.Nonlinearity.ModifiedRappModel.OutputSaturationLevel = [0.9, 1.1];

    %% ========== REAL HARDWARE RECEIVER (FUTURE) ==========
    config.Factories.Receive.Real.SDR.handle = '';
    config.Factories.Receive.Real.SDR.Description = 'SDR-based receiver (not implemented)';
    config.Factories.Receive.Real.SDR.Supported = false;

    %% ========== METADATA ==========
    config.Factories.Receive.LogDetails = true;
    config.Factories.Receive.Description = 'Receiver factory (class handles + hardware details)';
end
