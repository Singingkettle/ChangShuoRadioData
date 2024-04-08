classdef PM < BaseModulator

    methods (Access = private)

        function y = baseModulator(obj, x)

            y = complex(cos(obj.ModulatorConfig.phaseDev * x + ...
                obj.ModulatorConfig.initPhase), ...
                sin(obj.ModulatorConfig.phaseDev * x + ...
                obj.ModulatorConfig.initPhase)) / 2;

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)

            modulatorHandle = @(x)obj.baseModulator(x);
            obj.IsDigital = false;
            obj.NumTransmitAntennnas = 1; % donot consider multi-tx in analog modulation

        end

    end

end
