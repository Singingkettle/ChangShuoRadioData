classdef DSBAM < DSBSCAM

    methods (Access = protected)

        function y = baseModulator(obj, x)

            x = lowpass(x, 30e3, obj.SampleRate, ImpulseResponse = "fir", Steepness = 0.99);
            y = x + obj.ModulatorConfig.carramp;

        end

    end

end
