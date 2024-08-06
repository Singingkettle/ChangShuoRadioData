classdef MSK < FSK
    
    methods
        
        function modulatorHandle = genModulatorHandle(obj)
            
            obj.IsDigital = true;
            obj.NumTransmitAntennas = 1;
            if ~isfield(obj.ModulatorConfig, 'DataEncode')
                obj.ModulatorConfig.DataEncode = randsample(["diff", "nondiff"], 1);
                obj.ModulatorConfig.InitPhase = rand(1)*2*pi;
            end
            obj.pureModulator = @(x)mskmod(x, ...
                obj.SamplePerSymbol, ...
                obj.ModulatorConfig.DataEncode, ...
                obj.ModulatorConfig.InitPhase);
            modulatorHandle = @(x)obj.baseModulator(x);
            
        end
        
    end
    
end
