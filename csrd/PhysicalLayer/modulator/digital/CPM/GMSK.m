classdef GMSK < FSK
    
    methods
        
        function modulatorHandle = genModulationHandle(obj)
            
            obj.IsDigital = true;
            obj.NumTransmitAntennnas = 1;
            obj.pureModulation = comm.GMSKModulation( ...
                BitInput = true, ...
                BandwidthTimeProduct = obj.ModulationConfig.BandwidthTimeProduct, ...
                PulseLength = obj.ModulationConfig.PulseLength, ...
                SymbolPrehistory = obj.ModulationConfig.SymbolPrehistory, ...
                InitialPhaseOffset = obj.ModulationConfig.InitialPhaseOffset, ...
                SamplesPerSymbol = obj.SamplePerSymbol);
            modulatorHandle = @(x)obj.baseModulation(x);
            
        end
        
    end
    
end
