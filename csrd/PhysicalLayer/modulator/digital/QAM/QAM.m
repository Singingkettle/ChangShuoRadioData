classdef QAM < APSK
    
    methods (Access = protected)
        
        function [y, bw] = baseModulation(obj, x)
            % Modulate
            x = qammod(x, obj.ModulationOrder, obj.ModulationConfig.SymbolOrder, ...
                UnitAveragePower = true);
            x = obj.ostbc(x);
            
            % Pulse shape
            y = filter(obj.filterCoeffs, 1, upsample(x, obj.SamplePerSymbol));

            bw = obw(y, obj.SampleRate);
            if obj.NumTransmitAntennnas > 1
                bw = max(bw);
            end
            
        end
        
    end
    
end
