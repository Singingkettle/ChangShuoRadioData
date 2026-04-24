function config = channel_factory()
    % channel_factory - Channel factory configuration
    %
    % Channel propagation models for CSRD framework.

    % --- CHANNEL MODELS CONFIGURATION ---

    % AWGN Channel (Additive White Gaussian Noise)
    config.Factories.Channel.ChannelModels.AWGN.handle = 'csrd.blocks.physical.channel.AWGNChannel';
    config.Factories.Channel.ChannelModels.AWGN.Config.SNRdB = 20; % Default SNR

    % Rayleigh Fading Channel
    config.Factories.Channel.ChannelModels.Rayleigh.handle = 'csrd.blocks.physical.channel.MIMO';
    config.Factories.Channel.ChannelModels.Rayleigh.Config.FadingDistribution = 'Rayleigh';
    config.Factories.Channel.ChannelModels.Rayleigh.Config.MaximumDopplerShift = 100; % Hz
    config.Factories.Channel.ChannelModels.Rayleigh.Config.PathDelays = 0; % seconds (flat fading)
    config.Factories.Channel.ChannelModels.Rayleigh.Config.AveragePathGains = 0; % dB
    config.Factories.Channel.ChannelModels.Rayleigh.Config.Seed = 73;

    % Rician Fading Channel
    config.Factories.Channel.ChannelModels.Rician.handle = 'csrd.blocks.physical.channel.MIMO';
    config.Factories.Channel.ChannelModels.Rician.Config.FadingDistribution = 'Rician';
    config.Factories.Channel.ChannelModels.Rician.Config.KFactor = 10; % dB
    config.Factories.Channel.ChannelModels.Rician.Config.MaximumDopplerShift = 50; % Hz
    config.Factories.Channel.ChannelModels.Rician.Config.PathDelays = [0, 1e-6]; % seconds
    config.Factories.Channel.ChannelModels.Rician.Config.AveragePathGains = [0, -3]; % dB
    config.Factories.Channel.ChannelModels.Rician.Config.Seed = 73;

    % Ray Tracing Channel (for 3D environment simulation)
    config.Factories.Channel.ChannelModels.RayTracing.handle = 'csrd.blocks.physical.channel.RayTracing';
    config.Factories.Channel.ChannelModels.RayTracing.Config.Environment = 'Urban';
    config.Factories.Channel.ChannelModels.RayTracing.Config.MaxReflections = 3;
    config.Factories.Channel.ChannelModels.RayTracing.Config.FrequencyCarrier = 2.4e9; % Hz
    config.Factories.Channel.ChannelModels.RayTracing.Config.NumRaysPerSource = 1000;
    config.Factories.Channel.ChannelModels.RayTracing.Config.PropagationModelConfig.Method = 'sbr';
    config.Factories.Channel.ChannelModels.RayTracing.Config.PropagationModelConfig.MaxNumReflections = 3;
    config.Factories.Channel.ChannelModels.RayTracing.Config.PropagationModelConfig.MaxNumDiffractions = 0;

    % Multi-Path Fading Channel (Frequency Selective)
    config.Factories.Channel.ChannelModels.MultiPath.handle = 'csrd.blocks.physical.channel.MIMO';
    config.Factories.Channel.ChannelModels.MultiPath.Config.FadingDistribution = 'Rayleigh';
    config.Factories.Channel.ChannelModels.MultiPath.Config.MaximumDopplerShift = 50; % Hz
    config.Factories.Channel.ChannelModels.MultiPath.Config.PathDelays = [0, 0.5e-6, 1e-6, 2e-6]; % seconds
    config.Factories.Channel.ChannelModels.MultiPath.Config.AveragePathGains = [0, -3, -6, -9]; % dB
    config.Factories.Channel.ChannelModels.MultiPath.Config.Seed = 73;

    % --- PARAMETER RANGES FOR SCENARIO GENERATION ---

    % Available channel types for scenario selection
    config.Factories.Channel.Types = {'AWGN', 'Rayleigh', 'Rician', 'RayTracing', 'MultiPath'};

    % SNR parameter ranges
    config.Factories.Channel.SNR.Min = 0; % dB
    config.Factories.Channel.SNR.Max = 30; % dB

    % --- PATH LOSS & LINK BUDGET PARAMETERS ---
    % Used by ChannelFactory to compute distance-based path loss and SNR
    config.Factories.Channel.LinkBudget.CarrierFrequency = 2.4e9;   % Hz (default carrier)
    config.Factories.Channel.LinkBudget.NoiseBandwidth = 50e6;       % Hz (receiver bandwidth)
    config.Factories.Channel.LinkBudget.NoiseFigure = 6;             % dB (receiver noise figure)
    config.Factories.Channel.LinkBudget.ThermalNoisePSD = -174;      % dBm/Hz (kTB at 290K)
    config.Factories.Channel.LinkBudget.MinDistance = 0.01;           % km (clamp to avoid infinite gain)
    config.Factories.Channel.LinkBudget.EnableDistanceBasedSNR = true;

    % Default model selection by scenario map profile
    config.Factories.Channel.DefaultModels.Statistical = 'AWGN';
    config.Factories.Channel.DefaultModels.OSMBuildings = 'RayTracing';
    config.Factories.Channel.DefaultModels.FlatTerrain = 'RayTracing';
    config.Factories.Channel.NoValidPathFallback = 'FreeSpaceAttenuation';

    % Configuration metadata
    config.Factories.Channel.LogDetails = true;
    config.Factories.Channel.Description = 'Channel propagation factory configuration with multiple channel models';
end
