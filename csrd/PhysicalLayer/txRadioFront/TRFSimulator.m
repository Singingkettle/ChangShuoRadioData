classdef TRFSimulator < matlab.System
    % https://www.mathworks.com/help/comm/ug/end-to-end-qam-simulation-with-rf-impairments-and-corrections.html
    % The simulation of transminter is based on the function
    % "QAMwithRFImpairmentsSim" of the aformentioned example.
    % Where the txGain is not defined in our code.
    % 此外我们还参考了USRP的零中频设计架构实现发射器模拟
    % https://kb.ettus.com/UHD
    % https://zhuanlan.zhihu.com/p/24217098
    % https://www.mathworks.com/help/simrf/ug/modeling-an-rf-mmwave-transmitter-with-hybrid-beamforming.html
    % =====================================================================
    % 关于发射机的模拟，里面的射频损失主要是依据论文："ORACLE: Optimized Radio
    % clAssification through Convolutional neuraL nEtworks"和USRP官网给出的
    % 关于硬件示意图：https://kb.ettus.com/UHD
    % 其中，DUC的两个关键参数作用：https://blog.csdn.net/u010565765/article/details/54925659/
    % DUC的取值主要参考这个链接：https://www.mathworks.com/matlabcentral/answers/772293-passband-ripple-and-stopband-attenuation
    % =====================================================================
    
    properties
        
        AntennaEfficiency (1, 1) {mustBePositive, mustBeReal} = 0.5
        TransmitAntennaDiameter  (1, 1) {mustBePositive, mustBeReal} = 0.4
        OutputPower (1, 1) {mustBeReal} = -10 % dBm
        % Master clock rate, specified as a scalar in Hz. The master clock
        % rate is the A/D and D/A clock rate. The valid range of values for
        % this property depends on the radio platform that is connected.
        % This value depends on the ettus usrp devices.
        % Please refer:
        % https://www.mathworks.com/help/comm/usrpradio/ug/sdrutransmitter.html
        
        MasterClockRate (1, 1) {mustBePositive, mustBeReal} = 184.32e6
        DCOffset {mustBeReal} = -50
        
        TxSiteConfig = false
        IqImbalanceConfig struct
        PhaseNoiseConfig struct
        MemoryLessNonlinearityConfig struct
        
    end
    
    properties (Access = protected)
        
        IQImbalance
        PhaseNoise
        MemoryLessNonlinearity
        DUC
    end
    
    methods (Access = protected)
        
        function IQImbalance = genIqImbalance(obj)
            
            % https://www.mathworks.com/help/comm/ref/iqimbal.html
            IQImbalance = @(x)iqimbal(x, ...
                obj.IqImbalanceConfig.A, ...
                obj.IqImbalanceConfig.P);
            
        end
        
        function PhaseNoise = genPhaseNoise(obj)
            % https://www.mathworks.com/help/comm/ref/comm.phasenoise-system-object.html
            PhaseNoise = comm.PhaseNoise( ...
                Level = obj.PhaseNoiseConfig.Level, ...
                FrequencyOffset = obj.PhaseNoiseConfig.FrequencyOffset, ...
                SampleRate = obj.MasterClockRate);
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
            
            obj.IQImbalance = obj.genIqImbalance;
            obj.PhaseNoise = obj.genPhaseNoise;
            obj.MemoryLessNonlinearity = obj.genMemoryLessNonlinearity;
            
        end
        
        function out = stepImpl(obj, x)
            % Change the input signal sample rate as txrf's master clock
            % rate
            InterpDecim = fix(obj.MasterClockRate / x.SampleRate);
            obj.MasterClockRate = InterpDecim * x.SampleRate;
            hbw = max(abs(x.BandWidth));
            if strcmpi(x.ModulatorType, 'OFDM') || strcmpi(x.ModulatorType, 'SCFDMA') || strcmpi(x.ModulatorType, 'OTFS') || strcmpi(x.ModulatorType, 'CPFSK')
                bw = fix(hbw/1000)*1000*2;
            else
                bw = 2 * hbw;
            end
            src = dsp.SampleRateConverter( ...
                Bandwidth=bw, ...
                InputSampleRate=x.SampleRate, ...
                OutputSampleRate=obj.MasterClockRate, ...
                StopbandAttenuation=80);
            y = src(x.data);

            % y = x.data;
            % After that, add impairments
            y = obj.IQImbalance(y);
            y = y + 10 ^ (obj.DCOffset / 10);
            % release(obj.PhaseNoise);
            % obj.PhaseNoise.SampleRate = obj.MasterClockRate;
            % y = obj.PhaseNoise(y);
            y = obj.MemoryLessNonlinearity(y);

            % Then pass the rated signal through a low pass filter, to
            % supress the compenents of high frequency
            y = lowpass(y, max(abs(x.BandWidth)), obj.MasterClockRate, ...
                ImpulseResponse = "fir", Steepness = 0.9, ...
                StopbandAttenuation=100);

            % Transform the baseband to passband
            UpConverter = dsp.SineWave( ...
                Amplitude=1, ...
                Frequency=x.CarrierFrequency, ...
                PhaseOffset=0, ...
                ComplexOutput=true, ...
                SampleRate=obj.MasterClockRate, ...
                SamplesPerFrame=size(y, 1));
            y = y.*UpConverter();
            y = real(y);
            
            % To control the output power, we refer：
            % https://www.mathworks.com/help/comm/ref/comm.thermalnoise-system-object.html
            % y = (10^((obj.OutputPower-30)/20)) * y;
            
            out = x;
            out.data = y;
            out.DCOffset = obj.DCOffset;
            out.IqImbalanceConfig = obj.IqImbalanceConfig;
            out.MemoryLessNonlinearityConfig = obj.MemoryLessNonlinearityConfig;
            out.PhaseNoiseConfig = obj.PhaseNoiseConfig;
            out.SDRInterpDecim = InterpDecim;
            out.SampleRate = obj.MasterClockRate;
            out.SamplePerFrame = size(y, 1);
            out.TimeDuration = out.SamplePerFrame / out.SampleRate;
            out.CarrierFrequency = x.CarrierFrequency;
            out.TxSiteConfig = obj.TxSiteConfig;
        end
        
    end
    
    methods
        
        function obj = TRFSimulator(varargin)
            
            setProperties(obj, nargin, varargin{:});
            
        end
        
    end
    
end
