function config = transmit_factory()
    %TRANSMIT_FACTORY Transmitter factory configuration (v0.4 deep refactor).
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 transmit_factory 实现。
    %
    %   Implementation details for transmitter instantiation:
    %     * Class handles for different transmitter types
    %     * RF impairment configuration (DCOffset, IQ, PhaseNoise, PA
    %       memoryless nonlinearity).
    %
    %   The Nonlinearity section follows the official MATLAB
    %   `comm.MemorylessNonlinearity` documentation: each Method block
    %   lists ONLY the properties the System object accepts for that
    %   Method (per the "Dependencies" section). The cubic polynomial
    %   case lists every TOI specification choice in TOISpecifications;
    %   only the matching numeric range is sampled at runtime.
    %
    %   NOTE: scenario-level parameter ranges (transmit power, antennas,
    %   etc.) live in scenario_factory.m / CommunicationBehavior, not
    %   here.

    config.Factories.Transmit.Types = {'Simulation'};

    config.Factories.Transmit.Simulation.handle = ...
        'csrd.blocks.physical.txRadioFront.TRFSimulator';
    config.Factories.Transmit.Simulation.Description = ...
        'Simulation-based transmitter with configurable RF impairments';

    % --- DCOffset (dB) ---
    config.Factories.Transmit.Simulation.DCOffset = [-60, -40];

    % --- IQImbalance ---
    config.Factories.Transmit.Simulation.IQImbalance.Amplitude = [0, 5]; % dB
    config.Factories.Transmit.Simulation.IQImbalance.Phase     = [0, 5]; % deg

    % --- PhaseNoise (multi-point spec) ---
    config.Factories.Transmit.Simulation.PhaseNoise.Level            = [-130, -80]; % dBc/Hz
    config.Factories.Transmit.Simulation.PhaseNoise.FrequencyOffsets = [1e3, 10e3, 100e3]; % Hz

    % --- Reference impedance (shared across all Methods) ---
    config.Factories.Transmit.Simulation.Nonlinearity.ReferenceImpedance = 50; % Ω

    % --- Available Methods ---
    config.Factories.Transmit.Simulation.Nonlinearity.Methods = { ...
        'Cubic polynomial', 'Hyperbolic tangent', 'Saleh model', ...
        'Ghorbani model', 'Modified Rapp model', 'Lookup table' };

    % --- Cubic polynomial -------------------------------------------
    cp = struct();
    cp.LinearGain = [0, 10];
    cp.TOISpecifications = { ...
        'IIP3', 'OIP3', 'IP1dB', 'OP1dB', 'IPsat', 'OPsat' };
    cp.IIP3  = [20, 40];
    cp.OIP3  = [20, 40];
    cp.IP1dB = [20, 40];
    cp.OP1dB = [20, 40];
    cp.IPsat = [20, 40];
    cp.OPsat = [20, 40];
    cp.AMPMConversion  = [10, 20];
    cp.PowerLowerLimit = [-40, 10];
    cp.PowerUpperLimit = Inf;
    config.Factories.Transmit.Simulation.Nonlinearity.CubicPolynomial = cp;

    % --- Hyperbolic tangent -----------------------------------------
    ht = struct();
    ht.LinearGain      = [0, 10];
    ht.IIP3            = [20, 40];
    ht.AMPMConversion  = [10, 20];
    ht.PowerLowerLimit = [-40, 10];
    ht.PowerUpperLimit = Inf;
    config.Factories.Transmit.Simulation.Nonlinearity.HyperbolicTangent = ht;

    % --- Saleh model ------------------------------------------------
    sm = struct();
    sm.InputScaling          = [-1, 1];
    sm.AMAMParametersAlpha   = [2.157, 2.159];
    sm.AMAMParametersBeta    = [1.151, 1.152];
    sm.AMPMParametersAlpha   = [4.003, 4.004];
    sm.AMPMParametersBeta    = [9.103, 9.105];
    sm.OutputScaling         = [-1, 1];
    config.Factories.Transmit.Simulation.Nonlinearity.SalehModel = sm;

    % --- Ghorbani model ---------------------------------------------
    gm = struct();
    gm.InputScaling          = [-1, 1];
    gm.AMAMParametersX1      = [8.1075, 8.1085];
    gm.AMAMParametersX2      = [1.541,  1.542];
    gm.AMAMParametersX3      = [6.520,  6.521];
    gm.AMAMParametersX4      = [-0.072, -0.071];
    gm.AMPMParametersY1      = [4.664,  4.665];
    gm.AMPMParametersY2      = [2.096,  2.097];
    gm.AMPMParametersY3      = [10.80, 10.90];
    gm.AMPMParametersY4      = [-0.004, -0.002];
    gm.OutputScaling         = [-1, 1];
    config.Factories.Transmit.Simulation.Nonlinearity.GhorbaniModel = gm;

    % --- Modified Rapp model ----------------------------------------
    mr = struct();
    mr.LinearGain            = [0, 10];
    mr.Smoothness            = [0.4, 0.6];
    mr.PhaseGainRadian       = [-0.45, 0];
    mr.PhaseSaturation       = [0.8, 0.9];
    mr.PhaseSmoothness       = [3.2, 3.6];
    mr.OutputSaturationLevel = [0.9, 1.1];
    config.Factories.Transmit.Simulation.Nonlinearity.ModifiedRappModel = mr;

    % --- Lookup table -----------------------------------------------
    lt = struct();
    lt.Table = [ ...
        -25,  5.16, -0.25;
        -20, 10.11, -0.47;
        -15, 15.11, -0.68;
        -10, 20.05, -0.89;
         -5, 24.79, -1.22;
          0, 27.64,  5.59;
          5, 28.49, 12.03 ];
    config.Factories.Transmit.Simulation.Nonlinearity.LookupTable = lt;

    config.Factories.Transmit.LogDetails = true;
    config.Factories.Transmit.Description = ...
        'Transmitter factory configuration (RF impairment models)';
end
