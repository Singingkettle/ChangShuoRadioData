classdef QAM < APSK

    methods (Access = protected)

        function y = baseModulator(obj, x)
            % Modulate
            x = qammod(x, obj.ModulationOrder, obj.ModulatorConfig.SymbolOrder, ...
                UnitAveragePower = true);
            x = obj.ostbc(x);

            % Pulse shape
            y = filter(obj.filterCoeffs, 1, upsample(x, obj.SamplePerSymbol));

        end

    end

end
