classdef FSK < BaseModulator
    
    properties
        
        SamplePerSymbol (1, 1) {mustBePositive, mustBeReal} = 2
        
    end
    
    properties (Access=private)
        freq_sep
    end

    properties
        pureModulator
        
    end
    
    methods (Access = protected)
        
        function [y, bw] = baseModulator(obj, x)
            y = obj.pureModulator(x);
            if isprop(obj, 'freq_sep')
                bw = obj.freq_sep * obj.ModulationOrder;
            else
                bw = obw(y, obj.SampleRate);
            end

        end
    end
    
    methods
        
        function modulatorHandle = genModulatorHandle(obj)
            
            obj.IsDigital = true;
            obj.NumTransmitAntennnas = 1;
            max_freq_sep = obj.SampleRate / (obj.ModulationOrder - 1);
            obj.freq_sep = (rand(1)*0.1+0.4)*max_freq_sep;

            obj.pureModulator = @(x)fskmod(x, ...
                obj.ModulationOrder, ...
                obj.freq_sep, ...
                obj.SamplePerSymbol, ...
                obj.SampleRate, ...
                'discont', ...
                obj.ModulatorConfig.SymbolOrder);
            modulatorHandle = @(x)obj.baseModulator(x);
        end
        
    end
    
end
