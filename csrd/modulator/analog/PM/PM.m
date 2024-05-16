classdef PM < BaseModulator

    methods (Access = private)

        function [y, bw] = baseModulator(obj, x)

            y = complex(cos(obj.ModulatorConfig.phaseDev * x + ...
                obj.ModulatorConfig.initPhase), ...
                sin(obj.ModulatorConfig.phaseDev * x + ...
                obj.ModulatorConfig.initPhase)) / 2;
            bw = obw(y, obj.SampleRate, [], 99.99999);
            
        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            
            obj.IsDigital = false;
            % donot consider multi-tx in analog modulation
            obj.NumTransmitAntennnas = 1; 
            modulatorHandle = @(x)obj.baseModulator(x);
            
        end

    end

end
