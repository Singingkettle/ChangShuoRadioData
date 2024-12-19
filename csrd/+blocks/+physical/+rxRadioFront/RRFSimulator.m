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
        NumReceiveAntennas (1, 1) {mustBePositive, mustBeReal} = 1 % Number of receive antennas
        BandWidth {mustBePositive, mustBeReal, mustBeInteger} = 20e3 % Receiver bandwidth in Hz
        CenterFrequency (1, 1) {mustBePositive, mustBeReal, mustBeInteger} = 20e3 % Center frequency in Hz
        SampleRateOffset (1, 1) {mustBeReal} = 0 % Sample rate offset affecting crystal frequency and sampling
        TimeDuration (1, 1) {mustBePositive, mustBeReal} = 0.1 % Total simulation duration in seconds
        MasterClockRate (1, 1) {mustBePositive, mustBeReal} = 184.32e6 % Master clock rate in Hz
        DCOffset {mustBeReal} = -50 % DC offset in dB

        % Configuration structs for RF impairments
        RxSiteConfig struct % Configuration for receiver site parameters
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
    end

    methods (Access = private)

        function IQImbalance = genIqImbalance(obj)
            % Generates IQ imbalance function handle
            % Returns a function that applies amplitude (A) and phase (P) imbalance
            % to the input signal using the iqimbal function

            IQImbalance = @(x)iqimbal(x, ...
                obj.IqImbalanceConfig.A, ...
                obj.IqImbalanceConfig.P);
        end

        function LowerNoiseAmplifier = genLowerPowerAmplifier(obj)
            % Generates and configures the nonlinear amplifier object based on configuration
            % Supports multiple nonlinearity models:
            % - Cubic polynomial
            % - Hyperbolic tangent
            % - Saleh model
            % - Ghorbani model
            % - Modified Rapp model
            % - Lookup table

            if strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Cubic polynomial')
                % Configure cubic polynomial model
                LowerNoiseAmplifier = comm.MemorylessNonlinearity( ...
                    Method = 'Cubic polynomial', ...
                    LinearGain = obj.MemoryLessNonlinearityConfig.LinearGain, ...
                    TOISpecification = obj.MemoryLessNonlinearityConfig.TOISpecification, ...
                    IIP3 = obj.MemoryLessNonlinearityConfig.IIP3);

                % Set appropriate TOI specification parameter
                if strcmp(obj.MemoryLessNonlinearityConfig.TOISpecification, 'OIP3')
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
                    PhaseSmoothness = obj.MemoryLessNonlinearityConfig.PhaseSmoothness, ...
                    OutputSaturationLevel = obj.MemoryLessNonlinearityConfig.OutputSaturationLevel);
            elseif strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Lookup table')
                % Configure Lookup table model
                LowerNoiseAmplifier = comm.MemorylessNonlinearity( ...
                    Method = 'Look table', ...
                    Table = obj.MemoryLessNonlinearityConfig.Table);
            end

            % Set reference impedance for all models
            LowerNoiseAmplifier.ReferenceImpedance = obj.MemoryLessNonlinearityConfig.ReferenceImpedance;
        end

        function ThermalNoise = genThermalNoise(obj)
            % Generates thermal noise object with specified noise figure and sample rate
            ThermalNoise = comm.ThermalNoise( ...
                NoiseMethod = "Noise figure", ...
                NoiseFigure = obj.ThermalNoiseConfig.NoiseFigure, ...
                SampleRate = obj.MasterClockRate);
        end

        function SampleShifter = genSampleShifter(obj)
            % Generates sample rate offset object with specified master clock rate
            SampleShifter = comm.SampleRateOffset( ...
                Offset = obj.MasterClockRate);
        end

    end

    methods

        function obj = RRFSimulator(varargin)
            % Constructor for RRFSimulator
            % Accepts name-value pairs to set object properties
            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function setupImpl(obj)
            % Initialize all RF impairment components before processing
            obj.LowerPowerAmplifier = obj.genLowerPowerAmplifier; % Initialize nonlinear amplifier
            obj.SampleShifter = obj.genSampleShifter; % Initialize sample rate offset
            obj.ThermalNoise = obj.genThermalNoise; % Initialize thermal noise
            obj.IQImbalance = obj.genIqImbalance; % Initialize IQ imbalance
        end

        function out = stepImpl(obj, chs)
            % Main processing function that applies RF impairments to input signals
            % Input:
            %   chs: Cell array of input channels, each containing signal data
            % Output:
            %   out: Structure containing processed signals and configuration info

            % Calculate simulation duration based on input signals
            num_tx = length(chs);

            % Adjust simulation duration if start times are specified
            if isfield(chs{1}{1}, 'StartTime')
                obj.TimeDuration = 0.001;

                % Find the latest end time among all transmissions
                for tx_id = 1:num_tx
                    txs = chs{tx_id};

                    for part_id = 1:length(txs)
                        tx = txs{part_id};
                        end_time = tx.StartTime + tx.TimeDuration;

                        if obj.TimeDuration < end_time
                            obj.TimeDuration = end_time;
                        end

                    end

                end

                % Add random margin to duration
                obj.TimeDuration = (rand(1) * 0.1 + 1) * obj.TimeDuration;
            end

            % Initialize arrays for combined signals
            datas = zeros(round(obj.MasterClockRate * obj.TimeDuration * obj.InterpDecim), ...
                num_tx, ...
                obj.NumReceiveAntennas);

            datas_info = cell(1, num_tx);

            % Process each transmitter's signals
            for tx_id = 1:num_tx
                txs = chs{tx_id};
                partinfo = zeros(2, length(txs));
                InputSampleRate = txs{1}.SampleRate;

                gcd_val = gcd(obj.MasterClockRate, InputSampleRate);

                if gcd_val ~= min(obj.MasterClockRate, InputSampleRate)
                    error("The master clock rate and input sample rate are not coprime");
                else
                    InterpDecim = max(obj.MasterClockRate, InputSampleRate) / gcd_val;
                end

                % Combine signals from all parts of this transmitter
                sub_datas = zeros(round(InputSampleRate * obj.TimeDuration), obj.NumReceiveAntennas);
                Bandwidth = max(abs(txs{1}.BandWidth)) + txs{1}.CarrierFrequency;
                CenterFrequency = txs{1}.CarrierFrequency;

                % Process each part of the transmission
                for part_id = 1:length(txs)
                    tx = txs{part_id};

                    % Verify sample rate consistency
                    if tx.SampleRate ~= InputSampleRate
                        error("The sample rate of the %dth part of the %dth tx is not equal to the input sample rate", part_id, tx_id);
                    end

                    % Update bandwidth if necessary
                    if max(abs(tx.BandWidth)) + tx.CarrierFrequency > Bandwidth
                        Bandwidth = max(abs(tx.BandWidth)) + tx.CarrierFrequency;
                    end

                    % Place data at correct time offset
                    startIdx = fix(InputSampleRate * tx.StartTime) + 1;
                    sub_datas(startIdx:length(tx.data) + startIdx - 1, :) = tx.data;
                    partinfo(1, part_id) = fix(obj.MasterClockRate * tx.StartTime) + 1;
                    partinfo(2, part_id) = fix(obj.MasterClockRate * (tx.StartTime + tx.TimeDuration)) + 1;
                end

                % Perform sample rate conversion
                if InterpDecim ~= 1

                    if InputSampleRate > obj.MasterClockRate
                        % Configure digital down converter
                        DDC = dsp.DigitalDownConverter( ...
                            DecimationFactor = InterpDecim, ...
                            SampleRate = obj.MasterClockRate, ...
                            Bandwidth = Bandwidth, ...
                            StopbandAttenuation = 60, ...
                            PassbandRipple = 0.1, ...
                            CenterFrequency = CenterFrequency);
                        sub_datas = DDC(sub_datas);
                    else
                        % Configure digital up converter
                        DUC = dsp.DigitalUpConverter( ...
                            InterpolationFactor = InterpDecim, ...
                            SampleRate = obj.MasterClockRate, ...
                            Bandwidth = Bandwidth, ...
                            StopbandAttenuation = 60, ...
                            PassbandRipple = 0.1, ...
                            CenterFrequency = CenterFrequency);
                        sub_datas = DUC(sub_datas);
                    end

                end

                datas(:, tx_id, :) = sub_datas(1:round(obj.MasterClockRate * obj.TimeDuration), :);
                datas_info{tx_id} = partinfo;
            end

            % Initialize output arrays
            y = cell(1, obj.NumReceiveAntennas);
            SNRs = cell(num_tx, obj.NumReceiveAntennas);

            % Process each receive antenna
            for ra_id = 1:obj.NumReceiveAntennas
                % Combine signals from all transmitters
                x = sum(datas(:, :, ra_id), 2);

                % Apply bandpass filter
                x = bandpass(x, ...
                    [obj.CenterFrequency - obj.BandWidth / 2, ...
                     obj.CenterFrequency + obj.BandWidth / 2], ...
                    obj.MasterClockRate, ...
                    ImpulseResponse = "fir", ...
                    Steepness = 0.99, ...
                    StopbandAttenuation = 100);

                % Apply RF impairments
                x = obj.LowerPowerAmplifier(x);
                x = obj.SampleShifter(x);
                xAwgn = obj.ThermalNoise(x);

                % Calculate SNR for each transmission
                n = xAwgn - x;

                for tx_id = 1:num_tx
                    num_parts = size(datas_info{tx_id}, 2);
                    part_SNRs = zeros(1, num_parts);

                    % Calculate SNR for each part
                    for part_id = 1:num_parts
                        left = datas_info{tx_id}(1, part_id);
                        right = datas_info{tx_id}(2, part_id);
                        px = x(left:right, 1);
                        pn = n(left:right, 1);
                        part_SNRs(part_id) = 10 * log10(sum(abs(px) .^ 2) / sum(abs(pn) .^ 2));
                    end

                    SNRs{tx_id, ra_id} = part_SNRs;
                end

                % Apply DC offset and IQ imbalance
                x = x + 10 ^ (obj.DCOffset / 10);
                x = obj.IQImbalance(x);
                y{ra_id} = x;
            end

            % Combine all antenna outputs
            y = cell2mat(y);

            % Prepare output structure
            out.data = y;
            out.StartTime = obj.StartTime;
            out.TimeDuration = size(y, 1) / obj.MasterClockRate;
            out.MasterClockRate = obj.MasterClockRate;
            out.NumReceiveAntennas = obj.NumReceiveAntennas;
            out.SampleRateOffset = obj.SampleRateOffset;
            out.DCOffset = obj.DCOffset;
            out.IqImbalanceConfig = obj.IqImbalanceConfig;
            out.MemoryLessNonlinearityConfig = obj.MemoryLessNonlinearityConfig;
            out.ThermalNoiseConfig = obj.ThermalNoiseConfig;
            out.SNRs = SNRs;
            out.RxSiteConfig = obj.RxSiteConfig;

            % Store transmitter information without data
            out.tx = cell(num_tx, 1);

            for tx_id = 1:num_tx
                out.tx{tx_id} = cell(length(chs{tx_id}), 1);

                for part_id = 1:length(chs{tx_id})
                    item = rmfield(chs{tx_id}{part_id}, 'data');
                    out.tx{tx_id}{part_id} = item;
                end

            end

        end

    end

end
