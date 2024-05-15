classdef FM < BaseModulator

    methods (Access = private)

        function [y, bw] = baseModulator(obj, x)

            intY = cast(0, class(x)) + cumsum(x)/obj.SampleRate;
            y = exp(1i*2*pi*obj.ModulatorConfig.FrequencyDeviation*intY);
            bw = obw(y, obj.SampleRate, [], 99.99999);
        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            
            obj.IsDigital = false;
            % donot consider multi-tx in analog modulation
            obj.NumTransmitAntennnas = 1; 
            modulatorHandle = @(x)obj.baseModulator(x);
            
        end

    end

end
