function config = receive_factory()
    % receive_factory - Receiver factory configuration
    %
    % Defines receiver factory function and receiver types with a clear separation
    % between Antenna settings and RF impairments (Noise, IQ imbalance, Amplifier).

    % --- RECEIVER TYPES ---

    % Simulation-based Receiver (comprehensive RF impairment modeling)
    config.Factories.Receive.Simulation.handle = 'csrd.blocks.physical.rxRadioFront.RRFSimulator';
    config.Factories.Receive.Simulation.Description = 'Simulation-based receiver with configurable antenna and RF impairments';

    % Antenna settings
    config.Factories.Receive.Simulation.Antenna.Types = {'Omni', 'Parabolic', 'Array'};
    % Omni: simple gain/height ranges
    config.Factories.Receive.Simulation.Antenna.Omni.GainRange = [0, 6]; % dBi
    config.Factories.Receive.Simulation.Antenna.Omni.HeightRange = [5, 30]; % m
    % Parabolic: dish-based
    config.Factories.Receive.Simulation.Antenna.Parabolic.DishDiameterRange = [0.3, 5.0]; % m
    config.Factories.Receive.Simulation.Antenna.Parabolic.EfficiencyRange = [0.45, 0.7]; % 0-1
    config.Factories.Receive.Simulation.Antenna.Parabolic.GainRange = [20, 40]; % dBi (approx)
    % Array: MIMO-style
    config.Factories.Receive.Simulation.Antenna.Array.NumElementsRange = [2, 8];
    config.Factories.Receive.Simulation.Antenna.Array.ElementSpacingRange = [0.4, 0.6]; % lambda units
    config.Factories.Receive.Simulation.Antenna.Array.GeometryOptions = {'ULA', 'URA'};

    % Impairment settings

    config.Factories.Receive.Simulation.DCOffset.Range = [-150, -100];

    config.Factories.Receive.Simulation.IqImbalance.A = [0, 5]; % dB
    config.Factories.Receive.Simulation.IqImbalance.P = [0, 5]; % deg

    config.Factories.Receive.Simulation.Noise.NoiseTemperature = [0, 290]; % K

    % Cubic Polynomial Amplifier
    config.Factories.Receive.Simulation.Amplifier.CubicPolynomial.LinearGain = [0, 10];
    config.Factories.Receive.Simulation.Amplifier.CubicPolynomial.TOISpecification = {'IIP3', 'OIP3', 'IP1dB', 'OP1dB', 'IPsat', 'OPsat'};
    config.Factories.Receive.Simulation.Amplifier.CubicPolynomial.IIP3 = [20, 40];
    config.Factories.Receive.Simulation.Amplifier.CubicPolynomial.OIP3 = [20, 40];
    config.Factories.Receive.Simulation.Amplifier.CubicPolynomial.IP1dB = [20, 40];
    config.Factories.Receive.Simulation.Amplifier.CubicPolynomial.OP1dB = [20, 40];
    config.Factories.Receive.Simulation.Amplifier.CubicPolynomial.IPsat = [20, 40];
    config.Factories.Receive.Simulation.Amplifier.CubicPolynomial.OPsat = [20, 40];
    config.Factories.Receive.Simulation.Amplifier.PowerLowerLimit = -Inf;
    config.Factories.Receive.Simulation.Amplifier.PowerUpperLimit = Inf;

    % Available receiver types for scenario selection (top-level types)
    config.Factories.Receive.Types = {'Simulation'};

    % Configuration metadata
    config.Factories.Receive.LogDetails = true;
    config.Factories.Receive.Description = 'Receiver factory configuration (antenna + RF impairments)';
end
