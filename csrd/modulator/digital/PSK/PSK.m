classdef PSK < APSK
    % 关于ostbc 与PRC的关系https://publik.tuwien.ac.at/files/pub-et_8438.pdf
    methods (Access = protected)
        
        function [y, bw] = baseModulator(obj, x)
            
            if obj.ModulatorConfig.Differential
                x = dpskmod(x, obj.ModulationOrder, obj.ModulatorConfig.PhaseOffset, obj.ModulatorConfig.SymbolOrder);
            else
                x = pskmod(x, obj.ModulationOrder, obj.ModulatorConfig.PhaseOffset, obj.ModulatorConfig.SymbolOrder);
            end
            
            x = obj.ostbc(x);
            
            % Pulse shape
            y = filter(obj.filterCoeffs, 1, upsample(x, obj.SamplePerSymbol));
            
            bw = obw(y, obj.SampleRate, [], 99.99999);
            if obj.NumTransmitAntennnas > 1
                bw = max(bw);
            end
            
        end
        
    end
    
end
