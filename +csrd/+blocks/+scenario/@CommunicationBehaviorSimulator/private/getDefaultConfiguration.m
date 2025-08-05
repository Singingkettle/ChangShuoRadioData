function config = getDefaultConfiguration(obj)
    % getDefaultConfiguration - Get default communication behavior configuration
    config = struct();

    % Frequency allocation configuration
    config.FrequencyAllocation.Strategy = 'ReceiverCentric';
    config.FrequencyAllocation.MinSeparation = 100e3; % 100 kHz
    config.FrequencyAllocation.MaxOverlap = 0.1; % 10 % overlap allowed

    % Modulation selection configuration
    config.ModulationSelection.Strategy = 'Random';

    % Transmission pattern configuration
    config.TransmissionPattern.DefaultType = 'Continuous';

    % Power control configuration
    config.PowerControl.Strategy = 'FixedPower';
    config.PowerControl.DefaultPower = 20; % dBm
    config.PowerControl.MaxPower = 30; % dBm

    % Interference management
    config.InterferenceManagement.EnableCollisionAvoidance = true;
    config.InterferenceManagement.InterferenceThreshold = -80; % dBm
end
