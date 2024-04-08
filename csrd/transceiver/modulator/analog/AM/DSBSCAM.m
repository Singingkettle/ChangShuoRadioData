classdef DSBSCAM < BaseModulator

    methods (Access = protected)

        function y = baseModulator(obj, x)

            x = lowpass(x, 30e3, obj.SampleRate, ImpulseResponse = "fir", Steepness = 0.99);
            y = x;

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)

            modulatorHandle = @(x)obj.baseModulator(x);
            obj.IsDigital = false;
            % donot consider multi-tx in analog modulation
            obj.NumTransmitAntennnas = 1;

        end

    end

end
