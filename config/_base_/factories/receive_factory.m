function config = receive_factory()
    %RECEIVE_FACTORY Receiver factory configuration (v0.4 deep refactor).
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
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

    % --- DCOffset (dB) ---
    config.Factories.Receive.Simulation.DCOffset = [-60, -40];

    % --- IQImbalance ---
    config.Factories.Receive.Simulation.IQImbalance.Amplitude = [0, 5];   % dB
    config.Factories.Receive.Simulation.IQImbalance.Phase = [0, 5];       % deg

    % --- ThermalNoise ---
    config.Factories.Receive.Simulation.ThermalNoise.NoiseFigure = [10, 20]; % dB

    % --- Reference impedance (shared across all Methods) ---
    config.Factories.Receive.Simulation.Nonlinearity.ReferenceImpedance = 50; % Ω

    % --- Input back-off (shared across all Methods) ---
    % Same attenuate-only guard as the transmit side (see transmit_factory.m
    % and TRFSimulator Step 3.5), enforced by RRFSimulator in front of the LNA.
    % On the receive side this guard is not a corner case: the combined
    % channel-output frames measure +33..+35 dBm (50-ohm convention) at the
    % LNA input -- 3..40 dB PAST every Method's compression point -- so
    % without it every saved frame's waveform is LNA-clipped. The range is
    % tighter than the transmitter's [4, 12] because a receiver operator runs
    % the front end linear (the LNA exists to preserve the waveform, not to
    % shape it); the residual nonlinearity diversity comes from the drawn
    % curve parameters. Attenuation ahead of the (tiny, absolute-power)
    % thermal-noise stage rescales the frame without breaking the controlled
    % SNR realization, and the received-SNR GT re-measures realized noise.
    config.Factories.Receive.Simulation.Nonlinearity.InputBackoffDb = [8, 16];

    % --- Available Methods ---
    config.Factories.Receive.Simulation.Nonlinearity.Methods = { ...
        'Cubic polynomial', 'Hyperbolic tangent', 'Saleh model', ...
        'Ghorbani model', 'Modified Rapp model', 'Lookup table' };

    % --- Cubic polynomial ---------------------------------------------
    % PHYSICALIZED (construction audit), mirroring transmit_factory.m batch 1
    % but tighter: an LNA's AM/PM is fractions of a degree per dB (the [10, 20]
    % deg/dB that shipped here belongs to no real receiver front end), so the
    % receive-side window is [0, 1.5] with zero included -- many LNAs measure
    % no AM/PM at all. The power window and TOI rationale are the transmit
    % side's: AM/PM engages only near compression, the window can never
    % invert (factory asserts), and IM3 shoulders stay -26 dBc or better.
    cp = struct();
    cp.LinearGain = [0, 10];                   % dB
    cp.TOISpecifications = { ...                % Only one is used per draw
        'IIP3', 'OIP3', 'IP1dB', 'OP1dB', 'IPsat', 'OPsat' };
    cp.IIP3  = [26, 40];                       % dBm
    cp.OIP3  = [26, 40];
    cp.IP1dB = [26, 40];
    cp.OP1dB = [26, 40];
    cp.IPsat = [26, 40];
    cp.OPsat = [26, 40];
    cp.AMPMConversion  = [0, 1.5];             % deg/dB
    cp.PowerLowerLimit = [0, 10];              % dBm
    cp.PowerUpperLimit = [15, 22];             % dBm
    config.Factories.Receive.Simulation.Nonlinearity.CubicPolynomial = cp;

    % --- Hyperbolic tangent --------------------------------------------
    % Same physicalization as CubicPolynomial.
    ht = struct();
    ht.LinearGain      = [0, 10];
    ht.IIP3            = [26, 40];
    ht.AMPMConversion  = [0, 1.5];
    ht.PowerLowerLimit = [0, 10];
    ht.PowerUpperLimit = [15, 22];
    config.Factories.Receive.Simulation.Nonlinearity.HyperbolicTangent = ht;

    % --- Saleh model ---------------------------------------------------
    % Canonical published curve parameters, untouched; the operating point is
    % fixed the same way as on the transmit side: InputScaling [-12, -4] keeps
    % the drive on the monotonic segment of the Saleh AM/AM instead of past
    % its fold-over (r ~ 0.93), and the InputBackoffDb guard above holds the
    % combined-frame drive at a compression-referenced distance.
    sm = struct();
    sm.InputScaling          = [-12, -4];      % dB
    sm.AMAMParametersAlpha   = [2.157, 2.159]; % α_a
    sm.AMAMParametersBeta    = [1.151, 1.152]; % β_a
    sm.AMPMParametersAlpha   = [4.003, 4.004]; % α_φ
    sm.AMPMParametersBeta    = [9.103, 9.105]; % β_φ
    sm.OutputScaling         = [-1, 1];
    config.Factories.Receive.Simulation.Nonlinearity.SalehModel = sm;

    % --- Ghorbani model ------------------------------------------------
    % Same operating-point fix as Saleh: canonical curve parameters kept, the
    % drive backed off the saturating region via InputScaling.
    gm = struct();
    gm.InputScaling           = [-12, -4];
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
    % Smoothness p < 1 is not a physical SSPA (compression bleeds across the
    % whole dynamic range instead of localizing near saturation), and
    % PhaseGainRadian is brought to the near-zero AM/PM a real front end
    % exhibits. Mirrors the transmit-side batch-1 rationale.
    mr = struct();
    mr.LinearGain            = [0, 10];
    mr.Smoothness            = [1.2, 3.0];
    mr.PhaseGainRadian       = [-0.05, 0];
    mr.PhaseSaturation       = [0.8, 0.9];
    mr.PhaseSmoothness       = [3.2, 3.6];
    mr.OutputSaturationLevel = [1.4, 2.2];     % volts
    config.Factories.Receive.Simulation.Nonlinearity.ModifiedRappModel = mr;

    % --- Lookup table --------------------------------------------------
    % The documented default characterisation curve, extended with two
    % saturation rows exactly as on the transmit side: the original table
    % ended at +5 dBm input with the phase column still rising linearly, so
    % any hotter drive EXTRAPOLATED a runaway phase ramp. The appended rows
    % plateau both columns, as a real compressed front end does.
    lt = struct();
    lt.Table = [ ...
        -25,  5.16, -0.25;
        -20, 10.11, -0.47;
        -15, 15.11, -0.68;
        -10, 20.05, -0.89;
         -5, 24.79, -1.22;
          0, 27.64,  5.59;
          5, 28.49, 12.03;
         10, 28.90, 14.00;
         15, 29.00, 15.00 ];
    config.Factories.Receive.Simulation.Nonlinearity.LookupTable = lt;
end
