classdef OQPSK < BaseModulator

    methods

        function modulator = getModulator(obj)

            modulator = comm.OQPSKModulator( ...
                PhaseOffset = obj.modulatorConfig.phaseOffset, ...
                SymbolMapping = obj.modulatorConfig.symbolMapping, ...
                PulseShape = 'Root raised cosine', ...
                RolloffFactor = obj.modulatorConfig.beta, ...
                FilterSpanInSymbols = obj.modulatorConfig.span, ...
                SamplesPerSymbol = obj.samplePerSymbol);

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
