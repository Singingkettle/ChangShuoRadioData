classdef SSBAM < DSBSCAM

    methods (Access = protected)

        function [y, bw] = baseModulator(obj, x)

            if strcmp(obj.ModulatorConfig.mode, 'upper')
                y = complex(x, imag(hilbert(x)));
            else
                y = complex(x, -imag(hilbert(x)));
            end
            
            bw = obw(y, obj.SampleRate);

        end

    end

end
