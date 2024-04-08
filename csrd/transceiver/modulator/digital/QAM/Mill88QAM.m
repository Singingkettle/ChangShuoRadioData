classdef Mill88QAM < APSK

    methods (Access = protected)

        function y = baseModulator(obj, x)
            % Modulate
            x = mil188qammod(x, obj.ModulatorConfig.order, ...
                UnitAveragePower = true);
            x = obj.ostbc(x);

            % Pulse shape
            y = filter(obj.filterCoeffs, 1, upsample(x, obj.SamplePerSymbol));

        end

    end

end
