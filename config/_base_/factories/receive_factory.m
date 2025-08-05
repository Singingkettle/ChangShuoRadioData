function config = receive_factory()
    % receive_factory - Receiver factory configuration
    %
    % Defines receiver factory function and receiver types with their configurations.

    % --- RECEIVER TYPES ---

    % Simulation-based Receiver (comprehensive RF impairment modeling)
    config.Factories.Receive.Simulation.handle = 'csrd.blocks.physical.rxRadioFront.RRFSimulator';
    config.Factories.Receive.Simulation.Description = 'Simulation-based receiver with configurable RF impairments';

    % --- RECEIVER MODEL CONFIGURATIONS FOR SIMULATION RECEIVER ---
    % These are configuration parameters that will be used to configure the RRFSimulator instance
    % Each model represents different RF receiver scenarios

    % Ideal Demodulator (no impairments)
    config.Factories.Receive.Simulation.ReceiverModels.IdealDemod.DCOffsetRange = [0, 0]; % No DC offset
    config.Factories.Receive.Simulation.ReceiverModels.IdealDemod.IqImbalanceConfig.A = [0, 0]; % No amplitude imbalance
    config.Factories.Receive.Simulation.ReceiverModels.IdealDemod.IqImbalanceConfig.P = [0, 0]; % No phase imbalance
    config.Factories.Receive.Simulation.ReceiverModels.IdealDemod.ThermalNoiseConfig.NoiseTemperature = [0, 0]; % No thermal noise
    config.Factories.Receive.Simulation.ReceiverModels.IdealDemod.MemoryLessNonlinearityConfig.LinearGain = [0, 0]; % Unity gain
    config.Factories.Receive.Simulation.ReceiverModels.IdealDemod.MemoryLessNonlinearityConfig.Method = 'Cubic polynomial';
    config.Factories.Receive.Simulation.ReceiverModels.IdealDemod.MemoryLessNonlinearityConfig.TOISpecification = 'IIP3';
    config.Factories.Receive.Simulation.ReceiverModels.IdealDemod.MemoryLessNonlinearityConfig.IIP3 = [Inf, Inf]; % Ideal
    config.Factories.Receive.Simulation.ReceiverModels.IdealDemod.MemoryLessNonlinearityConfig.ReferenceImpedance = 50;

    % RRF Simulator (Comprehensive Receiver RF Front-End)
    config.Factories.Receive.Simulation.ReceiverModels.RRFSimulator.DCOffsetRange = [-150, -100]; % dB range

    % IQ Imbalance configuration
    config.Factories.Receive.Simulation.ReceiverModels.RRFSimulator.IqImbalanceConfig.A = [0, 5]; % dB
    config.Factories.Receive.Simulation.ReceiverModels.RRFSimulator.IqImbalanceConfig.P = [0, 5]; % degrees

    % Thermal Noise configuration
    config.Factories.Receive.Simulation.ReceiverModels.RRFSimulator.ThermalNoiseConfig.NoiseTemperature = [0, 290]; % Kelvin

    % Nonlinearity Models - Cubic Polynomial
    config.Factories.Receive.Simulation.ReceiverModels.RRFSimulator.MemoryLessNonlinearityConfig.Method = 'Cubic polynomial';
    config.Factories.Receive.Simulation.ReceiverModels.RRFSimulator.MemoryLessNonlinearityConfig.LinearGain = [0, 10];
    config.Factories.Receive.Simulation.ReceiverModels.RRFSimulator.MemoryLessNonlinearityConfig.TOISpecification = 'IIP3';
    config.Factories.Receive.Simulation.ReceiverModels.RRFSimulator.MemoryLessNonlinearityConfig.IIP3 = [20, 40];
    config.Factories.Receive.Simulation.ReceiverModels.RRFSimulator.MemoryLessNonlinearityConfig.AMPMConversion = [10, 20];
    config.Factories.Receive.Simulation.ReceiverModels.RRFSimulator.MemoryLessNonlinearityConfig.PowerLowerLimit = -Inf;
    config.Factories.Receive.Simulation.ReceiverModels.RRFSimulator.MemoryLessNonlinearityConfig.PowerUpperLimit = Inf;
    config.Factories.Receive.Simulation.ReceiverModels.RRFSimulator.MemoryLessNonlinearityConfig.ReferenceImpedance = 50;

    % Low Noise Amplifier Model
    config.Factories.Receive.Simulation.ReceiverModels.LNAReceiver.DCOffsetRange = [-120, -80]; % dB range
    config.Factories.Receive.Simulation.ReceiverModels.LNAReceiver.IqImbalanceConfig.A = [0, 2]; % dB (low imbalance)
    config.Factories.Receive.Simulation.ReceiverModels.LNAReceiver.IqImbalanceConfig.P = [0, 2]; % degrees (low imbalance)
    config.Factories.Receive.Simulation.ReceiverModels.LNAReceiver.ThermalNoiseConfig.NoiseTemperature = [50, 100]; % Kelvin (low noise)
    config.Factories.Receive.Simulation.ReceiverModels.LNAReceiver.MemoryLessNonlinearityConfig.Method = 'Cubic polynomial';
    config.Factories.Receive.Simulation.ReceiverModels.LNAReceiver.MemoryLessNonlinearityConfig.LinearGain = [20, 30]; % dB (high gain)
    config.Factories.Receive.Simulation.ReceiverModels.LNAReceiver.MemoryLessNonlinearityConfig.TOISpecification = 'IIP3';
    config.Factories.Receive.Simulation.ReceiverModels.LNAReceiver.MemoryLessNonlinearityConfig.IIP3 = [10, 20]; % dBm (good linearity)
    config.Factories.Receive.Simulation.ReceiverModels.LNAReceiver.MemoryLessNonlinearityConfig.AMPMConversion = [5, 10];
    config.Factories.Receive.Simulation.ReceiverModels.LNAReceiver.MemoryLessNonlinearityConfig.ReferenceImpedance = 50;

    % Phase Noise Limited Receiver
    config.Factories.Receive.Simulation.ReceiverModels.PhaseNoiseLimited.DCOffsetRange = [-100, -60]; % dB range
    config.Factories.Receive.Simulation.ReceiverModels.PhaseNoiseLimited.IqImbalanceConfig.A = [0.5, 3]; % dB
    config.Factories.Receive.Simulation.ReceiverModels.PhaseNoiseLimited.IqImbalanceConfig.P = [1, 5]; % degrees
    config.Factories.Receive.Simulation.ReceiverModels.PhaseNoiseLimited.ThermalNoiseConfig.NoiseTemperature = [200, 400]; % Kelvin (higher noise)
    config.Factories.Receive.Simulation.ReceiverModels.PhaseNoiseLimited.MemoryLessNonlinearityConfig.Method = 'Cubic polynomial';
    config.Factories.Receive.Simulation.ReceiverModels.PhaseNoiseLimited.MemoryLessNonlinearityConfig.LinearGain = [10, 20]; % dB
    config.Factories.Receive.Simulation.ReceiverModels.PhaseNoiseLimited.MemoryLessNonlinearityConfig.TOISpecification = 'IIP3';
    config.Factories.Receive.Simulation.ReceiverModels.PhaseNoiseLimited.MemoryLessNonlinearityConfig.IIP3 = [5, 15]; % dBm (moderate linearity)
    config.Factories.Receive.Simulation.ReceiverModels.PhaseNoiseLimited.MemoryLessNonlinearityConfig.AMPMConversion = [8, 15];
    config.Factories.Receive.Simulation.ReceiverModels.PhaseNoiseLimited.MemoryLessNonlinearityConfig.ReferenceImpedance = 50;

    % --- PARAMETER RANGES FOR SCENARIO GENERATION ---

    % Receiver parameter ranges
    config.Factories.Receive.Parameters.Antennas.Min = 1;
    config.Factories.Receive.Parameters.Antennas.Max = 4;
    config.Factories.Receive.Parameters.NoiseFigure.Min = 3; % dB
    config.Factories.Receive.Parameters.NoiseFigure.Max = 10; % dB
    config.Factories.Receive.Parameters.Height.Min = 10; % meters
    config.Factories.Receive.Parameters.Height.Max = 50; % meters
    config.Factories.Receive.Parameters.SampleRateRange.Min = 10e6; % Hz
    config.Factories.Receive.Parameters.SampleRateRange.Max = 50e6; % Hz
    config.Factories.Receive.Parameters.SensitivityRange.Min = -100; % dBm
    config.Factories.Receive.Parameters.SensitivityRange.Max = -80; % dBm

    % Available receiver types for scenario selection (now top-level types)
    config.Factories.Receive.Types = {'Simulation'};

    % Configuration metadata
    config.Factories.Receive.LogDetails = true;
    config.Factories.Receive.Description = 'Receiver factory configuration with simulation-based RF modeling';
end
