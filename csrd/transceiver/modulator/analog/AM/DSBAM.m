classdef DSBAM < BaseModulator
    
    methods

        function modulator = getModulator(obj)
            modulator = @(x)baseAMModulator(x);
            obj.isDigital = false;
        end

        
        function bw = bandWidth(obj, x)
            bw = obw(x - min(abs(x)), obj.sampleRate) * 2;
        end

        function  y = passBand(obj, x)
            t = (0:1/obj.sampleRate:((size(x,1)-1)/obj.sampleRate))';
            t = t(:, ones(1, size(x, 2)));
            y = x .* cos(2 * pi * obj.carrierFrequency * t + obj.modulatorConfig.initPhase);
        end
        
    end
    
end


function y = baseAMModulator(x)

y = x + min(abs(x));

end