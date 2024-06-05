classdef OOK < APSK
    
    methods (Access = protected)
        
        function [y, bw] = baseModulation(obj, x)
            
            % Pulse shape
            y = filter(obj.filterCoeffs, 1, upsample(x, obj.SamplePerSymbol));

            bw = obw(y, obj.SampleRate)*2;
            if obj.NumTransmitAntennnas > 1
                bw = max(bw);
            end
            
        end
        
    end
    
    methods
        
        function modulatorHandle = genModulationHandle(obj)
            
            obj.IsDigital = true;
            obj.NumTransmitAntennnas = 1;
            obj.ModulationOrder = 2;
            obj.filterCoeffs = obj.genFilterCoeffs;
            modulatorHandle = @(x)obj.baseModulation(x);
            
        end
        
    end
    
end
