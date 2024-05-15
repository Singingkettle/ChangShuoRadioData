classdef FSK < BaseModulator

    properties

        SamplePerSymbol (1, 1) {mustBePositive, mustBeReal} = 2

    end
    
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
            obj.NumTransmitAntennnas = 1;
            modulatorHandle = @(x)fskmod(x, ...
                obj.ModulationOrder, ...
                obj.SampleRate / obj.SamplePerSymbol / 2, ...
                obj.SamplePerSymbol, ...
                obj.SampleRate, ...
                'discont', ...
                obj.ModulatorConfig.SymbolOrder);
            
        end

    end

end
