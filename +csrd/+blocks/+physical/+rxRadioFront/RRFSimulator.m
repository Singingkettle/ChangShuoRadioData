classdef RRFSimulator < matlab.System
    % RRFSimulator: Radio Receiver Front-end Simulator
    %
    % Models the receiver-side RF chain that is currently implemented.
    % Today the actively connected stages, in order, are:
    %   1. Low-noise amplifier nonlinearity (comm.MemorylessNonlinearity)
    %   2. Thermal noise (comm.ThermalNoise)
    %   3. IQ imbalance (iqimbal)
    %   4. ADC sample-rate offset in ppm (comm.SampleRateOffset)
    %
    % Stages historically declared but never wired (phase noise, AGC,
    % bandpass filter, Doppler frequency shifter) have been removed from
    % this class so that the documented capabilities match the runtime
    % behaviour. Re-enable them only after they are integrated into
    % stepImpl with proper validation.

    properties
        StartTime (1, 1) {mustBeGreaterThanOrEqual(StartTime, 0), mustBeReal} = 0 % Start time of simulation in seconds
        DecimationFactor (1, 1) {mustBePositive, mustBeReal} = 1 % Decimation factor
        NumReceiveAntennas (1, 1) {mustBePositive, mustBeReal} = 1 % Number of receive antennas
        BandWidth {mustBePositive, mustBeReal, mustBeInteger} = 20e6 % Receiver bandwidth in Hz (updated default)
        CenterFrequency (1, 1) {mustBeReal, mustBeInteger} = 0 % Center frequency in Hz (now allows 0 for baseband-centric)
        SampleRateOffset (1, 1) {mustBeReal} = 0 % ADC clock offset in parts per million (ppm)
        TimeDuration (1, 1) {mustBePositive, mustBeReal} = 0.1 % Total simulation duration in seconds
        MasterClockRate (1, 1) {mustBePositive, mustBeReal} = 20e6 % Master clock rate in Hz (updated default)
        DCOffset {mustBeReal} = -50 % DC offset in dB

        UseReceiverCentricMode (1, 1) logical = true % Use new frequency allocation approach

        SiteConfig struct % Configuration for receiver site parameters
        IqImbalanceConfig struct % Configuration for IQ imbalance parameters
        MemoryLessNonlinearityConfig struct % Configuration for nonlinearity parameters
        ThermalNoiseConfig struct % Configuration for thermal noise parameters
    end

    properties (GetAccess = public, SetAccess = protected)
        % Read-only handles to the actually-connected impairment objects.
        LowerPowerAmplifier % comm.MemorylessNonlinearity instance
        ThermalNoise        % comm.ThermalNoise instance
        IQImbalance         % function handle applying iqimbal
        SampleShifter       % comm.SampleRateOffset instance
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
            % Generates the ADC sample-rate-offset object.
            % Offset is in ppm (parts per million); 0 ppm is a no-op
            % (identity) and therefore safe to instantiate unconditionally.
            SampleShifter = comm.SampleRateOffset( ...
                Offset = obj.SampleRateOffset);
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
            obj.LowerPowerAmplifier = obj.genLowerPowerAmplifier;
            obj.ThermalNoise = obj.genThermalNoise;
            obj.IQImbalance = obj.genIqImbalance;
            obj.SampleShifter = obj.genSampleShifter;
        end

        function outputSignal = stepImpl(obj, inputSignal)
            % stepImpl - Apply receiver RF impairments to a pre-combined signal.
            %
            % Signal combination is performed upstream in
            % processReceiverProcessing. The active impairment chain is:
            %   1. LNA nonlinearity (comm.MemorylessNonlinearity)
            %   2. Thermal noise   (comm.ThermalNoise)
            %   3. IQ imbalance    (iqimbal)
            %   4. ADC sample-rate offset (comm.SampleRateOffset, ppm)
            %
            % comm.SampleRateOffset is invoked unconditionally because
            % an offset of 0 ppm is a deterministic identity. When the
            % configured offset is non-zero the output length may
            % differ from the input length by one sample (Farrow filter).
            %
            % Args:
            %   inputSignal: Pre-combined numeric signal array [samples x antennas]
            % Returns:
            %   outputSignal: Signal array after the impairment chain.

            x = obj.LowerPowerAmplifier(inputSignal);

            release(obj.ThermalNoise);
            xAwgn = obj.ThermalNoise(x);

            xIq = obj.IQImbalance(xAwgn);

            release(obj.SampleShifter);
            outputSignal = obj.SampleShifter(xIq);
        end

    end

end
