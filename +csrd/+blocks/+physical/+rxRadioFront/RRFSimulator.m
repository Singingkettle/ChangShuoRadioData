classdef RRFSimulator < matlab.System
    % RRFSimulator: Radio Receiver Front-end Simulator
    % Simulates various RF impairments and processing stages of a radio receiver front-end
    % including nonlinear amplification, thermal noise, IQ imbalance, DC offset, etc.
    %
    % The simulator processes input signals through multiple stages to model real-world
    % RF receiver behavior and impairments.

    properties
        % Configuration parameters for the receiver
        StartTime (1, 1) {mustBeGreaterThanOrEqual(StartTime, 0), mustBeReal} = 0 % Start time of simulation in seconds
        DecimationFactor (1, 1) {mustBePositive, mustBeReal} = 1 % Decimation factor
        NumReceiveAntennas (1, 1) {mustBePositive, mustBeReal} = 1 % Number of receive antennas
        BandWidth {mustBePositive, mustBeReal, mustBeInteger} = 20e6 % Receiver bandwidth in Hz (updated default)
        CenterFrequency (1, 1) {mustBeReal, mustBeInteger} = 0 % Center frequency in Hz (now allows 0 for baseband-centric)
        SampleRateOffset (1, 1) {mustBeReal} = 0 % Sample rate offset affecting crystal frequency and sampling
        TimeDuration (1, 1) {mustBePositive, mustBeReal} = 0.1 % Total simulation duration in seconds
        MasterClockRate (1, 1) {mustBePositive, mustBeReal} = 20e6 % Master clock rate in Hz (updated default)
        DCOffset {mustBeReal} = -50 % DC offset in dB

        % NEW: Enable receiver-centric frequency processing
        UseReceiverCentricMode (1, 1) logical = true % Use new frequency allocation approach

        % Configuration structs for RF impairments
        SiteConfig struct % Configuration for receiver site parameters
        IqImbalanceConfig struct % Configuration for IQ imbalance parameters
        MemoryLessNonlinearityConfig struct % Configuration for nonlinearity parameters
        ThermalNoiseConfig struct % Configuration for thermal noise parameters
    end

    properties (Access = protected)
        % Internal properties used during signal processing
        SamplePerFrame % Number of samples per frame
        FrequencyOffset % Frequency offset value
        LowerPowerAmplifier % Nonlinear amplifier object
        FrequencyShifter % Doppler shift object
        ThermalNoise % Thermal noise generator object
        PhaseNoise % Phase noise generator object
        IQImbalance % IQ imbalance object
        AGC % Automatic Gain Control object
        SNR % Signal-to-Noise Ratio
        SampleShifter % Sample rate offset object
        BandpassFilter % Bandpass filter object
    end

    methods (Access = private)

        function IQImbalance = genIqImbalance(obj)
            % Generates IQ imbalance function handle
            % Returns:
            %   IQImbalance: Function handle that applies amplitude (A) and phase (P) imbalance
            %                to the input signal using the iqimbal function
            IQImbalance = @(x)iqimbal(x, ...
                obj.IqImbalanceConfig.A, ...
                obj.IqImbalanceConfig.P);
        end

        function LowerNoiseAmplifier = genLowerPowerAmplifier(obj)
            % Generates and configures the nonlinear amplifier object
            % Returns:
            %   LowerNoiseAmplifier: Configured nonlinear amplifier object based on specified method
            %                        Supports multiple nonlinearity models:
            %                        - Cubic polynomial
            %                        - Hyperbolic tangent
            %                        - Saleh model
            %                        - Ghorbani model
            %                        - Modified Rapp model
            %                        - Lookup table

            if strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Cubic polynomial')
                % Configure cubic polynomial model
                LowerNoiseAmplifier = comm.MemorylessNonlinearity( ...
                    Method = 'Cubic polynomial', ...
                    LinearGain = obj.MemoryLessNonlinearityConfig.LinearGain, ...
                    TOISpecification = obj.MemoryLessNonlinearityConfig.TOISpecification);

                % Set appropriate TOI specification parameter
                if strcmp(obj.MemoryLessNonlinearityConfig.TOISpecification, 'IIP3')
                    LowerNoiseAmplifier.IIP3 = obj.MemoryLessNonlinearityConfig.IIP3;
                elseif strcmp(obj.MemoryLessNonlinearityConfig.TOISpecification, 'OIP3')
                    LowerNoiseAmplifier.OIP3 = obj.MemoryLessNonlinearityConfig.OIP3;
                elseif strcmp(obj.MemoryLessNonlinearityConfig.TOISpecification, 'IP1dB')
                    LowerNoiseAmplifier.IP1dB = obj.MemoryLessNonlinearityConfig.IP1dB;
                elseif strcmp(obj.MemoryLessNonlinearityConfig.TOISpecification, 'OP1dB')
                    LowerNoiseAmplifier.OP1dB = obj.MemoryLessNonlinearityConfig.OP1dB;
                elseif strcmp(obj.MemoryLessNonlinearityConfig.TOISpecification, 'IPsat')
                    LowerNoiseAmplifier.IPsat = obj.MemoryLessNonlinearityConfig.IPsat;
                elseif strcmp(obj.MemoryLessNonlinearityConfig.TOISpecification, 'OPsat')
                    LowerNoiseAmplifier.OPsat = obj.MemoryLessNonlinearityConfig.OPsat;
                end

                % Set additional parameters for cubic polynomial model
                LowerNoiseAmplifier.AMPMConversion = obj.MemoryLessNonlinearityConfig.AMPMConversion;
                LowerNoiseAmplifier.PowerLowerLimit = obj.MemoryLessNonlinearityConfig.PowerLowerLimit;
                LowerNoiseAmplifier.PowerUpperLimit = obj.MemoryLessNonlinearityConfig.PowerUpperLimit;

            elseif strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Hyperbolic tangent')
                % Configure hyperbolic tangent model
                LowerNoiseAmplifier = comm.MemorylessNonlinearity( ...
                    Method = 'Hyperbolic tangent', ...
                    LinearGain = obj.MemoryLessNonlinearityConfig.LinearGain, ...
                    IIP3 = obj.MemoryLessNonlinearityConfig.IIP3);
                LowerNoiseAmplifier.AMPMConversion = obj.MemoryLessNonlinearityConfig.AMPMConversion;
                LowerNoiseAmplifier.PowerLowerLimit = obj.MemoryLessNonlinearityConfig.PowerLowerLimit;
                LowerNoiseAmplifier.PowerUpperLimit = obj.MemoryLessNonlinearityConfig.PowerUpperLimit;

            elseif strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Saleh model') || strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Ghorbani model')
                % Configure Saleh or Ghorbani model
                LowerNoiseAmplifier = comm.MemorylessNonlinearity( ...
                    Method = obj.MemoryLessNonlinearityConfig.Method, ...
                    InputScaling = obj.MemoryLessNonlinearityConfig.InputScaling, ...
                    AMAMParameters = obj.MemoryLessNonlinearityConfig.AMAMParameters, ...
                    AMPMParameters = obj.MemoryLessNonlinearityConfig.AMPMParameters, ...
                    OutputScaling = obj.MemoryLessNonlinearityConfig.OutputScaling);
            elseif strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Modified Rapp model')
                % Configure Modified Rapp model
                LowerNoiseAmplifier = comm.MemorylessNonlinearity( ...
                    Method = 'Modified Rapp model', ...
                    LinearGain = obj.MemoryLessNonlinearityConfig.LinearGain, ...
                    Smoothness = obj.MemoryLessNonlinearityConfig.Smoothness, ...
                    PhaseGainRadian = obj.MemoryLessNonlinearityConfig.PhaseGainRadian, ...
                    PhaseSaturation = obj.MemoryLessNonlinearityConfig.PhaseSaturation, ...
                    PhaseSmoothness = obj.MemoryLessNonlinearityConfig.PhaseSmoothness, ...
                    OutputSaturationLevel = obj.MemoryLessNonlinearityConfig.OutputSaturationLevel);
            elseif strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Lookup table')
                % Configure Lookup table model
                LowerNoiseAmplifier = comm.MemorylessNonlinearity( ...
                    Method = 'Lookup table', ...
                    Table = obj.MemoryLessNonlinearityConfig.Table);
            else
                warning('RRFSimulator:UnknownNonlinearityMethod', ...
                    'Unknown nonlinearity method: %s. Using default Cubic polynomial.', ...
                    obj.MemoryLessNonlinearityConfig.Method);
                LowerNoiseAmplifier = comm.MemorylessNonlinearity(Method = 'Cubic polynomial');
            end

            % Set reference impedance for all models
            LowerNoiseAmplifier.ReferenceImpedance = obj.MemoryLessNonlinearityConfig.ReferenceImpedance;
        end

        function ThermalNoise = genThermalNoise(obj)
            % Generates thermal noise object with specified parameters
            % Returns:
            %   ThermalNoise: Configured thermal noise generator object
            ThermalNoise = comm.ThermalNoise( ...
                NoiseMethod = "Noise temperature", ...
                NoiseTemperature = obj.ThermalNoiseConfig.NoiseTemperature, ...
                SampleRate = obj.MasterClockRate);
        end

        function SampleShifter = genSampleShifter(obj)
            % Generates sample rate offset object
            % Offset is in ppm (parts per million)
            SampleShifter = comm.SampleRateOffset( ...
                Offset = obj.SampleRateOffset);
        end

        function bpFilt = genBandpassFilter(obj)
            % Generates bandpass filter object
            % Returns:
            %   bpFilt: Bandpass filter object configured with center frequency and bandwidth
            bpFilt = designfilt('bandpassiir', ...
                FilterOrder = 8, ...
                HalfPowerFrequency1 = obj.CenterFrequency - obj.BandWidth / 2, ...
                HalfPowerFrequency2 = obj.CenterFrequency + obj.BandWidth / 2, ...
                SampleRate = obj.MasterClockRate);
        end

    end

    methods

        function obj = RRFSimulator(varargin)
            % Constructor for RRFSimulator
            % Args:
            %   varargin: Name-value pairs for setting object properties
            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function setupImpl(obj, ~)
            % Initialize all RF impairment components before processing
            obj.LowerPowerAmplifier = obj.genLowerPowerAmplifier;
            obj.SampleShifter = obj.genSampleShifter;
            obj.ThermalNoise = obj.genThermalNoise;
            obj.IQImbalance = obj.genIqImbalance;
        end

        function outputSignal = stepImpl(obj, inputSignal)
            % stepImpl - Apply RF impairments to pre-combined signal
            %
            % Refactored receiver-centric approach:
            % Signal combination is now done upstream in processReceiverProcessing.
            % This method focuses solely on applying receiver RF impairments:
            %   1. LNA nonlinearity
            %   2. Thermal noise (AWGN)
            %   3. IQ imbalance
            %
            % Args:
            %   inputSignal: Pre-combined numeric signal array [samples x antennas]
            % Returns:
            %   outputSignal: Processed signal array with RF impairments applied

            % Apply RF impairments chain
            x = obj.LowerPowerAmplifier(inputSignal);

            release(obj.ThermalNoise);
            xAwgn = obj.ThermalNoise(x);

            outputSignal = obj.IQImbalance(xAwgn);
        end

    end

end
