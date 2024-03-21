classdef FSK < BaseModulator
    
   
    methods

        function modulator = getModulator(obj)
            modulator = @(x)fskmod(x, ...
                obj.modulatorConfig.order, ...
                obj.sampleRate/obj.samplePerSymbol/2, ...
                obj.samplePerSymbol, ...
                obj.sampleRate, ...
                'discont', ...
                obj.modulatorConfig.symbolOrder);

            obj.isDigital = true;
        end

        
        function bw = bandWidth(obj, x)

            bw = (obj.modulatorConfig.order - 1) * obj.sampleRate/obj.samplePerSymbol/2;
            
        end

        function  y = passBand(obj, x)
            y = real(x .* obj.carrierWave);
        end
        
    end
    
end
