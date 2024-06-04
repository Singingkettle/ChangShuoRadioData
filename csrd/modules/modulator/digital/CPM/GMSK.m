classdef GMSK < FSK
    
    methods
        
        function modulatorHandle = genModulatorHandle(obj)
            
            obj.IsDigital = true;
            obj.NumTransmitAntennnas = 1;
            obj.pureModulator = comm.GMSKModulator( ...
                BitInput = true, ...
                BandwidthTimeProduct = obj.ModulatorConfig.BandwidthTimeProduct, ...
                PulseLength = obj.ModulatorConfig.PulseLength, ...
                SymbolPrehistory = obj.ModulatorConfig.SymbolPrehistory, ...
                InitialPhaseOffset = obj.ModulatorConfig.InitialPhaseOffset, ...
                SamplesPerSymbol = obj.SamplePerSymbol);
            modulatorHandle = @(x)obj.baseModulator(x);
            
        end
        
    end
    
end
