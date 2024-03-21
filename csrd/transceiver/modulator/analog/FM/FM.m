classdef FM < BaseModulator

    methods

        function modulator = getModulator(obj)
            % modulator = comm.FMModulator( ...
            %     %AudioSampleRate = obj.sampleRate, ...
            %     SampleRate = obj.sampleRate, ...
            %     FrequencyDeviation = obj.modulatorConfig.frequencyDeviation);
            modulator = comm.FMModulator( ...
                SampleRate = obj.sampleRate, ...
                FrequencyDeviation = obj.modulatorConfig.frequencyDeviation);
        end

        function bw = bandWidth(obj, x)

            bw1 = obw(real(x), obj.sampleRate) * 2;
            bw2 = obw(imag(x), obj.sampleRate) * 2;
            bw = max([bw1, bw2]);

        end

        function y = passBand(obj, x)

            y = x .* obj.carrierWave + conj(x) .* conj(obj.carrierWave);

        end

    end

end
