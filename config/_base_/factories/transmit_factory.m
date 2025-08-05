function config = transmit_factory()
    % transmit_factory - Transmitter factory configuration
    %
    % Defines transmitter factory function and transmitter types with their configurations.

    % --- TRANSMITTER TYPES ---

    % Simulation-based Transmitter (comprehensive RF impairment modeling)
    config.Factories.Transmit.Simulation.handle = 'csrd.blocks.physical.txRadioFront.TRFSimulator';
    config.Factories.Transmit.Simulation.Description = 'Simulation-based transmitter with configurable RF impairments';

    % --- IMPAIRMENT MODEL CONFIGURATIONS FOR SIMULATION TRANSMITTER ---
    % These are configuration parameters that will be used to configure the TRFSimulator instance
    % Each model represents different RF impairment scenarios

    % Ideal Configuration (no impairments)
    config.Factories.Transmit.Simulation.ImpairmentModels.Ideal.DCOffsetRange = [0, 0]; % No DC offset
    config.Factories.Transmit.Simulation.ImpairmentModels.Ideal.IqImbalanceConfig.A = [0, 0]; % No amplitude imbalance
    config.Factories.Transmit.Simulation.ImpairmentModels.Ideal.IqImbalanceConfig.P = [0, 0]; % No phase imbalance
    config.Factories.Transmit.Simulation.ImpairmentModels.Ideal.PhaseNoiseConfig.Level = [-Inf, -Inf]; % No phase noise
    config.Factories.Transmit.Simulation.ImpairmentModels.Ideal.PhaseNoiseConfig.FrequencyOffset = [10, 200]; % Hz
    config.Factories.Transmit.Simulation.ImpairmentModels.Ideal.MemoryLessNonlinearityConfig.LinearGain = [0, 0]; % Unity gain

    % Phase Noise Impairment Model
    config.Factories.Transmit.Simulation.ImpairmentModels.PhaseNoise.DCOffsetRange = [-60, -40]; % dB range
    config.Factories.Transmit.Simulation.ImpairmentModels.PhaseNoise.IqImbalanceConfig.A = [0, 1]; % dB
    config.Factories.Transmit.Simulation.ImpairmentModels.PhaseNoise.IqImbalanceConfig.P = [0, 1]; % degrees
    config.Factories.Transmit.Simulation.ImpairmentModels.PhaseNoise.PhaseNoiseConfig.Level = [-120, -100]; % dBc/Hz
    config.Factories.Transmit.Simulation.ImpairmentModels.PhaseNoise.PhaseNoiseConfig.FrequencyOffset = [10, 200]; % Hz
    config.Factories.Transmit.Simulation.ImpairmentModels.PhaseNoise.PhaseNoiseConfig.RandomStream = 'mt19937ar with seed';
    config.Factories.Transmit.Simulation.ImpairmentModels.PhaseNoise.PhaseNoiseConfig.Seed = 67;
    config.Factories.Transmit.Simulation.ImpairmentModels.PhaseNoise.MemoryLessNonlinearityConfig.LinearGain = [0, 5];

    % Power Amplifier Impairment Model (comprehensive RF front-end simulation)
    config.Factories.Transmit.Simulation.ImpairmentModels.PowerAmplifier.DCOffsetRange = [-60, -40]; % dB range

    % IQ Imbalance configuration
    config.Factories.Transmit.Simulation.ImpairmentModels.PowerAmplifier.IqImbalanceConfig.A = [0, 5]; % dB
    config.Factories.Transmit.Simulation.ImpairmentModels.PowerAmplifier.IqImbalanceConfig.P = [0, 5]; % degrees

    % Phase Noise configuration
    config.Factories.Transmit.Simulation.ImpairmentModels.PowerAmplifier.PhaseNoiseConfig.Level = [-150, -100]; % dBc/Hz
    config.Factories.Transmit.Simulation.ImpairmentModels.PowerAmplifier.PhaseNoiseConfig.FrequencyOffset = [10, 200]; % Hz
    config.Factories.Transmit.Simulation.ImpairmentModels.PowerAmplifier.PhaseNoiseConfig.RandomStream = 'mt19937ar with seed';
    config.Factories.Transmit.Simulation.ImpairmentModels.PowerAmplifier.PhaseNoiseConfig.Seed = 42;

    % Nonlinearity Models - Cubic Polynomial
    config.Factories.Transmit.Simulation.ImpairmentModels.PowerAmplifier.MemoryLessNonlinearityConfig.Method = 'Cubic polynomial';
    config.Factories.Transmit.Simulation.ImpairmentModels.PowerAmplifier.MemoryLessNonlinearityConfig.LinearGain = [0, 10];
    config.Factories.Transmit.Simulation.ImpairmentModels.PowerAmplifier.MemoryLessNonlinearityConfig.TOISpecification = 'IIP3';
    config.Factories.Transmit.Simulation.ImpairmentModels.PowerAmplifier.MemoryLessNonlinearityConfig.IIP3 = [20, 40];
    config.Factories.Transmit.Simulation.ImpairmentModels.PowerAmplifier.MemoryLessNonlinearityConfig.AMPMConversion = [10, 20];
    config.Factories.Transmit.Simulation.ImpairmentModels.PowerAmplifier.MemoryLessNonlinearityConfig.PowerLowerLimit = -Inf;
    config.Factories.Transmit.Simulation.ImpairmentModels.PowerAmplifier.MemoryLessNonlinearityConfig.PowerUpperLimit = Inf;
    config.Factories.Transmit.Simulation.ImpairmentModels.PowerAmplifier.MemoryLessNonlinearityConfig.ReferenceImpedance = 50;

    % IQ Imbalance Only Model
    config.Factories.Transmit.Simulation.ImpairmentModels.IQImbalance.DCOffsetRange = [-80, -60]; % dB range
    config.Factories.Transmit.Simulation.ImpairmentModels.IQImbalance.IqImbalanceConfig.A = [2, 5]; % dB
    config.Factories.Transmit.Simulation.ImpairmentModels.IQImbalance.IqImbalanceConfig.P = [3, 8]; % degrees
    config.Factories.Transmit.Simulation.ImpairmentModels.IQImbalance.PhaseNoiseConfig.Level = [-Inf, -Inf]; % No phase noise
    config.Factories.Transmit.Simulation.ImpairmentModels.IQImbalance.PhaseNoiseConfig.FrequencyOffset = [10, 200]; % Hz
    config.Factories.Transmit.Simulation.ImpairmentModels.IQImbalance.MemoryLessNonlinearityConfig.LinearGain = [0, 2];

    % DC Offset Only Model
    config.Factories.Transmit.Simulation.ImpairmentModels.DCOffset.DCOffsetRange = [-50, -30]; % dB range
    config.Factories.Transmit.Simulation.ImpairmentModels.DCOffset.IqImbalanceConfig.A = [0, 0.5]; % dB
    config.Factories.Transmit.Simulation.ImpairmentModels.DCOffset.IqImbalanceConfig.P = [0, 0.5]; % degrees
    config.Factories.Transmit.Simulation.ImpairmentModels.DCOffset.PhaseNoiseConfig.Level = [-Inf, -Inf]; % No phase noise
    config.Factories.Transmit.Simulation.ImpairmentModels.DCOffset.PhaseNoiseConfig.FrequencyOffset = [10, 200]; % Hz
    config.Factories.Transmit.Simulation.ImpairmentModels.DCOffset.MemoryLessNonlinearityConfig.LinearGain = [0, 1];

    % --- PARAMETER RANGES FOR SCENARIO GENERATION ---
    config.Factories.Transmit.Parameters.Antennas.Min = 1;
    config.Factories.Transmit.Parameters.Antennas.Max = 4;
    config.Factories.Transmit.Parameters.Power.Min = 10; % dBm
    config.Factories.Transmit.Parameters.Power.Max = 30; % dBm
    config.Factories.Transmit.Parameters.Height.Min = 10; % meters
    config.Factories.Transmit.Parameters.Height.Max = 100; % meters

    % Transmission behavior ranges
    config.Factories.Transmit.Behavior.StartTime.Min = 0.0; % seconds
    config.Factories.Transmit.Behavior.StartTime.Max = 0.1; % seconds
    config.Factories.Transmit.Behavior.Duration.Min = 0.05; % seconds
    config.Factories.Transmit.Behavior.Duration.Max = 0.2; % seconds
    config.Factories.Transmit.Behavior.Bandwidth.Min = 100e3; % Hz
    config.Factories.Transmit.Behavior.Bandwidth.Max = 1e6; % Hz

    % Configuration metadata
    config.Factories.Transmit.LogDetails = true;
    config.Factories.Transmit.Description = 'Transmitter factory configuration with simulation-based RF modeling';
end
