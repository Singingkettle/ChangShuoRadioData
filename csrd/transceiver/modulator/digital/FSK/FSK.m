classdef FSK < BaseModulator

    properties

        SamplePerSymbol (1, 1) {mustBePositive, mustBeReal} = 2

    end

    methods

        function modulatorHandle = genModulator(obj)
            modulatorHandle = @(x)fskmod(x, ...
                obj.ModulatorConfig.order, ...
                obj.SampleRate / obj.SamplePerSymbol / 2, ...
                obj.SamplePerSymbol, ...
                obj.SampleRate, ...
                'discont', ...
                obj.ModulatorConfig.SymbolOrder);
            obj.NumTransmitAntennnas = 1;
            obj.IsDigital = true;
        end

    end

end
