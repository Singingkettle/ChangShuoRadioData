classdef OQPSK < APSK
    
     properties

        pureModulator
        
     end
    
     methods (Access = protected)

        function [y, bw] = baseModulator(obj, x)
            y = obj.pureModulator(x);
            bw = obw(y, obj.SampleRate, [], 99.99999);
            if obj.NumTransmitAntennnas > 1
                bw = max(bw);
            end
        end

     end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            obj.IsDigital = true;
            obj.filterCoeffs = obj.genFilterCoeffs;
            obj.ostbc = obj.genOSTBC;
            obj.pureModulator = BaseOQPSK( ...
                PhaseOffset = obj.ModulatorConfig.PhaseOffset, ...
                SymbolMapping = obj.ModulatorConfig.SymbolMapping, ...
                PulseShape = 'Root raised cosine', ...
                RolloffFactor = obj.ModulatorConfig.beta, ...
                FilterSpanInSymbols = obj.ModulatorConfig.span, ...
                SamplesPerSymbol = obj.SamplePerSymbol, ...
                NumTransmitAntennas = obj.NumTransmitAntennas, ...
                ostbc = obj.ostbc);
            
            modulatorHandle = @(x)obj.baseModulator(x);
            
        end

    end

end
