classdef PM < BaseModulation
    
    methods (Access = private)
        
        function [y, bw] = baseModulation(obj, x)
            
            y = complex(cos(obj.ModulationConfig.PhaseDeviation * x + ...
                obj.ModulationConfig.InitPhase), ...
                sin(obj.ModulationConfig.PhaseDeviation * x + ...
                obj.ModulationConfig.InitPhase));
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
