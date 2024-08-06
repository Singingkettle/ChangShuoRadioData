classdef SSBAM < DSBSCAM
    
    methods (Access = protected)
        
        function [y, bw] = baseModulator(obj, x)

            if strcmp(obj.ModulatorConfig.mode, 'upper')
                y = complex(x, imag(hilbert(x)));
                bw = [0, obw(x, obj.SampleRate)];
            else
                y = complex(x, -imag(hilbert(x)));
                bw = [-obw(x, obj.SampleRate), 0];
            end
            
        end
        
    end
    
    methods
    
        function modulatorHandle = genModulatorHandle(obj)
            
            if ~isfield(obj.ModulatorConfig, 'mode')
                obj.ModulatorConfig.mode = randsample(["upper", "lower"], 1);
            end
            obj.IsDigital = false;
            % donot consider multi-tx in analog modulation
            obj.NumTransmitAntennas = 1;
            modulatorHandle = @(x)obj.baseModulator(x);
            
        end
        
    end
end
