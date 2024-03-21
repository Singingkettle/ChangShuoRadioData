classdef GMSK < BaseModulator

    methods

        function modulator = getModulator(obj)
            modulator = comm.GMSKModulator( ...
                BitInput = true, ...
                BandwidthTimeProduct = obj.modulatorConfig.bandwidthTimeProduct, ...
                PulseLength = obj.modulatorConfig.pulseLength, ...
                SymbolPrehistory = obj.modulatorConfig.symbolPrehistory, ...
                InitialPhaseOffset = obj.modulatorConfig.initialPhaseOffset, ...
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
