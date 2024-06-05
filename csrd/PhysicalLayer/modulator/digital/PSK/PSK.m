classdef PSK < APSK
    % 关于ostbc 与PRC的关系https://publik.tuwien.ac.at/files/pub-et_8438.pdf
    methods (Access = protected)
        
        function [y, bw] = baseModulation(obj, x)
            
            if obj.ModulationConfig.Differential
                x = dpskmod(x, obj.ModulationOrder, obj.ModulationConfig.PhaseOffset, obj.ModulationConfig.SymbolOrder);
            else
                x = pskmod(x, obj.ModulationOrder, obj.ModulationConfig.PhaseOffset, obj.ModulationConfig.SymbolOrder);
            end
            
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
