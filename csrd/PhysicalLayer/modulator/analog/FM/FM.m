classdef FM < BaseModulation
    
    methods (Access = private)
        
        function [y, bw] = baseModulation(obj, x)
            
            intY = cast(0, class(x)) + cumsum(x)/obj.SampleRate;
            y = exp(1i*2*pi*obj.ModulationConfig.FrequencyDeviation*intY);
            bw = obw(y, obj.SampleRate);
        end
        
    end
    
    methods
        
        function modulatorHandle = genModulationHandle(obj)
            
            obj.IsDigital = false;
            % donot consider multi-tx in analog modulation
            obj.NumTransmitAntennnas = 1;
            modulatorHandle = @(x)obj.baseModulation(x);
            
        end
        
    end
    
end
