classdef SSBAM < DSBSCAM
    
    methods (Access = protected)
        
        function [y, bw] = baseModulation(obj, x)
            
            if strcmp(obj.ModulationConfig.mode, 'upper')
                y = complex(x, imag(hilbert(x)));
            else
                y = complex(x, -imag(hilbert(x)));
            end
            bw = obw(x, obj.SampleRate)*2;
            
        end
        
    end
    
end
