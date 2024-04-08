classdef MSK < FSK

    methods

        function modulatorHandle = genModulator(obj)
            modulatorHandle = @(x)mskmod(x, ...
                obj.SamplePerSymbol, ...
                obj.ModulatorConfig.DataEncode, ...
                obj.ModulatorConfig.InitPhase);
            obj.NumTransmitAntennnas = 1;
            obj.isDigital = true;
        end

    end

end
