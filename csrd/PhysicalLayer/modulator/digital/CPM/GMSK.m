classdef GMSK < FSK
    
    methods
        
        function modulatorHandle = genModulatorHandle(obj)
            
            obj.IsDigital = true;
            obj.NumTransmitAntennas = 1;
            if ~isfield(obj.ModulatorConfig, 'BandwidthTimeProduct')
                obj.ModulatorConfig.BandwidthTimeProduct = rand(1)*0.2+0.2;
                obj.ModulatorConfig.PulseLength = randi([4, 10], 1);
                obj.ModulatorConfig.SymbolPrehistory = randsample([-1, 1], 1);
                obj.ModulatorConfig.InitialPhaseOffset = rand(1)*2*pi;
            end

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
