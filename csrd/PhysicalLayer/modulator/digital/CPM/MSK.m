classdef MSK < FSK
    
    methods
        
        function modulatorHandle = genModulationHandle(obj)
            
            obj.IsDigital = true;
            obj.NumTransmitAntennnas = 1;
            obj.pureModulation = @(x)mskmod(x, ...
                obj.SamplePerSymbol, ...
                obj.ModulationConfig.DataEncode, ...
                obj.ModulationConfig.InitPhase);
            modulatorHandle = @(x)obj.baseModulation(x);
            
        end
        
    end
    
end
