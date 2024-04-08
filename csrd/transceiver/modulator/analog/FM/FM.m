classdef FM < BaseModulator

    methods

        function modulatorHandle = genModulatorHandle(obj)

            modulatorHandle = comm.FMModulator( ...
                SampleRate = obj.SampleRate, ...
                FrequencyDeviation = obj.ModulatorConfig.frequencyDeviation);
            obj.IsDigital = false;
            obj.NumTransmitAntennnas = 1; % donot consider multi-tx in analog modulation

        end

    end

end
