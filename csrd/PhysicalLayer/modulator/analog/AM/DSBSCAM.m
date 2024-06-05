classdef DSBSCAM < BaseModulation
    
    methods (Access = protected)
        
        function [y, bw] = baseModulation(obj, x)
            if hasfield(obj.ModulationConfig, 'initPhase')
                obj.ModulationConfig.initPhase = 0;
            end
            y = x;
            bw = obw(y, obj.SampleRate)*2;
            
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
