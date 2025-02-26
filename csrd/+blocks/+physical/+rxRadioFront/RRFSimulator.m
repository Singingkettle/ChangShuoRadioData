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
        BandWidth {mustBePositive, mustBeReal, mustBeInteger} = 20e3 % Receiver bandwidth in Hz
        CenterFrequency (1, 1) {mustBePositive, mustBeReal, mustBeInteger} = 20e3 % Center frequency in Hz
        SampleRateOffset (1, 1) {mustBeReal} = 0 % Sample rate offset affecting crystal frequency and sampling
        TimeDuration (1, 1) {mustBePositive, mustBeReal} = 0.1 % Total simulation duration in seconds
        MasterClockRate (1, 1) {mustBePositive, mustBeReal} = 184.32e6 % Master clock rate in Hz
        DCOffset {mustBeReal} = -50 % DC offset in dB

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

        function bpFilt = genBandpassFilter(obj)
            % Generates bandpass filter object with specified center frequency and bandwidth
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
            obj.BandpassFilter = obj.genBandpassFilter; % Initialize bandpass filter
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
                obj.TimeDuration = obj.TimeDuration + (rand(1) * 0.1 + 1) * 0.0001;
            end

            % Initialize arrays for combined signals
            datas = zeros(round(obj.MasterClockRate * obj.TimeDuration), ...
                num_tx, ...
                obj.NumReceiveAntennas);

            datas_info = cell(1, num_tx);

            for tx_id = 1:num_tx
                txs = chs{tx_id};

                partinfo = cell(length(txs), 3);
                hbw = 0;
                cf = 0;
                sp = 0;

                for part_id = 1:length(txs)
                    tx = txs{part_id};

                    if obj.MasterClockRate ~= tx.SampleRate
                        useSR = true;

                        if max(abs(tx.BandWidth)) > hbw
                            hbw = max(abs(tx.BandWidth));
                        end

                        cf = tx.CarrierFrequency;
                        sp = tx.SampleRate;

                    else
                        useSR = false;
                        break;
                    end

                end

                if useSR
                    src = dsp.SampleRateConverter( ...
                        Bandwidth = hbw + cf, ...
                        InputSampleRate = sp, ...
                        OutputSampleRate = obj.MasterClockRate);
                end

                for part_id = 1:length(txs)
                    tx = txs{part_id};

                    if useSR
                        x = src(tx.data);
                    else
                        x = tx.data;
                    end

                    startIdx = fix(obj.MasterClockRate * tx.StartTime) + 1;
                    datas(startIdx:length(x) + startIdx - 1, tx_id, :) = x;
                    partinfo{part_id, 1} = startIdx;
                    partinfo{part_id, 2} = length(x) + startIdx - 1;
                    partinfo{part_id, 3} = sum(abs(x) .^ 2, 1); % the power of the signal for calculating SNR
                end

                datas_info{tx_id} = partinfo;
            end

            % Apply bandpass filter
            datas = sum(datas, 2);
            datas = reshape(datas, [], obj.NumReceiveAntennas);
            datas = filter(obj.BandpassFilter, datas);

            % Apply RF impairments
            x = obj.LowerPowerAmplifier(datas);
            % TODO: add sample rate offset, it will be used in the future
            % However, it is not used in the current implementation.
            % Because the sample rate offset implementation has bugs.
            % x = obj.SampleShifter(x);

            release(obj.ThermalNoise);
            xAwgn = obj.ThermalNoise(x);
            n = xAwgn - x;
            % Apply DC offset and IQ imbalance
            x = xAwgn + 10 ^ (obj.DCOffset / 10);
            y = obj.IQImbalance(x);
            % Initialize output cell array
            SNRs = cell(num_tx, obj.NumReceiveAntennas);

            % Process each receive antenna
            for ra_id = 1:obj.NumReceiveAntennas
                % Calculate SNR for each transmission
                for tx_id = 1:num_tx
                    num_parts = size(datas_info{tx_id}, 1);
                    part_SNRs = zeros(1, num_parts);

                    % Calculate SNR for each part
                    for part_id = 1:num_parts
                        left = datas_info{tx_id}{part_id, 1};
                        right = datas_info{tx_id}{part_id, 2};
                        pn = n(left:right, ra_id);
                        part_SNRs(part_id) = 10 * log10(datas_info{tx_id}{part_id, 3}(ra_id) / sum(abs(pn) .^ 2));
                    end

                    SNRs{tx_id, ra_id} = part_SNRs;
                end

            end

            % Prepare output structure
            out.data = y;
            out.StartTime = obj.StartTime;
            out.TimeDuration = size(y, 1) / obj.MasterClockRate;
            out.MasterClockRate = obj.MasterClockRate;
            out.NumReceiveAntennas = obj.NumReceiveAntennas;
            out.SampleRateOffset = obj.SampleRateOffset;
            out.DCOffset = obj.DCOffset;
            out.SDRDecimationFactor = obj.DecimationFactor;
            out.IqImbalanceConfig = obj.IqImbalanceConfig;
            out.MemoryLessNonlinearityConfig = obj.MemoryLessNonlinearityConfig;
            out.ThermalNoiseConfig = obj.ThermalNoiseConfig;
            out.SNRs = SNRs;
            out.SiteConfig = obj.SiteConfig;
            out.SDRMode = "Zero-IF Receiver";

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
