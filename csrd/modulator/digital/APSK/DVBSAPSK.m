classdef DVBSAPSK < APSK
    % 关于DVBSAPSK的调制器参数取值，请参考
    % https://www.mathworks.com/help/comm/ref/dvbsapskmod.html#mw_c8c83d0e-4cb9-4aa7-bf44-92d4e39be3c9
    
    methods (Access = protected)
        
        function [y, bw] = baseModulator(obj, x)
            
            % Modulate
            x = dvbsapskmod(x, obj.ModulationOrder, ...
                obj.ModulatorConfig.stdSuffix, ...
                obj.ModulatorConfig.codeIDF, ...
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
