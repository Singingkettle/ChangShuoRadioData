classdef SSBAM < DSBSCAM
    
    methods (Access = protected)
        
        function [y, bw] = baseModulator(obj, x)
            
            if strcmp(obj.ModulatorConfig.mode, 'upper')
                y = complex(x, imag(hilbert(x)));
            else
                y = complex(x, -imag(hilbert(x)));
            end
            bw = obw(x, obj.SampleRate)*2;
            
        end
        
    end
    
end
