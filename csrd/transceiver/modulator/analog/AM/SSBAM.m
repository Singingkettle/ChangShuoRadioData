classdef SSBAM < BaseModulator
    

    methods

        function modulator = getModulator(obj)
            if strcmp(obj.modulatorConfig.mode, 'upper')
                modulator = @(x)ssbmod(x, obj.carrierFrequency, ...
                    obj.sampleRate, obj.modulatorConfig.initPhase, 'upper');
            else
                modulator = @(x)ssbmod(x, obj.carrierFrequency, ...
                    obj.sampleRate, obj.modulatorConfig.initPhase);
            end
            obj.isDigital = false;
            
        end
        
        function bw = bandWidth(obj, x)
            if strcmp(obj.modulatorConfig.mode, 'upper')
                bw = obw(x, obj.sampleRate, [obj.carrierFrequency, obj.sampleRate/2]);
            else
                bw = obw(x, obj.sampleRate, [0, obj.carrierFrequency]);
            end
            
        end

        function  y = passBand(obj, x)
            y = x;
        end

    end
    
end