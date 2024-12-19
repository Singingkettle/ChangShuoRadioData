classdef Simulation < matlab.System
    % Simulation - Simulates the runner
    %   This class simulates the runner using the given parameters.
    
    properties
        % Parameters for the simulation
        NumMaxTx (1, 1) {mustBePositive, mustBeReal} = 8
        NumMaxRx (1, 1) {mustBePositive, mustBeReal} = 8
        NumMaxTransmitTimes (1, 1) {mustBePositive, mustBeReal} = 4
        IsOverlap (1, 1) = true
        FrequencyOverlapRadioRange = [0, 0.15];
        TimeOverlapRadio = [0, 0.5];
        TimeIntervalRatio (2, 1) {mustBeReal} = [-50, 50]
        MasterClockRateStep (1, 1) {mustBePositive, mustBeInteger} = 1e4

        % Parameters for transmiter
        AnnlogRatio (1, 1) {mustBePositive, mustBeReal} = 10
        SamplePerSymbolRange (2, 1) {mustBePositive, mustBeReal} = [4; 32]
        TxTimeDurationRange (2, 1) {mustBePositive, mustBeReal} = [0.04; 0.06]
        % 这里将信号的采样率以及发射设备的采样率设置一个较低的数量级是为了，尽量避免
        % 过多的生成数据，
        SampleRateRange (2, 1) {mustBePositive, mustBeReal} = [30e3; 300e3]
        SampleRateStep (1, 1) {mustBePositive, mustBeInteger} = 10e3
        TxMasterClockRateRange (2, 1) {mustBePositive, mustBeReal} = [100e4; 150e4]

        TxOutputPowerRange (2, 1) {mustBeReal} = [-100, 0]
        TxDCOffsetRange (2, 1) {mustBeReal} = [-60, -40]
        TxIqImbalaceConfigARange (2, 1) {mustBeReal} = [0, 5]
        TxIqImbalaceConfigPRange (2, 1) {mustBeReal} = [0, 5]
        TxPhaseNoiseConfigLevel (2, 1) {mustBeReal} = [-100, -20]
        TxPhaseNoiseConfigFrequencyOffset (2, 1) {mustBeReal} = [10, 200]
        TxMemoryLessNonlinearityConfigMethodPool = ["Cubic polynomial", "Hyperbolic tangent", "Saleh model", "Ghorbani model", "Modified Rapp model", "Lookup table"]
        
        AnalogModulatorPool = ["DSBAM", "DSBSCAM", "SSBAM", "VSBAM", "FM", "PM"]
        DigitalModulatorPool = ["APSK", "DVBSAPSK", "ASK", "CPFSK", "GFSK", "GMSK", "MSK", "FSK", "OFDM", "OOK", "OTFS", "PSK", "OQPSK", "QAM", "Mill88QAM", "SCFDMA"]
        % DigitalModulatorPool = ["OTFS"]
        NumTransmitAntennasRange (2, 1) {mustBePositive, mustBeReal, mustBeLessThan(NumTransmitAntennasRange, 5)} = [1, 4]
        
        % Parameters for receiver
        RxTimeDurationRange (2, 1) {mustBePositive, mustBeReal} = [1; 2]
        RxMasterClockRateRange (2, 1) {mustBePositive, mustBeReal} = [150e4; 200e4]
        RxDCOffsetRange (2, 1) {mustBeReal} = [-60, -40]
        RxIqImbalaceConfigARange (2, 1) {mustBeReal} = [0, 5]
        RxIqImbalaceConfigPRange (2, 1) {mustBeReal} = [0, 5]
        NumReceiveAntennnasRange (2, 1) {mustBePositive, mustBeReal} = [1; 4]
        ThermalNoiseConfigNoiseFigure (2, 1) {mustBeReal} = [0, 10]
    end
    
    properties (Access = private)
        %
        MemoryLessNonlinearityCfgFilePath = '../config/_base_/RF/MemoryLessNonlinearity.json'
        
    end
    
    methods
        function obj = Simulation(varargin)
            % FILEPATH: ChangShuoRadioData/csrd/runner/Simulation.m
            %
            % Simulation class constructor.
            %
            % Syntax:
            %   obj = Simulation(varargin)
            %
            % Description:
            %   This constructor creates an instance of the Simulation class.
            %
            % Input Arguments:
            %   - varargin: Variable number of input arguments.
            %
            % Output Arguments:
            %   - obj: Instance of the Simulation class.
            %
            % Example:
            %   sim = Simulation("param1", value1, "param2", value2);
            %
            % See also: Other classes and functions related to simulation.
            % Constructor
            setProperties(obj, nargin, varargin{:});
            
        end
    end
    
    methods (Access = protected)
        
        function output = stepImpl(obj, numFrames)
            % stepImpl - Simulates the runner for one time step
            %   This function simulates the runner for one time step.
            %   The input is the control input.
            %   The output is the state of the runner.
            
            output = cell(1, numFrames);
            for frameIndex=1:numFrames
                % Modulate
                txs = cell(1, randi([1, obj.NumMaxTx]));
                % the same transimitter will be used to emit wireless signals using different modulation types
                isSuccess = false;
                while ~isSuccess
                    for TxIndex=1:length(txs)
                        txs{TxIndex} = obj.modulate();
                    end
                    txs = obj.tilingTx(txs);
                    if ~isempty(txs)
                        isSuccess=true;
                    else
                        txs = cell(1, randi([1, obj.NumMaxTx]));
                    end
                end
                
                for TxIndex=1:length(txs)
                    txs{TxIndex} = obj.transmit(txs{TxIndex});
                end
                rxs = cell(1, randi([1, obj.NumMaxRx]));
                for RxIndex=1:length(rxs)
                    rxs{RxIndex} = obj.channel(txs);
                    rxs{RxIndex} = obj.receive(rxs{RxIndex});
                end
                output{frameIndex} = rxs;
            end

        end
        
        function ys = modulate(obj)
            
            SampleRate = randi((obj.SampleRateRange(2)-obj.SampleRateRange(1))/obj.SampleRateStep)*obj.SampleRateStep+obj.SampleRateRange(1);
            SamplePerSymbol = randi((obj.SamplePerSymbolRange(2)-obj.SamplePerSymbolRange(1)))+obj.SamplePerSymbolRange(1);
            % 这块是自己手动设置的参数，来控制多发射天线的场景比例
            if rand(1) < 0.2
                NumTransmitAntennas = randi(obj.NumTransmitAntennasRange, 1);
            else
                NumTransmitAntennas = 1;
            end
            
            if randi(100) <= obj.AnnlogRatio
                parentModulatorType = "analog";
                % Limit the SampleRate of Analog < 1MHz
                if SampleRate > 100e3
                    SampleRate = 100e3;
                end
            else
                parentModulatorType = "digital";
            end
            
            if parentModulatorType == "analog"
                ModulatorType = obj.AnalogModulatorPool(randi(length(obj.AnalogModulatorPool)));
            else
                ModulatorType = obj.DigitalModulatorPool(randi(length(obj.DigitalModulatorPool)));
            end
            
            if ModulatorType == "OFDM" || ModulatorType == "OTFS" || ModulatorType == "SCFDMA"
                baseModulatorType = randsample(["psk", "qam"], 1);
                ModulatorOrder = obj.ModulatorOrderPool.(ModulatorType).(upper(baseModulatorType))(randi(length(obj.ModulatorOrderPool.(ModulatorType).(upper(baseModulatorType)))));
            else
                ModulatorOrder = obj.ModulatorOrderPool.(ModulatorType)(randi(length(obj.ModulatorOrderPool.(ModulatorType))));
            end
            
            NumTransmitTimes = randi(obj.NumMaxTransmitTimes, 1);
            ys = cell(1, NumTransmitTimes);
            modulate = sprintf("%s(SampleRate=SampleRate, ModulatorOrder=ModulatorOrder, SamplePerSymbol=SamplePerSymbol, NumTransmitAntennas=NumTransmitAntennas)", ModulatorType);
            modulate = eval(modulate);
            if strcmpi(ModulatorType, 'OFDM') || strcmpi(ModulatorType, 'SCFDMA') || strcmpi(ModulatorType, 'OTFS')
                SamplePerSymbol = 1;
            end
            for i = 1:NumTransmitTimes
                TimeDuration = rand(1)*(obj.TxTimeDurationRange(2)-obj.TxTimeDurationRange(1))+obj.TxTimeDurationRange(1);
                if parentModulatorType == "analog"
                    source = Audio(SampleRate = SampleRate, TimeDuration = TimeDuration);
                    NumTransmitAntennas = 1;
                else
                    source = RandomSource(SampleRate=SampleRate, ...
                        TimeDuration=TimeDuration, ...
                        ModulatorOrder=ModulatorOrder, ...
                        SamplePerSymbol=SamplePerSymbol);
                end
                x = source();
                y = modulate(x);
                y.ModulatorType = ModulatorType;
                ys{1, i} = y;
            end
        end
        
        function xs = tilingTx(obj, xs)
            
            % 打乱顺序
            % 本质上采取的是一种类似贴瓷砖的策略，针对单个发射机，按照时域将数据依次排开
            % 紧接着，按照频域将数据依次排开
            num_tx = length(xs);
            mf = min(obj.TxMasterClockRateRange)/2-1e4;
            base_frequency = randi(10, 1)*1e4;
            
            current_frequnecy_delta = 0;
            for i=1:num_tx
                
                min_left = 0;
                max_right = 0;
                for j=1:length(xs{i})
                    if xs{i}{j}.BandWidth(1) < min_left
                        min_left = xs{i}{j}.BandWidth(1);
                    end
                    if xs{i}{j}.BandWidth(2) > max_right
                        max_right = xs{i}{j}.BandWidth(2);
                    end
                end
                current_band_width = max_right - min_left;
                % randi(100, 1)*1e2 随机设置的两个信号间的频率间隔
                move_step = current_band_width + randi(100, 1)*1e3;
                if obj.IsOverlap
                    if rand(1) < 0.1
                        move_step = (1 - rand(1)*(obj.FrequencyOverlapRadioRange(2)-obj.FrequencyOverlapRadioRange(1))) * current_band_width;
                    end
                end
                move_step = floor(move_step/100)*100;
                current_frequnecy_delta =  current_frequnecy_delta + move_step;
                
                if (current_frequnecy_delta + base_frequency + (2^randi(10, 1))*1e2) > mf
                    if i>1
                        xs = xs(1:i-1);
                        if i-1==1
                            xs = {xs};
                        end
                        break;
                    else
                        xs = [];
                        break;
                    end
                end
                current_start_time = 0;
                CarrierFrequency = current_frequnecy_delta + base_frequency - max_right;
                for j=1:length(xs{i})
                    x = xs{i}{j};
                    item_start_time = current_start_time + rand(1)*0.001;
                    x.StartTime = item_start_time;
                    x.CarrierFrequency = CarrierFrequency;
                    current_start_time = item_start_time + x.TimeDuration;
                    xs{i}{j} = x;
                end
                
            end
            
        end
        
        function y = transmit(obj, x)
            OutputPower = rand(1)*(obj.TxOutputPowerRange(2)-obj.TxOutputPowerRange(1))+obj.TxOutputPowerRange(1);
            MasterClockRate = randi((obj.TxMasterClockRateRange(2)-obj.TxMasterClockRateRange(1))/obj.MasterClockRateStep)*obj.MasterClockRateStep+obj.TxMasterClockRateRange(1);
            DCOffset = rand(1)*(obj.TxDCOffsetRange(2)-obj.TxDCOffsetRange(1))+obj.TxDCOffsetRange(1);
            
            IqImbalanceConfig.A = rand(1)*(obj.TxIqImbalaceConfigARange(2)-obj.TxIqImbalaceConfigARange(1))+obj.TxIqImbalaceConfigARange(1);
            IqImbalanceConfig.P = rand(1)*(obj.TxIqImbalaceConfigPRange(2)-obj.TxIqImbalaceConfigPRange(1))+obj.TxIqImbalaceConfigPRange(1);
            
            PhaseNoiseConfig.Level = randi(obj.TxPhaseNoiseConfigLevel(2)-obj.TxPhaseNoiseConfigLevel(1))+obj.TxPhaseNoiseConfigLevel(1);
            PhaseNoiseConfig.FrequencyOffset = randi(obj.TxPhaseNoiseConfigFrequencyOffset(2)-obj.TxPhaseNoiseConfigFrequencyOffset(1))+obj.TxPhaseNoiseConfigFrequencyOffset(1);
            "MemoryLessNonlinearityConfig" = MemoryLessNonlinearityRandom(obj.MemoryLessNonlinearityCfgFilePath);

            TxSiteConfig.owner = "Shuo Chang";
            TxSiteConfig.location = "Beijing";
            currentTime = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
            TxSiteConfig.Name = sprintf('Tx_%s_%s_%s', TxSiteConfig.owner, TxSiteConfig.location, currentTime);
            txRF = TRFSimulator(MasterClockRate=MasterClockRate, IqImbalanceConfig=IqImbalanceConfig, ...
                                DCOffset=DCOffset, OutputPower=OutputPower, PhaseNoiseConfig=PhaseNoiseConfig, ...
                                MemoryLessNonlinearityConfig=MemoryLessNonlinearityConfig, TxSiteConfig=TxSiteConfig);
            y = cell(1, length(x));
            for partId = 1:length(x)
                y{1, partId} = txRF(x{1, partId});
            end
        end

        function y = channel(obj, x)
            % 确定接收机的天线数
            if rand(1) < 0.9
                NumReceiveAntennas = randi(obj.NumReceiveAntennnasRange(2)-obj.NumReceiveAntennnasRange(1))+obj.NumReceiveAntennnasRange(1);
            else
                NumReceiveAntennas = 1;
            end
            y = cell(1, length(x));
            for txId=1:length(x)

                delay_num = randi(3, 1);
                PathDelays = zeros(1, delay_num+1);
                PathDelays(1) = 0;
                if randi(2) == 1
                    % indoor
                    Distance = randi(10, 1); % m
                    PathDelays(2:end) = 10.^(sort(randi(3, 1, delay_num))-10);
                else
                    % outdoor
                    Distance = randi(10, 1)*1000; % m
                    PathDelays(2:end) = 10.^(sort(randi(3, 1, delay_num))-8);
                end

                % The dB values in a vector of average path gains often decay roughly linearly as a function of delay, but the specific delay profile depends on the propagation environment.
                AveragePathGains = linspace(0, -20, delay_num + 1); % Example: decay from 0 dB to -20 dB

                % 28m/s is the max speed about car in 100Km/s
                % 1m/s is the 1.5m/s
                Speed = rand(1)*(28-1.5)+1.5;
                MaximumDopplerShift = x{txId}{1}.CarrierFrequency * Speed / 3 / 10^8;

                % https://www.mathworks.com/help/comm/ug/fading-channels.html
                if randi(2) == 1
                    KFactor = rand(1)*9+1;
                    FadingDistribution ="Rician";
                else
                    KFactor = 0;
                    FadingDistribution = "Rayleigh";
                end

                current_channel = "MIMO";
                % 根据字符串选择不同的类
                switch current_channel
                    case "MIMO"
                        channel = MIMO(PathDelays=PathDelays, AveragePathGains=AveragePathGains, ...
                            MaximumDopplerShift=MaximumDopplerShift, KFactor=KFactor, Distance=Distance, ...
                                FadingTechnique="Sum of sinusoids", InitialTimeSource="Input port", ...
                            NumTransmitAntennas=x{txId}{1}.NumTransmitAntennas, NumReceiveAntennas=NumReceiveAntennas, ...
                            FadingDistribution=FadingDistribution);
                    otherwise
                        error('Unknown channel type');
                end

                sub_y = cell(1, length(x{txId}));
                for partId=1:length(x{txId})
                    sub_y{partId} = channel(x{txId}{partId});
                end
                y{txId} = sub_y;
            end

        end

        function y = receive(obj, x)
            MasterClockRate = randi((obj.RxMasterClockRateRange(2)-obj.RxMasterClockRateRange(1))/obj.MasterClockRateStep)*obj.MasterClockRateStep+obj.RxMasterClockRateRange(1);
            DCOffset = rand(1)*(obj.RxDCOffsetRange(2)-obj.RxDCOffsetRange(1))+obj.RxDCOffsetRange(1);

            IqImbalanceConfig.A = rand(1)*(obj.RxIqImbalaceConfigARange(2)-obj.RxIqImbalaceConfigARange(1))+obj.RxIqImbalaceConfigARange(1);
            IqImbalanceConfig.P = rand(1)*(obj.RxIqImbalaceConfigPRange(2)-obj.RxIqImbalaceConfigPRange(1))+obj.RxIqImbalaceConfigPRange(1);

            ThermalNoiseConfig.NoiseFigure = rand(1)*(obj.ThermalNoiseConfigNoiseFigure(2)-obj.ThermalNoiseConfigNoiseFigure(1))+obj.ThermalNoiseConfigNoiseFigure(1);
            
            MemoryLessNonlinearityConfig = MemoryLessNonlinearityRandom(obj.MemoryLessNonlinearityCfgFilePath);

            RxSiteConfig.owner = "Shuo Chang";
            RxSiteConfig.location = "Beijing";
            currentTime = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
            RxSiteConfig.Name = sprintf('Rx_%s_%s_%s', RxSiteConfig.owner, RxSiteConfig.location, currentTime);
            TimeDuration = 0.1;
            NumReceiveAntennas = x{1}{1}.NumReceiveAntennas;
            rxRF = RRFSimulator(MasterClockRate=MasterClockRate, IqImbalanceConfig=IqImbalanceConfig, ...
                                DCOffset=DCOffset, ThermalNoiseConfig=ThermalNoiseConfig, TimeDuration = TimeDuration, ...
                                NumReceiveAntennas=NumReceiveAntennas, MemoryLessNonlinearityConfig=MemoryLessNonlinearityConfig, RxSiteConfig=RxSiteConfig);
            
            y = rxRF(x);
        end            
    end
    
end


