classdef TRFSimulator < matlab.System
    % https://www.mathworks.com/help/comm/ug/end-to-end-qam-simulation-with-rf-impairments-and-corrections.html
    % The simulation of transmitter is based on the function
    % "QAMwithRFImpairmentsSim" of the aforementioned example.
    % Where the txGain is not defined in our code.
    % Additionally, we referenced the USRP zero-IF design architecture to implement the transmitter simulation
    % https://kb.ettus.com/UHD
    % https://zhuanlan.zhihu.com/p/24217098
    % https://www.mathworks.com/help/simrf/ug/modeling-an-rf-mmwave-transmitter-with-hybrid-beamforming.html
    % =====================================================================
    % Regarding the transmitter simulation, the RF impairments are mainly based on the paper:
    % "ORACLE: Optimized Radio clAssification through Convolutional neuraL nEtworks"
    % and the USRP hardware diagram from: https://kb.ettus.com/UHD
    % The two key parameters of DUC (Digital Up-Converter) and their effects:
    % https://blog.csdn.net/u010565765/article/details/54925659/
    % The DUC values mainly reference this link:
    % https://www.mathworks.com/matlabcentral/answers/772293-passband-ripple-and-stopband-attenuation
    % =====================================================================

    properties
        % Master clock rate, specified as a scalar in Hz. The master clock
        % rate is the A/D and D/A clock rate. The valid range of values for
        % this property depends on the radio platform that is connected.
        % This value depends on the ettus usrp devices.
        % Please refer:
        % https://www.mathworks.com/help/comm/usrpradio/ug/sdrutransmitter.html
        MasterClockRate (1, 1) {mustBePositive, mustBeReal} = 184.32e6
        DCOffset {mustBeReal} = -50
        TxPowerDb (1, 1) {mustBeReal} = 50 % Desired transmission power in dBm (default: 10 dBm)
        CarrierFrequency (1, 1) {mustBeReal} = 2.4e9
        BandWidth (1, 1) {mustBeReal} = 20e6
        SampleRate (1, 1) {mustBeReal} = 20e6

        SiteConfig = false
        IqImbalanceConfig struct
        PhaseNoiseConfig struct
        MemoryLessNonlinearityConfig struct
    end

    properties (Access = protected)

        IQImbalance
        PhaseNoise
        MemoryLessNonlinearity
        InterpolationFactor
        DUC

    end

    methods (Access = protected)

        function DUC = genDUC(obj)
            % Generates Digital Up-Converter (DUC) object
            % Returns:
            %   DUC: Digital Up-Converter object configured with interpolation factor,
            %        sample rate, bandwidth, and carrier frequency settings
            obj.InterpolationFactor = ceil(obj.MasterClockRate / obj.SampleRate);
            % Check if InterpolationFactor is prime
            if obj.InterpolationFactor == 1
                obj.InterpolationFactor = 4;
            else

                while isprime(obj.InterpolationFactor)
                    obj.InterpolationFactor = obj.InterpolationFactor +1;
                end

            end

            obj.MasterClockRate = obj.InterpolationFactor * obj.SampleRate;
            bw = obj.BandWidth;
            DUC = dsp.DigitalUpConverter( ...
                InterpolationFactor = obj.InterpolationFactor, ...
                SampleRate = obj.SampleRate, ...
                Bandwidth = bw, ...
                PassbandRipple = 0.2, ...
                StopbandAttenuation = 40, ...
                CenterFrequency = obj.CarrierFrequency);
        end

        function IQImbalance = genIqImbalance(obj)
            % Generates IQ imbalance function handle
            % Returns:
            %   IQImbalance: Function handle that applies amplitude and phase imbalance
            %                using the configured parameters
            IQImbalance = @(x)iqimbal(x, ...
                obj.IqImbalanceConfig.A, ...
                obj.IqImbalanceConfig.P);
        end

        function PhaseNoise = genPhaseNoise(obj)
            % https://www.mathworks.com/help/comm/ref/comm.phasenoise-system-object.html
            PhaseNoise = comm.PhaseNoise( ...
                Level = obj.PhaseNoiseConfig.Level, ...
                FrequencyOffset = obj.PhaseNoiseConfig.FrequencyOffset, ...
                SampleRate = obj.SampleRate);

            if isfield(obj.PhaseNoiseConfig, 'RandomStream')

                if strcmp(obj.PhaseNoiseConfig.RandomStream, ...
                    'mt19936ar with seed')
                    PhaseNoise.RandomStream = "mt19937ar with seed";
                    PhaseNoise.Seed = obj.PhaseNoiseConfig.Seed;
                end

            end

        end

        function MemoryLessNonlinearity = genMemoryLessNonlinearity(obj)

            if strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Cubic polynomial')
                MemoryLessNonlinearity = comm.MemorylessNonlinearity( ...
                    Method = 'Cubic polynomial', ...
                    LinearGain = obj.MemoryLessNonlinearityConfig.LinearGain, ...
                    TOISpecification = obj.MemoryLessNonlinearityConfig.TOISpecification);

                if strcmp(obj.MemoryLessNonlinearityConfig.TOISpecification, 'IIP3')
                    MemoryLessNonlinearity.OIP3 = obj.MemoryLessNonlinearityConfig.IIP3;
                elseif strcmp(obj.MemoryLessNonlinearityConfig.TOISpecification, 'OIP3')
                    MemoryLessNonlinearity.OIP3 = obj.MemoryLessNonlinearityConfig.OIP3;
                elseif strcmp(obj.MemoryLessNonlinearityConfig.TOISpecification, 'IP1dB')
                    MemoryLessNonlinearity.IP1dB = obj.MemoryLessNonlinearityConfig.IP1dB;
                elseif strcmp(obj.MemoryLessNonlinearityConfig.TOISpecification, 'OP1dB')
                    MemoryLessNonlinearity.OP1dB = obj.MemoryLessNonlinearityConfig.OP1dB;
                elseif strcmp(obj.MemoryLessNonlinearityConfig.TOISpecification, 'IPsat')
                    MemoryLessNonlinearity.IPsat = obj.MemoryLessNonlinearityConfig.IPsat;
                elseif strcmp(obj.MemoryLessNonlinearityConfig.TOISpecification, 'OPsat')
                    MemoryLessNonlinearity.OPsat = obj.MemoryLessNonlinearityConfig.OPsat;
                end

                MemoryLessNonlinearity.AMPMConversion = obj.MemoryLessNonlinearityConfig.AMPMConversion;
                MemoryLessNonlinearity.PowerLowerLimit = obj.MemoryLessNonlinearityConfig.PowerLowerLimit;
                MemoryLessNonlinearity.PowerUpperLimit = obj.MemoryLessNonlinearityConfig.PowerUpperLimit;
            elseif strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Hyperbolic tangent')
                MemoryLessNonlinearity = comm.MemorylessNonlinearity( ...
                    Method = 'Hyperbolic tangent', ...
                    LinearGain = obj.MemoryLessNonlinearityConfig.LinearGain, ...
                    IIP3 = obj.MemoryLessNonlinearityConfig.IIP3);
                MemoryLessNonlinearity.AMPMConversion = obj.MemoryLessNonlinearityConfig.AMPMConversion;
                MemoryLessNonlinearity.PowerLowerLimit = obj.MemoryLessNonlinearityConfig.PowerLowerLimit;
                MemoryLessNonlinearity.PowerUpperLimit = obj.MemoryLessNonlinearityConfig.PowerUpperLimit;

            elseif strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Saleh model') || strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Ghorbani model')
                MemoryLessNonlinearity = comm.MemorylessNonlinearity( ...
                    Method = obj.MemoryLessNonlinearityConfig.Method, ...
                    InputScaling = obj.MemoryLessNonlinearityConfig.InputScaling, ...
                    AMAMParameters = obj.MemoryLessNonlinearityConfig.AMAMParameters, ...
                    AMPMParameters = obj.MemoryLessNonlinearityConfig.AMPMParameters, ...
                    OutputScaling = obj.MemoryLessNonlinearityConfig.OutputScaling);
            elseif strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Modified Rapp model')
                MemoryLessNonlinearity = comm.MemorylessNonlinearity( ...
                    Method = 'Modified Rapp model', ...
                    LinearGain = obj.MemoryLessNonlinearityConfig.LinearGain, ...
                    Smoothness = obj.MemoryLessNonlinearityConfig.Smoothness, ...
                    PhaseGainRadian = obj.MemoryLessNonlinearityConfig.PhaseGainRadian, ...
                    PhaseSaturation = obj.MemoryLessNonlinearityConfig.PhaseSaturation, ...
                    PhaseSmoothness = obj.MemoryLessNonlinearityConfig.PhaseSmoothness, ...
                    OutputSaturationLevel = obj.MemoryLessNonlinearityConfig.OutputSaturationLevel);
            elseif strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Lookup table')
                MemoryLessNonlinearity = comm.MemorylessNonlinearity( ...
                    Method = 'Look table', ...
                    Table = obj.MemoryLessNonlinearityConfig.Table);
            end

            MemoryLessNonlinearity.ReferenceImpedance = obj.MemoryLessNonlinearityConfig.ReferenceImpedance;
        end

        function setupImpl(obj)
            % Initialize system object
            % Sets up all necessary components including IQ imbalance, phase noise,
            % nonlinearity, and digital up-converter
            obj.IQImbalance = obj.genIqImbalance;
            obj.PhaseNoise = obj.genPhaseNoise;
            obj.MemoryLessNonlinearity = obj.genMemoryLessNonlinearity;
            obj.DUC = obj.genDUC;
        end

        function y = DUCH(obj, x)
            % Applies Digital Up-Conversion to input signal
            % Args:
            %   x: Input baseband signal
            % Returns:
            %   y: Up-converted signal
            y = obj.DUC(x);
        end

        function out = stepImpl(obj, x)
            % Main processing function that applies RF impairments and up-conversion
            % Args:
            %   x: Input structure containing baseband signal and configuration
            % Returns:
            %   out: Structure containing processed signal and updated configuration

            % Add impairments
            y = obj.IQImbalance(x.data);
            y = y + 10 ^ (obj.DCOffset / 10);
            y = obj.PhaseNoise(y);
            y = obj.MemoryLessNonlinearity(y);

            % Transform the baseband to passband
            if x.NumTransmitAntennas > 1
                % Process multiple antennas in parallel using arrayfun
                y = arrayfun(@(col) obj.DUC(y(:, col)), 1:x.NumTransmitAntennas, 'UniformOutput', false);
                y = cat(2, y{:});
            else
                y = obj.DUC(y);
            end

            % Set the transmitter power for IQ signal
            signalDuration = size(y, 1) / obj.MasterClockRate; % Signal duration in seconds
            signalPower = sum(abs(y(:, 1)) .^ 2) / (size(y, 1)); % Average power per sample
            % Convert dBm to linear power (Watts) and scale the signal
            % 10^(dBm/10)/1000 converts dBm to Watts
            scalingFactor = sqrt((10 ^ (obj.TxPowerDb / 10) / 1000) / (signalPower * signalDuration)) * sqrt(signalDuration);
            y = y * scalingFactor;

            out = x;
            out.data = y;
            out.DCOffset = obj.DCOffset;
            out.IqImbalanceConfig = obj.IqImbalanceConfig;
            out.MemoryLessNonlinearityConfig = obj.MemoryLessNonlinearityConfig;
            out.PhaseNoiseConfig = obj.PhaseNoiseConfig;
            out.SDRInterpolationFactor = obj.InterpolationFactor;
            out.SampleRate = obj.MasterClockRate;
            out.SamplePerFrame = size(y, 1);
            out.TimeDuration = out.SamplePerFrame / out.SampleRate;
            out.CarrierFrequency = x.CarrierFrequency;
            out.TxSiteConfig = obj.SiteConfig;
            out.SDRMode = "Zero-IF Receiver";
        end

    end

    methods

        function obj = TRFSimulator(varargin)
            % Constructor for TRFSimulator
            % Args:
            %   varargin: Name-value pairs for setting object properties
            setProperties(obj, nargin, varargin{:});
        end

    end

end
