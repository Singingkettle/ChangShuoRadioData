classdef FSK < BaseModulation
    
    properties
        
        SamplePerSymbol (1, 1) {mustBePositive, mustBeReal} = 2
        
    end
    
    properties (Access=private)
        freq_sep
    end

    properties
        pureModulation
        
    end
    
    methods (Access = protected)
        
        function [y, bw] = baseModulation(obj, x)
            y = obj.pureModulation(x);
            if isprop(obj, 'freq_sep')
                bw = obj.freq_sep * obj.ModulationOrder;
            else
                bw = obw(y, obj.SampleRate);
            end

        end
    end
    
    methods
        
        function modulatorHandle = genModulationHandle(obj)
            
            obj.IsDigital = true;
            obj.NumTransmitAntennnas = 1;
            max_freq_sep = obj.SampleRate / (obj.ModulationOrder - 1);
            obj.freq_sep = (rand(1)*0.1+0.4)*max_freq_sep;

            obj.pureModulation = @(x)fskmod(x, ...
                obj.ModulationOrder, ...
                obj.freq_sep, ...
                obj.SamplePerSymbol, ...
                obj.SampleRate, ...
                'discont', ...
                obj.ModulationConfig.SymbolOrder);
            modulatorHandle = @(x)obj.baseModulation(x);
        end
        
    end
    
end
