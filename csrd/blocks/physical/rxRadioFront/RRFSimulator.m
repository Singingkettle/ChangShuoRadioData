classdef RRFSimulator < matlab.System
    
    properties
        StartTime (1, 1) {mustBeGreaterThanOrEqual(StartTime, 0), mustBeReal} = 0
        InterpDecim (1, 1) {mustBePositive, mustBeInteger} = 2
        NumReceiveAntennas (1, 1) {mustBePositive, mustBeReal} = 1
        BandWidth {mustBePositive, mustBeReal, mustBeInteger} = 20e3;
        CenterFrequency (1, 1) {mustBePositive, mustBeReal, mustBeInteger} = 20e3
        % 关于SampleRateOffset的取值影响晶振频率也影响采样偏移
        % 可参考matlab的调制识别例子
        SampleRateOffset (1, 1) {mustBeReal} = 0
        TimeDuration (1, 1) {mustBePositive, mustBeReal} = 0.1
        MasterClockRate (1, 1) {mustBePositive, mustBeReal} = 184.32e6
        DCOffset {mustBeReal} = -50
        
        SiteConfig struct
        IqImbalanceConfig struct
        MemoryLessNonlinearityConfig struct
        ThermalNoiseConfig struct

    end
    
    properties (Access = protected)
        
        SamplePerFrame
        FrequencyOffset
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

        function ThermalNoise = genThermalNoise(obj)
            ThermalNoise = comm.ThermalNoise( ...
                NoiseMethod = "Noise figure", ...
                NoiseFigure = obj.ThermalNoiseConfig.NoiseFigure, ...
                SampleRate = obj.MasterClockRate);
        end
        
        function SampleShifter = genSampleShifter(obj)
            SampleShifter = comm.SampleRateOffset(...
                Offset=obj.MasterClockRate);
        end
        
    end
    
    methods
        
        function obj = RRFSimulator(varargin)
            
            setProperties(obj, nargin, varargin{:});
            
        end
        
    end
    
    methods (Access=protected)
        
        function setupImpl(obj)

            obj.LowerPowerAmplifier = obj.genLowerPowerAmplifier;
            obj.SampleShifter = obj.genSampleShifter;
            obj.ThermalNoise = obj.genThermalNoise;
            obj.IQImbalance = obj.genIqImbalance;

        end
        
        function out = stepImpl(obj, chs)
            
            num_tx = length(chs);
            if isfield(chs{1}{1}, 'StartTime')
                obj.TimeDuration = 0.001;
                for tx_id = 1:num_tx
                    txs = chs{tx_id};

                    for part_id=1:length(txs)
                        tx = txs{part_id};
                        end_time = tx.StartTime + tx.TimeDuration;
                        if obj.TimeDuration < end_time
                            obj.TimeDuration = end_time;
                        end
                    end
                end
                obj.TimeDuration = (rand(1)*0.1+1) * obj.TimeDuration;
            end
            % First step, aggreate all signals together
            datas = zeros(round(obj.MasterClockRate * obj.TimeDuration * obj.InterpDecim), ...
                num_tx, ...
                obj.NumReceiveAntennas);
            
            
            datas_info = cell(1, num_tx);
            for tx_id =1:num_tx
                txs = chs{tx_id};

                partinfo = zeros(2, length(txs));
                for part_id=1:length(txs)
                    tx = txs{part_id};
                    src = dsp.SampleRateConverter( ...
                        Bandwidth=max(abs(tx.BandWidth))+tx.CarrierFrequency, ...
                        InputSampleRate=tx.SampleRate, ...
                        OutputSampleRate=obj.MasterClockRate*obj.InterpDecim, ...
                        StopbandAttenuation=100);
                    x = src(tx.data);
                    startIdx = fix(obj.MasterClockRate * obj.InterpDecim * tx.StartTime)+1;
                    datas(startIdx:length(x)+startIdx-1, tx_id, :) = x;
                    partinfo(1, part_id) = startIdx;
                    partinfo(2, part_id) = length(x)+startIdx-1;
                end
                datas_info{tx_id} = partinfo;
            end

            % t, tx, rx
            y = cell(1, obj.NumReceiveAntennas);
            SNRs = cell(num_tx, obj.NumReceiveAntennas);
            
            DDC = dsp.DigitalDownConverter(...
                    DecimationFactor=obj.InterpDecim,...
                    SampleRate = obj.MasterClockRate*obj.InterpDecim,...
                    Bandwidth  = obj.BandWidth,...
                    StopbandAttenuation = 60,...
                    PassbandRipple = 0.1,...
                    CenterFrequency = obj.CenterFrequency);
            for ra_id=1:obj.NumReceiveAntennas
                x = sum(datas(:, :, ra_id), 2);
                x = bandpass(x, ...
                    [obj.CenterFrequency - obj.BandWidth/2, ...
                    obj.CenterFrequency + obj.BandWidth/2], ...
                    obj.MasterClockRate * obj.InterpDecim, ...
                    ImpulseResponse = "fir", ...
                    Steepness = 0.99, ...
                    StopbandAttenuation=100);
                x = obj.LowerPowerAmplifier(x);
                x = DDC(x);
                x = obj.SampleShifter(x);
                xAwgn = obj.ThermalNoise(x);
                
                % Estimate Eb/No
                n = xAwgn - x;
                for tx_id=1:num_tx
                    num_parts = size(datas_info{tx_id}, 2);
                    part_SNRs = zeros(1, num_parts);
                    for part_id = 1:num_parts
                        left = datas_info{tx_id}(part_id, 1);
                        right = datas_info{tx_id}(part_id, 2);
                        px = x(left:right, tx_id);
                        pn = n(left:right, tx_id);
                        part_SNRs(part_id) = 10*log10(sum(abs(px).^2)/sum(abs(pn).^2));
                    end
                    SNRs{tx_id, ra_id} = part_SNRs;
                end
                x = x + 10 ^ (obj.DCOffset / 10);
                x = obj.IQImbalance(x);
                y{ra_id} = x;
            end
            y = cell2mat(y);
            
            out.data = y;
            out.StartTime = obj.StartTime;
            out.TimeDuration = size(y, 1) / obj.MasterClockRate;
            out.MasterClockRate = obj.MasterClockRate;
            out.NumReceiveAntennas = obj.NumReceiveAntennas;
            out.SampleRateOffset = obj.SampleRateOffset;
            out.DCOffset = obj.DCOffset;
            out.IqImbalanceConfig = obj.IqImbalanceConfig;
            out.PhaseNoiseConfig = obj.PhaseNoiseConfig;
            out.MemoryLessNonlinearityConfig = obj.MemoryLessNonlinearityConfig;
            out.ThermalNoiseConfig = obj.ThermalNoiseConfig;
            out.SNRs = SNRs;
            out.RxSiteConfig = obj.RxSiteConfig;
            
            out.tx = cell(num_tx, 1);
            for tx_id=1:num_tx
                item = rmfield(chs{tx_id}, 'data');
                out.tx{tx_id} = item;
            end
            
        end
        
    end
    
end
