classdef OQPSK < APSK
    
    properties
        
        pureModulation
        
    end
    
    methods (Access = protected)
        
        function [y, bw] = baseModulation(obj, x)
            y = obj.pureModulation(x);

            bw = obw(y, obj.SampleRate);
            if obj.NumTransmitAntennnas > 1
                bw = max(bw);
            end
            
        end
        
    end
    
    methods
        
        function modulatorHandle = genModulationHandle(obj)
            obj.IsDigital = true;
            obj.filterCoeffs = obj.genFilterCoeffs;
            obj.ostbc = obj.genOSTBC;
            obj.pureModulation = BaseOQPSK( ...
                PhaseOffset = obj.ModulationConfig.PhaseOffset, ...
                SymbolMapping = obj.ModulationConfig.SymbolMapping, ...
                PulseShape = 'Root raised cosine', ...
                RolloffFactor = obj.ModulationConfig.beta, ...
                FilterSpanInSymbols = obj.ModulationConfig.span, ...
                SamplesPerSymbol = obj.SamplePerSymbol, ...
                NumTransmitAntennas = obj.NumTransmitAntennas, ...
                ostbc = obj.ostbc);
            
            modulatorHandle = @(x)obj.baseModulation(x);
            
        end
        
    end
    
end
