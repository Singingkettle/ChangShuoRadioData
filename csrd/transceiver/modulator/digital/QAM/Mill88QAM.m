classdef Mill88QAM < APSK

    methods (Access = protected)

        function [y, bw] = baseModulator(obj, x)
            % Modulate
            x = mil188qammod(x, obj.ModulationOrder, ...
                UnitAveragePower = true);
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
