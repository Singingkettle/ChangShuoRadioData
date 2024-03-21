classdef BaseModulator < matlab.System

    properties
        % RF impairments
        iqImbalanceConfig % only used in the digital modulation
        phaseNoiseConfig
        memoryLessNonlinearityConfig        

        % Modulate parameters
        modulatorConfig
        carrierFrequency
        timeDuration
        sampleRate
        samplePerSymbol

        % Digital Sign
        isDigital

        
    end

    properties (Dependent)
        % RF handles
        iqImbalance
        phaseNoise
        memoryLessNonlinearity

        % Modulate handle
        modulator
        carrierWave

        % Other parameter
        samplePerFrame
        
        % Passband
        isPassBand
    end

    methods
        function iqImbalance = get.iqImbalance(obj)
            % https://www.mathworks.com/help/comm/ref/iqimbal.html
            iqImbalance = @(x)iqimbal(x, ...
                obj.iqImbalanceConfig.A, ...
                obj.iqImbalanceConfig.P);

        end
        
        function phaseNoise = get.phaseNoise(obj)
            % https://www.mathworks.com/help/comm/ref/comm.phasenoise-system-object.html
            phaseNoise = comm.PhaseNoise( ...
                Level=obj.phaseNoiseConfig.Level, ...
                FrequencyOffset=obj.phaseNoiseConfig.FrequencyOffset, ...
                SampleRate=obj.sampleRate, ...
                RandomStream=obj.phaseNoiseConfig.RandomStream, ...
                Seed=obj.phaseNoiseConfig.Seed);
        end

        function samplePerFrame = get.samplePerFrame(obj)
            samplePerFrame = obj.timeDuration * obj.sampleRate;
            samplePerFrame = round(samplePerFrame);
        end
    
        function memoryLessNonlinearity = get.memoryLessNonlinearity(obj)
            if strcmp(obj.memoryLessNonlinearityConfig.Method, 'Cubic polynomial')
                memoryLessNonlinearity = comm.MemorylessNonlinearity( ...
                    Method='Cubic polynomial', ...
                    LinearGain=obj.memoryLessNonlinearityConfig.LinearGain, ...
                    TOISpecification=obj.memoryLessNonlinearityConfig.TOISpecification, ...
                    IIP3=obj.memoryLessNonlinearityConfig.IIP3);

                if strcmp(obj.memoryLessNonlinearityConfig.TOISpecification, 'OIP3')
                    memoryLessNonlinearity.OIP3 = obj.memoryLessNonlinearityConfig.OIP3;
                elseif strcmp(obj.memoryLessNonlinearityConfig.TOISpecification, 'IP1dB')
                    memoryLessNonlinearity.IP1dB = obj.memoryLessNonlinearityConfig.IP1dB;
                elseif strcmp(obj.memoryLessNonlinearityConfig.TOISpecification, 'OP1dB')
                    memoryLessNonlinearity.OP1dB = obj.memoryLessNonlinearityConfig.OP1dB;
                elseif strcmp(obj.memoryLessNonlinearityConfig.TOISpecification, 'IPsat')
                    memoryLessNonlinearity.IPsat = obj.memoryLessNonlinearityConfig.IPsat;
                elseif strcmp(obj.memoryLessNonlinearityConfig.TOISpecification, 'OPsat')
                    memoryLessNonlinearity.OPsat = obj.memoryLessNonlinearityConfig.OPsat;
                end
                memoryLessNonlinearity.AMPMConversion = obj.memoryLessNonlinearityConfig.AMPMConversion;
                memoryLessNonlinearity.PowerLowerLimit = obj.memoryLessNonlinearityConfig.PowerLowerLimit;
                memoryLessNonlinearity.PowerUpperLimit = obj.memoryLessNonlinearityConfig.PowerUpperLimit;
            elseif strcmp(obj.memoryLessNonlinearityConfig.Method, 'Hyperbolic tangent')
                memoryLessNonlinearity = comm.MemorylessNonlinearity( ...
                    Method='Hyperbolic tangent', ...
                    LinearGain=obj.memoryLessNonlinearityConfig.LinearGain, ...
                    IIP3=obj.memoryLessNonlinearityConfig.IIP3);
                memoryLessNonlinearity.AMPMConversion = obj.memoryLessNonlinearityConfig.AMPMConversion;
                memoryLessNonlinearity.PowerLowerLimit = obj.memoryLessNonlinearityConfig.PowerLowerLimit;
                memoryLessNonlinearity.PowerUpperLimit = obj.memoryLessNonlinearityConfig.PowerUpperLimit;
          
            elseif strcmp(obj.memoryLessNonlinearityConfig.Method, 'Saleh model') || strcmp(obj.memoryLessNonlinearityConfig.Method, 'Ghorbani model')
                memoryLessNonlinearity = comm.MemorylessNonlinearity( ...
                    Method=obj.memoryLessNonlinearityConfig.Method, ...
                    InputScaling=obj.memoryLessNonlinearityConfig.InputScaling, ...
                    AMAMParameters=obj.memoryLessNonlinearityConfig.AMAMParameters, ...
                    AMPMParameters=obj.memoryLessNonlinearityConfig.AMPMParameters, ...
                    OutputScaling=obj.memoryLessNonlinearityConfig.OutputScaling);
            elseif strcmp(obj.memoryLessNonlinearityConfig.Method, 'Modified Rapp model')
                memoryLessNonlinearity = comm.MemorylessNonlinearity( ...
                    Method='Modified Rapp model', ...
                    LinearGain=obj.memoryLessNonlinearityConfig.LinearGain, ...
                    Smoothness=obj.memoryLessNonlinearityConfig.Smoothness, ... 
                    PhaseGainRadian=obj.memoryLessNonlinearityConfig.PhaseGainRadian, ...
                    PhaseSmoothness=obj.memoryLessNonlinearityConfig.PhaseSmoothness, ...
                    OutputSaturationLevel=obj.memoryLessNonlinearityConfig.OutputSaturationLevel);
            elseif strcmp(obj.memoryLessNonlinearityConfig.Method, 'Lookup table')
                memoryLessNonlinearity = comm.MemorylessNonlinearity( ...
                    Method='Look table', ...
                    Table=obj.memoryLessNonlinearityConfig.Table);
            end
            memoryLessNonlinearity.ReferenceImpedance = obj.memoryLessNonlinearityConfig.ReferenceImpedance;
        end

        function modulator = get.modulator(obj)
            modulator = obj.getModulator();
        end

        function carrierWave = get.carrierWave(obj)
            sin_wave = dsp.SineWave( ...
                Frequency = obj.carrierFrequency, ...
                SampleRate = obj.sampleRate, ...
                ComplexOutput = false, ...
                SamplesPerFrame = obj.samplePerFrame, ...
                PhaseOffset = 0);
            cos_wave = dsp.SineWave( ...
                Frequency = obj.carrierFrequency, ...
                SampleRate = obj.sampleRate, ...
                ComplexOutput = false, ...
                SamplesPerFrame = obj.samplePerFrame, ...
                PhaseOffset = pi / 2);
            carrierWave = complex(cos_wave(), sin_wave());

        end
        
        function isPassBand =  get.isPassBand(obj)
            if obj.carrierFrequency ~= 0
                isPassBand = true;
            else
                isPassBand = False;
            end
        end
    end

    methods

        function obj = BaseModulator(param)
            % 
            obj.iqImbalanceConfig = param.iqImbalanceConfig;
            obj.phaseNoiseConfig = param.phaseNoiseConfig;
            obj.memoryLessNonlinearityConfig = param.memoryLessNonlinearityConfig;

            % 
            obj.carrierFrequency = param.carrierFrequency;
            obj.timeDuration = param.timeDuration;
            obj.sampleRate = param.sampleRate;
            obj.modulatorConfig = param.modulatorConfig;
            obj.samplePerSymbol = param.samplePerSymbol;

        end

    end
    
    methods

    end
    
    methods (Abstract)
        y = passBand(obj, x)
        y = getModulator(obj)
        y = bandWidth(obj, x)
            
    end

    methods (Access = protected)
        
        function y = placeHolder(obj, x)
                y = x;
        end

        function [y, bw]= stepImpl(obj, x)
            x = obj.modulator(x);
            bw = obj.bandWidth(x);
            if obj.isDigital
                x = obj.iqImbalance(x);
            end
            x = obj.passBand(x);
            y = obj.phaseNoise(x);
        end

    end

end
