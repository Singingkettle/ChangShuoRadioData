classdef DVBSAPSK < APSK

    methods (Access = protected)

        function y = baseModulator(obj, x)

            % Modulate
            x = dvbsapskmod(x, obj.ModulationOrder, ...
                obj.ModulatorConfig.stdSuffix, ...
                obj.ModulatorConfig.codeIDF, ...
                UnitAveragePower = true);
            x = obj.ostbc(x);

            % Pulse shape
            y = filter(obj.filterCoeffs, 1, upsample(x, obj.SamplePerSymbol));

        end

    end

end
