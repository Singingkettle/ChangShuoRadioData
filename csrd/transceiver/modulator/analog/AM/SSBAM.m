classdef SSBAM < DSBSCAM

    methods (Access = protected)

        function y = baseModulator(obj, x)

            x = lowpass(x, 30e3, obj.SampleRate, ImpulseResponse = "fir", Steepness = 0.99);

            if strcmp(obj.ModulatorConfig.mode, 'upper')
                y = complex(x, imag(hilbert(x)));
            else
                y = complex(x, -imag(hilbert(x)));
            end

        end

    end

end
