function config = getDefaultConfiguration(obj)
    % getDefaultConfiguration - Get default communication behavior configuration
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 getDefaultConfiguration 实现。
    config = struct();

    % Frequency allocation configuration.
    % Phase 2 (D7): only 'ReceiverCentric' is supported. The legacy
    % 'Optimized' / 'Random' strategies were thin wrappers and were
    % removed; setting Strategy to anything else now throws
    % CSRD:Scenario:UnsupportedFrequencyStrategy at execution time.
    config.FrequencyAllocation.Strategy = 'ReceiverCentric';
    config.FrequencyAllocation.MinSeparation = 100e3; % 100 kHz
    config.FrequencyAllocation.MaxOverlap = 0.1; % 10 % overlap allowed

    % Modulation selection configuration
    config.ModulationSelection.Strategy = 'Random';

    % Phase 8 regulatory spectrum planning defaults. The legacy random
    % path remains available only when Enable=false is set explicitly.
    config.Regulatory.Enable = true;
    config.Regulatory.Region.Policy = 'Fixed';
    config.Regulatory.Region.Fixed = 'CN';
    config.Regulatory.ServiceTier = 'Tier1';
    config.Regulatory.ExcludedServiceClasses = {'Radar','Radiolocation','Radionavigation'};
    config.Regulatory.MonitoringBand.Selection = 'WeightedByRegion';
    config.Regulatory.MaxBandwidthFractionOfSampleRate = 0.8;
    config.Regulatory.MinimumModulatorSampleRateHz = 250e3;

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
