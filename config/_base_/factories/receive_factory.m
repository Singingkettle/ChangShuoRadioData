function config = receive_factory()
    %RECEIVE_FACTORY Receiver factory configuration (v0.4 deep refactor).
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 receive_factory 实现。
    %
    %   Splits cleanly into:
    %     * Available receiver TYPEs (the scenario layer picks one).
    %     * Hardware DETAILs per type (RF impairment ranges, antenna config,
    %       memoryless nonlinearity templates).
    %
    %   The Nonlinearity section follows the official MATLAB
    %   `comm.MemorylessNonlinearity` System object property contract
    %   exactly. Each Method block lists ONLY the properties that the
    %   System object actually accepts for that Method (per the
    %   "Dependencies" section of the official docs):
    %
    %     Cubic polynomial   : LinearGain, TOISpecification + (the ONE
    %                          intercept / saturation property required by
    %                          TOISpecification: IIP3 | OIP3 | IP1dB |
    %                          OP1dB | IPsat | OPsat),
    %                          AMPMConversion, PowerLowerLimit,
    %                          PowerUpperLimit
    %     Hyperbolic tangent : LinearGain, IIP3, AMPMConversion,
    %                          PowerLowerLimit, PowerUpperLimit
    %     Saleh model        : InputScaling, AMAMParameters[1x2],
    %                          AMPMParameters[1x2], OutputScaling
    %     Ghorbani model     : InputScaling, AMAMParameters[1x4],
    %                          AMPMParameters[1x4], OutputScaling
    %     Modified Rapp model: LinearGain, Smoothness, PhaseGainRadian,
    %                          PhaseSaturation, PhaseSmoothness,
    %                          OutputSaturationLevel
    %     Lookup table       : Table[Nx3] = [Pin_dBm, Pout_dBm, dPhi_deg]
    %
    %   For every Method, ReferenceImpedance is shared (set in
    %   ReceiveFactory.configureNonlinearity, default 50 Ω).
    %
    %   For Cubic polynomial, the per-TOISpecification numeric range is
    %   nested under the TOISpecification name so the random sampler picks
    %   one TOISpec and ONLY draws the matching numeric range. This
    %   removes the "draw every intercept then ignore most" anti-pattern
    %   that earlier shipped in this config.

    config.Factories.Receive.Types = {'Simulation'};

    config.Factories.Receive.Simulation.handle = ...
        'csrd.blocks.physical.rxRadioFront.RRFSimulator';
    config.Factories.Receive.Simulation.Description = ...
        'Simulation-based receiver with configurable RF impairments';

    % --- Hardware Parameters (Detail-level, not scenario-level) ---
    config.Factories.Receive.Simulation.Parameters.NoiseFigure.Min = 3;      % dB
    config.Factories.Receive.Simulation.Parameters.NoiseFigure.Max = 10;     % dB
    config.Factories.Receive.Simulation.Parameters.Sensitivity.Min = -110;   % dBm
    config.Factories.Receive.Simulation.Parameters.Sensitivity.Max = -80;    % dBm
    config.Factories.Receive.Simulation.Parameters.AntennaGain.Min = 0;      % dBi
    config.Factories.Receive.Simulation.Parameters.AntennaGain.Max = 20;     % dBi

    % --- Antenna types ---
    config.Factories.Receive.Simulation.Antenna.Types = {'Omni', 'Parabolic', 'Array'};
    config.Factories.Receive.Simulation.Antenna.Omni.Gain = [0, 6];
    config.Factories.Receive.Simulation.Antenna.Omni.Height = [5, 30];
    config.Factories.Receive.Simulation.Antenna.Parabolic.Diameter = [0.3, 5.0];
    config.Factories.Receive.Simulation.Antenna.Parabolic.Efficiency = [0.45, 0.7];
    config.Factories.Receive.Simulation.Antenna.Parabolic.Gain = [20, 40];
    config.Factories.Receive.Simulation.Antenna.Array.NumElements = [2, 8];
    config.Factories.Receive.Simulation.Antenna.Array.ElementSpacing = [0.4, 0.6];
    config.Factories.Receive.Simulation.Antenna.Array.Geometry = {'ULA', 'URA'};

    % --- DCOffset (dB) ---
    config.Factories.Receive.Simulation.DCOffset = [-60, -40];

    % --- IQImbalance ---
    config.Factories.Receive.Simulation.IQImbalance.Amplitude = [0, 5];   % dB
    config.Factories.Receive.Simulation.IQImbalance.Phase = [0, 5];       % deg

    % --- ThermalNoise ---
    config.Factories.Receive.Simulation.ThermalNoise.NoiseFigure = [10, 20]; % dB

    % --- Reference impedance (shared across all Methods) ---
    config.Factories.Receive.Simulation.Nonlinearity.ReferenceImpedance = 50; % Ω

    % --- Available Methods ---
    config.Factories.Receive.Simulation.Nonlinearity.Methods = { ...
        'Cubic polynomial', 'Hyperbolic tangent', 'Saleh model', ...
        'Ghorbani model', 'Modified Rapp model', 'Lookup table' };

    % --- Cubic polynomial ---------------------------------------------
    cp = struct();
    cp.LinearGain = [0, 10];                   % dB
    cp.TOISpecifications = { ...                % Only one is used per draw
        'IIP3', 'OIP3', 'IP1dB', 'OP1dB', 'IPsat', 'OPsat' };
    cp.IIP3  = [20, 40];                       % dBm
    cp.OIP3  = [20, 40];
    cp.IP1dB = [20, 40];
    cp.OP1dB = [20, 40];
    cp.IPsat = [20, 40];
    cp.OPsat = [20, 40];
    cp.AMPMConversion  = [10, 20];             % deg/dB
    cp.PowerLowerLimit = [-40, 10];            % dBm
    cp.PowerUpperLimit = Inf;                  % dBm (Inf = unbounded)
    config.Factories.Receive.Simulation.Nonlinearity.CubicPolynomial = cp;

    % --- Hyperbolic tangent --------------------------------------------
    ht = struct();
    ht.LinearGain      = [0, 10];
    ht.IIP3            = [20, 40];
    ht.AMPMConversion  = [10, 20];
    ht.PowerLowerLimit = [-40, 10];
    ht.PowerUpperLimit = Inf;
    config.Factories.Receive.Simulation.Nonlinearity.HyperbolicTangent = ht;

    % --- Saleh model ---------------------------------------------------
    sm = struct();
    sm.InputScaling          = [-1, 1];        % dB
    sm.AMAMParametersAlpha   = [2.157, 2.159]; % α_a
    sm.AMAMParametersBeta    = [1.151, 1.152]; % β_a
    sm.AMPMParametersAlpha   = [4.003, 4.004]; % α_φ
    sm.AMPMParametersBeta    = [9.103, 9.105]; % β_φ
    sm.OutputScaling         = [-1, 1];
    config.Factories.Receive.Simulation.Nonlinearity.SalehModel = sm;

    % --- Ghorbani model ------------------------------------------------
    gm = struct();
    gm.InputScaling           = [-1, 1];
    gm.AMAMParametersX1       = [8.1075, 8.1085];
    gm.AMAMParametersX2       = [1.541,  1.542];
    gm.AMAMParametersX3       = [6.520,  6.521];
    gm.AMAMParametersX4       = [-0.072, -0.071];
    gm.AMPMParametersY1       = [4.664,  4.665];
    gm.AMPMParametersY2       = [2.096,  2.097];
    gm.AMPMParametersY3       = [10.80, 10.90];
    gm.AMPMParametersY4       = [-0.004, -0.002];
    gm.OutputScaling          = [-1, 1];
    config.Factories.Receive.Simulation.Nonlinearity.GhorbaniModel = gm;

    % --- Modified Rapp model -------------------------------------------
    mr = struct();
    mr.LinearGain            = [0, 10];
    mr.Smoothness            = [0.4, 0.6];
    mr.PhaseGainRadian       = [-0.45, 0];
    mr.PhaseSaturation       = [0.8, 0.9];
    mr.PhaseSmoothness       = [3.2, 3.6];
    mr.OutputSaturationLevel = [0.9, 1.1];     % volts
    config.Factories.Receive.Simulation.Nonlinearity.ModifiedRappModel = mr;

    % --- Lookup table --------------------------------------------------
    % Default lookup table mirrors the System object's documented default
    % characterisation curve. Override in derived configs if a measured
    % PA characterisation is available.
    lt = struct();
    lt.Table = [ ...
        -25,  5.16, -0.25;
        -20, 10.11, -0.47;
        -15, 15.11, -0.68;
        -10, 20.05, -0.89;
         -5, 24.79, -1.22;
          0, 27.64,  5.59;
          5, 28.49, 12.03 ];
    config.Factories.Receive.Simulation.Nonlinearity.LookupTable = lt;

    config.Factories.Receive.LogDetails = true;
    config.Factories.Receive.Description = ...
        'Receiver factory (class handles + hardware details)';
end
