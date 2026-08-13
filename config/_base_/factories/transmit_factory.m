function config = transmit_factory()
    %TRANSMIT_FACTORY Transmitter factory configuration (v0.4 deep refactor).
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
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

    config.Factories.Transmit.Simulation.handle = ...
        'csrd.blocks.physical.txRadioFront.TRFSimulator';

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
    % PHYSICALIZED (construction audit). The previous ranges produced an
    % unphysical PA: AMPMConversion U(10,20) deg/dB (real Class-AB PAs sit at
    % 1-3 deg/dB near compression, <5 worst case) applied from PowerLowerLimit
    % as low as -40 dBm with NO upper clamp, against a ~+13 dBm unit-power/50-ohm
    % drive -- i.e. 150-400 degrees of parasitic phase modulation across the
    % envelope. Measured effect on the dataset (11492 sources + the frozen
    % docs/baselines/2026-08-trf-widening-before.csv anchor): QAM occupied
    % bandwidth up to 2.9x its clean value, and 350 emitters reading ~0.98 of the
    % whole 50 MHz capture band. Constant-envelope families showed no widening
    % under any method, which is what pinned the cause to the envelope-dependent
    % PA terms rather than phase noise / DC / IQ.
    %
    % The new ranges keep the distortion VISIBLE but physical:
    %   AMPMConversion  [0.5, 4.0]  -- lower bound deliberately nonzero so every
    %                                  draw retains AM/PM diversity.
    %   PowerLowerLimit [2, 10] dBm -- AM/PM engages only near compression, as in
    %                                  a real device, instead of across the whole
    %                                  envelope dynamic range.
    %   PowerUpperLimit [16, 22] dBm - finite clamp where the envelope peaks live
    %                                  (QAM PAPR 6-8 dB over the +13 dBm mean).
    %                                  Kept DISJOINT from PowerLowerLimit so a
    %                                  draw can never invert the window
    %                                  (comm.MemorylessNonlinearity errors on
    %                                  Upper <= Lower); the factory asserts this.
    %   TOI [26, 40] dBm            -- IM3 shoulder ~ -2*(IIP3 - Pin) lands at
    %                                  -26..-54 dBc, i.e. 0.05-0.5% out-of-band
    %                                  power: the 99%-power bandwidth stays near
    %                                  the clean value while ACLR still spans a
    %                                  ~28 dB diversity range. The old [20,40]
    %                                  floor allowed -14 dBc shoulders (3-4% of
    %                                  total power out of band), which alone drags
    %                                  the ITU 99% edge past (1+beta)*Rs.
    cp = struct();
    cp.LinearGain = [0, 10];
    cp.TOISpecifications = { ...
        'IIP3', 'OIP3', 'IP1dB', 'OP1dB', 'IPsat', 'OPsat' };
    cp.IIP3  = [26, 40];
    cp.OIP3  = [26, 40];
    cp.IP1dB = [26, 40];
    cp.OP1dB = [26, 40];
    cp.IPsat = [26, 40];
    cp.OPsat = [26, 40];
    cp.AMPMConversion  = [0.5, 4.0];
    cp.PowerLowerLimit = [2, 10];
    cp.PowerUpperLimit = [16, 22];
    config.Factories.Transmit.Simulation.Nonlinearity.CubicPolynomial = cp;

    % --- Hyperbolic tangent -----------------------------------------
    % Same physicalization as CubicPolynomial (this Method was the worst
    % offender: hard tanh limiting plus the unbounded AM/PM gave QAM a median
    % 2.374x bandwidth widening).
    ht = struct();
    ht.LinearGain      = [0, 10];
    ht.IIP3            = [26, 40];
    ht.AMPMConversion  = [0.5, 4.0];
    ht.PowerLowerLimit = [2, 10];
    ht.PowerUpperLimit = [16, 22];
    config.Factories.Transmit.Simulation.Nonlinearity.HyperbolicTangent = ht;

    % --- Saleh model ------------------------------------------------
    % The alpha/beta curve parameters are the published Saleh model and stay
    % untouched. The defect was the OPERATING POINT: with InputScaling ~0 dB the
    % unit-power drive sits PAST the Saleh AM/AM fold-over (r ~ 0.93 for
    % beta ~ 1.15), where the curve is non-monotonic -- that is what crushed
    % DSBAM/VSBAM sidebands to ~0.086x (an amplitude-modulated signal driven past
    % fold-over comes out nearly constant-envelope). InputScaling [-12, -4] dB
    % keeps the envelope on the monotonic segment with occasional peak
    % compression, which is what a real operator does with a Saleh-class TWT.
    % OutputScaling is irrelevant here: Step 7 of the TRF renormalizes power.
    sm = struct();
    sm.InputScaling          = [-12, -4];
    sm.AMAMParametersAlpha   = [2.157, 2.159];
    sm.AMAMParametersBeta    = [1.151, 1.152];
    sm.AMPMParametersAlpha   = [4.003, 4.004];
    sm.AMPMParametersBeta    = [9.103, 9.105];
    sm.OutputScaling         = [-1, 1];
    config.Factories.Transmit.Simulation.Nonlinearity.SalehModel = sm;

    % --- Ghorbani model ---------------------------------------------
    % Same operating-point fix as Saleh: canonical curve parameters kept, the
    % drive backed off the saturating region via InputScaling.
    gm = struct();
    gm.InputScaling          = [-12, -4];
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
    % Smoothness p < 1 is not a physical SSPA (typical p is 1.5-3; p = 0.5 makes
    % compression bleed across the whole dynamic range instead of localizing near
    % saturation). OutputSaturationLevel [1.4, 2.2] V gives the unit-power drive
    % 3-7 dB of envelope headroom instead of hard-clipping every peak, and
    % PhaseGainRadian is brought to the near-zero AM/PM a real SSPA exhibits.
    mr = struct();
    mr.LinearGain            = [0, 10];
    mr.Smoothness            = [1.2, 3.0];
    mr.PhaseGainRadian       = [-0.05, 0];
    mr.PhaseSaturation       = [0.8, 0.9];
    mr.PhaseSmoothness       = [3.2, 3.6];
    mr.OutputSaturationLevel = [1.4, 2.2];
    config.Factories.Transmit.Simulation.Nonlinearity.ModifiedRappModel = mr;

    % --- Lookup table -----------------------------------------------
    % The original table ended at +5 dBm input, so the ~+13 dBm unit-power drive
    % EXTRAPOLATED the phase-shift column (already +12 deg at +5 dBm and rising
    % linearly). The two appended rows saturate both columns so any drive above
    % +5 dBm sees a plateau, as a real compressed PA does, instead of an
    % extrapolated runaway phase ramp.
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
    config.Factories.Transmit.Simulation.Nonlinearity.LookupTable = lt;
end
