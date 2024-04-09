classdef MSK < FSK

    methods

        function modulatorHandle = genModulatorHandle(obj)
            modulatorHandle = @(x)mskmod(x, ...
                obj.SamplePerSymbol, ...
                obj.ModulatorConfig.DataEncode, ...
                obj.ModulatorConfig.InitPhase);
            obj.NumTransmitAntennnas = 1;
            obj.IsDigital = true;
        end

    end

end
