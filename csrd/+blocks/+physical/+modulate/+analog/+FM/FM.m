classdef FM < blocks.physical.modulate.BaseModulator

    methods (Access = private)

        function [y, bw] = baseModulator(obj, x)
            intY = cast(0, class(x)) + cumsum(x) / obj.SampleRate;
            y = exp(1i * 2 * pi * obj.ModulatorConfig.FrequencyDeviation * intY);
            bw = obw(y, obj.SampleRate);
        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)

            obj.IsDigital = false;

            if ~isfield(obj.ModulatorConfig, 'FrequencyDeviation')
                % For FM modulation, frequency deviation typically ranges from 5 kHz (narrowband)
                % to 75 kHz (wideband) for audio broadcasting standards.
                % For data applications, it can range from 1-100 kHz depending on the application.
                % Using a moderate range of 5-75 kHz as default
                obj.ModulatorConfig.FrequencyDeviation = randi([5000, 75000]);
            end

            % donot consider multi-tx in analog modulation
            obj.NumTransmitAntennas = 1;
            modulatorHandle = @(x)obj.baseModulator(x);

        end

    end

end
