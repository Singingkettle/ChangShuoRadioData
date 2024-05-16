classdef ASK < APSK

    methods (Access = protected)

        function [y, bw] = baseModulator(obj, x)

            amp = 1 / sqrt(mean(abs(pammod(0:obj.ModulationOrder - 1, obj.ModulationOrder)) .^ 2));
            % Modulate
            x = amp * pammod(x, obj.ModulationOrder);
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
