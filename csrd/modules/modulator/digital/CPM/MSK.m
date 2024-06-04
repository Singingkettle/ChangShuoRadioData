classdef MSK < FSK
    
    methods
        
        function modulatorHandle = genModulatorHandle(obj)
            
            obj.IsDigital = true;
            obj.NumTransmitAntennnas = 1;
            obj.pureModulator = @(x)mskmod(x, ...
                obj.SamplePerSymbol, ...
                obj.ModulatorConfig.DataEncode, ...
                obj.ModulatorConfig.InitPhase);
            modulatorHandle = @(x)obj.baseModulator(x);
            
        end
        
    end
    
end
