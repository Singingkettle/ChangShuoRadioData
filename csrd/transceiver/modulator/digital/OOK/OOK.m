classdef OOK < APSK
    methods (Access = protected)

        function y = baseModulator(obj, x)

            % Pulse shape
            y = filter(obj.filterCoeffs, 1, upsample(x, obj.SamplePerSymbol));

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            obj.filterCoeffs = obj.genFilterCoeffs;
            modulatorHandle = @(x)obj.baseModulator(x);
            obj.NumTransmitAntennnas = 1;
            obj.IsDigital = true;
            obj.ModulationOrder = 2;
        end

    end

end
