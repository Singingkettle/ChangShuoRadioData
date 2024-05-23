classdef RRFSimulator < matlab.System

    properties
        StartTime (1, 1) {mustBeGreaterThanOrEqual(StartTime, 0), mustBeReal} = 0
        TimeDuration (1, 1) {mustBePositive, mustBeReal} = 1
        SampleRate (1, 1) {mustBePositive, mustBeReal} = 200e6
        NumReceiveAntennas (1, 1) {mustBePositive, mustBeReal} = 1
        CenterFrequency (1, 1) {mustBePositive, mustBeReal, mustBeInteger} = 20e3
        AntennaEfficiency (1, 1) {mustBePositive, mustBeReal} = 0.5
        ReceiveAntennaDiameter  (1, 1) {mustBePositive, mustBeReal} = 0.4
        % 关于SampleRateOffset的取值影响晶振频率也影响采样偏移
        % 可参考matlab的调制识别例子
        SampleRateOffset (1, 1) {mustBeReal} = 0
        Bandwidth {mustBePositive, mustBeReal, mustBeInteger} = 20e3;

        MasterClockRate (1, 1) {mustBePositive, mustBeReal} = 184.32e6;
        DCOffset {mustBeReal} = -50;
        
        MemoryLessNonlinearityConfig struct
        ThermalNoiseConfig struct
        PhaseNoiseConfig struct
        AGCConfig struct
        IqImbalanceConfig struct
        
    end

    properties (Access = protected)
        SamplePerFrame
        FrequencyOffset
        InterpDecim
        LowerPowerAmplifier
        FrequencyShifter % Doppler shift
        ThermalNoise
        PhaseNoise
        IQImbalance
        AGC
        SNR
        SampleShifter

    end

    methods (Access = private)
        
        function IQImbalance = genIqImbalance(obj)

            % https://www.mathworks.com/help/comm/ref/iqimbal.html
            IQImbalance = @(x)iqimbal(x, ...
                obj.IqImbalanceConfig.A, ...
                obj.IqImbalanceConfig.P);

        end

        function LowerNoiseAmplifier = genLowerPowerAmplifier(obj)

            if strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Cubic polynomial')
                LowerNoiseAmplifier = comm.MemorylessNonlinearity( ...
                    Method = 'Cubic polynomial', ...
                    LinearGain = obj.MemoryLessNonlinearityConfig.LinearGain, ...
                    TOISpecification = obj.MemoryLessNonlinearityConfig.TOISpecification, ...
                    IIP3 = obj.MemoryLessNonlinearityConfig.IIP3);

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

                LowerNoiseAmplifier.AMPMConversion = obj.MemoryLessNonlinearityConfig.AMPMConversion;
                LowerNoiseAmplifier.PowerLowerLimit = obj.MemoryLessNonlinearityConfig.PowerLowerLimit;
                LowerNoiseAmplifier.PowerUpperLimit = obj.MemoryLessNonlinearityConfig.PowerUpperLimit;
            elseif strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Hyperbolic tangent')
                LowerNoiseAmplifier = comm.MemorylessNonlinearity( ...
                    Method = 'Hyperbolic tangent', ...
                    LinearGain = obj.MemoryLessNonlinearityConfig.LinearGain, ...
                    IIP3 = obj.MemoryLessNonlinearityConfig.IIP3);
                LowerNoiseAmplifier.AMPMConversion = obj.MemoryLessNonlinearityConfig.AMPMConversion;
                LowerNoiseAmplifier.PowerLowerLimit = obj.MemoryLessNonlinearityConfig.PowerLowerLimit;
                LowerNoiseAmplifier.PowerUpperLimit = obj.MemoryLessNonlinearityConfig.PowerUpperLimit;

            elseif strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Saleh model') || strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Ghorbani model')
                LowerNoiseAmplifier = comm.MemorylessNonlinearity( ...
                    Method = obj.MemoryLessNonlinearityConfig.Method, ...
                    InputScaling = obj.MemoryLessNonlinearityConfig.InputScaling, ...
                    AMAMParameters = obj.MemoryLessNonlinearityConfig.AMAMParameters, ...
                    AMPMParameters = obj.MemoryLessNonlinearityConfig.AMPMParameters, ...
                    OutputScaling = obj.MemoryLessNonlinearityConfig.OutputScaling);
            elseif strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Modified Rapp model')
                LowerNoiseAmplifier = comm.MemorylessNonlinearity( ...
                    Method = 'Modified Rapp model', ...
                    LinearGain = obj.MemoryLessNonlinearityConfig.LinearGain, ...
                    Smoothness = obj.MemoryLessNonlinearityConfig.Smoothness, ...
                    PhaseGainRadian = obj.MemoryLessNonlinearityConfig.PhaseGainRadian, ...
                    PhaseSmoothness = obj.MemoryLessNonlinearityConfig.PhaseSmoothness, ...
                    OutputSaturationLevel = obj.MemoryLessNonlinearityConfig.OutputSaturationLevel);
            elseif strcmp(obj.MemoryLessNonlinearityConfig.Method, 'Lookup table')
                LowerNoiseAmplifier = comm.MemorylessNonlinearity( ...
                    Method = 'Look table', ...
                    Table = obj.MemoryLessNonlinearityConfig.Table);
            end

            LowerNoiseAmplifier.ReferenceImpedance = obj.MemoryLessNonlinearityConfig.ReferenceImpedance;
        end
        
        

        function FrequencyShifter = genFrequencyShifter(obj)
            FrequencyShifter = comm.PhaseFrequencyOffset(...
                SampleRate=obj.SampleRate);
            obj.FrequencyShifter.FrequencyOffset = -obj.SampleRateOffset*1e-6*obj.CenterFrequency;
        end

        function ThermalNoise = genThermalNoise(obj)
            ThermalNoise = comm.ThermalNoise( ...
                SampleRate = obj.SampleRate, ...
                NoiseTemperature = obj.ThermalNoiseConfig.NoiseTemperature);
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

        
        function AGC = genAGC(obj)
            AGC = comm.AGC(...
                AveragingLength = obj.AGCConfig.AveragingLength, ...
                MaxPowerGain = obj.AGCConfig.MaxPowerGain);

        end

        function SampleShifter = genSampleShifter(obj)
            SampleShifter = comm.SampleRateOffset(...
                Offset=obj.SampleRateOffset);
        end

    end
    
    methods

        function obj = RRFSimulator(varargin)
        
            setProperties(obj, nargin, varargin{:});
        
        end

    end

    methods (Access=protected)

        function setupImpl(obj)
            
            obj.SamplePerFrame = round(obj.SampleRate * obj.TimeDuration);
            obj.LowerPowerAmplifier = obj.genLowerPowerAmplifier;
            obj.FrequencyShifter = obj.genFrequencyShifter;
            obj.SampleShifter = obj.genSampleShifter;
            obj.ThermalNoise = obj.genThermalNoise;
            obj.PhaseNoise = obj.genPhaseNoise;
            obj.IQImbalance = obj.genIqImbalance;
            obj.AGC = obj.genAGC;
            

        end

        function out = stepImpl(obj, in)

            obj.InterpDecim = fix(obj.MasterClockRate / obj.SampleRate);
            obj.MasterClockRate = obj.InterpDecim * obj.SampleRate;
            
            % First step, aggreate all signals together
            datas = zeros(length(in), ...
                obj.MasterClockRate * obj.TimeDuration, ...
                obj.NumReceiveAntennas);
            if iscell(in) && length(in) > 1
                for i =1:length(in)
                    xgrid = zeros(obj.MasterClockRate * obj.TimeDuration, ...
                        obj.NumReceiveAntennas);
                    rx = in{i};
                    src = dsp.SampleRateConverter( ...
                        Bandwidth=rx.BandWidth+rx.CarrierFrequency*2, ...
                        InputSampleRate=rx.SampleRate, ...
                        OutputSampleRate=obj.MasterClockRate, ...
                        StopbandAttenuation=180);
                    x = src(rx.data);
                    startIdx = fix(obj.MasterClockRate * rx.StartTime)+1;
                    xgrid(startIdx:length(x)+startIdx-1, :) = x;
                    datas(i, :, :) = xgrid;
                end
            else
                xgrid = zeros(obj.MasterClockRate * obj.TimeDuration, ...
                        obj.NumReceiveAntennas);
                if ~iscell(in)
                    in = {in};
                end
                rx = in{1};
                src = dsp.SampleRateConverter( ...
                    Bandwidth=rx.BandWidth+rx.CarrierFrequency*2, ...
                    InputSampleRate=rx.SampleRate, ...
                    OutputSampleRate=obj.MasterClockRate, ...
                    StopbandAttenuation=180);
                x = src(rx.data);
                x = bandpass(x, ...
                            [rx.CarrierFrequency - rx.BandWidth/2, ...
                            rx.CarrierFrequency + rx.BandWidth/2], ...
                            obj.MasterClockRate, ...
                            ImpulseResponse = "fir", ...
                            Steepness = 0.99, ...
                            StopbandAttenuation=200);
                startIdx = fix(obj.MasterClockRate * rx.StartTime)+1;
                xgrid(startIdx:length(x)+startIdx-1, :) = x;
                datas(1, :, :) = xgrid;
            end
            
            mbc = comm.MultibandCombiner( ...
                    InputSampleRate=obj.MasterClockRate, ...
                    FrequencyOffsets=0, ...
                    OutputSampleRateSource='Property', ...
                    OutputSampleRate=obj.MasterClockRate);
            datas = permute(datas, [2 1 3]);
            y = cell(1, obj.NumReceiveAntennas);
            SNRs = zeros(length(in), obj.NumReceiveAntennas);
            for rxI=1:obj.NumReceiveAntennas
                x = mbc(datas(:, :, rxI));
    
                % lightSpeed = physconst('light');
                % waveLength = lightSpeed/(obj.CarrierFrequency);
                % rxAntGain = sqrt(obj.AntennaEfficiency)*pi*obj.ReceiveAntennaDiameter/waveLength;
                % x = rxAntGain*x;
    
                x = obj.LowerPowerAmplifier(x);
                DDC = dsp.DigitalDownConverter(...
                      DecimationFactor=obj.InterpDecim,...
                      SampleRate = obj.MasterClockRate,...
                      Bandwidth  = obj.Bandwidth,...
                      StopbandAttenuation = 60,...
                      PassbandRipple = 0.1,...
                      CenterFrequency = obj.CenterFrequency);
                x = DDC(x);
                x = obj.FrequencyShifter(x);
                x = obj.SampleShifter(x);
                xAwgn = obj.ThermalNoise(x);

                % Estimate Eb/No
                for i=1:length(in)
                    SNRs(i, rxI) = 10*log10(var(in{i}.data(:, rxI))./var(xAwgn-x));
                end
                x = obj.PhaseNoise(xAwgn);
                x = x + 10 ^ (obj.DCOffset / 10);
                x = obj.IQImbalance(x);
                x = obj.AGC(x);
                y{rxI} = x;
            end
            y = cell2mat(y);

            out.data = y;
            out.StartTime = obj.StartTime;
            out.TimeDuration = obj.TimeDuration;
            out.MasterClockRate = obj.MasterClockRate;
            out.SampleRate = obj.SampleRate;
            out.NumReceiveAntennas = obj.NumReceiveAntennas;
            out.CenterFrequency = obj.CenterFrequency;
            out.SampleRateOffset = obj.SampleRateOffset;
            out.Bandwidth = obj.Bandwidth;
            out.DCOffset = obj.DCOffset;
            out.IqImbalanceConfig = obj.IqImbalanceConfig;
            out.PhaseNoiseConfig = obj.PhaseNoiseConfig;
            out.MemoryLessNonlinearityConfig = obj.MemoryLessNonlinearityConfig;
            out.ThermalNoiseConfig = obj.ThermalNoiseConfig;
            out.AGCConfig = obj.AGCConfig;
            out.SNRs = SNRs;

            out.tx = cell(length(in), 1);
            for i=1:length(in)
                item = rmfield(in{i}, 'data');
                out.tx{i} = item;
            end

        end

    end

end
