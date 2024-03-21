classdef MSK < BaseModulator

    methods

        function modulator = getModulator(obj)
            modulator = @(x)mskmod(x, ...
                obj.samplePerSymbol, ...
                obj.modulatorConfig.dataEncode, ...
                obj.modulatorConfig.initPhase);

            obj.isDigital = true;
        end

        function bw = bandWidth(obj, x)

            bw = obw(x, obj.sampleRate);

        end

        function y = passBand(obj, x)
            y = real(x .* obj.carrierWave);
        end

    end

end
