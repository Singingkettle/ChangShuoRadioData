classdef PM < BaseModulator
    
    methods (Access = private)
        
        function [y, bw] = baseModulator(obj, x)
            
            y = complex(cos(obj.ModulatorConfig.PhaseDeviation * x + ...
                obj.ModulatorConfig.InitPhase), ...
                sin(obj.ModulatorConfig.PhaseDeviation * x + ...
                obj.ModulatorConfig.InitPhase));
            bw = obw(y, obj.SampleRate);
            
        end
        
    end
    
    methods
        
        function modulatorHandle = genModulatorHandle(obj)
            
            if ~isfield(obj.ModulatorConfig, 'FrequencyDeviation')
                obj.ModulatorConfig.PhaseDeviation = rand(1)*pi;
                obj.ModulatorConfig.InitPhase = 0;
            end
            obj.IsDigital = false;
            % donot consider multi-tx in analog modulation
            obj.NumTransmitAntennas = 1;
            modulatorHandle = @(x)obj.baseModulator(x);
            
        end
        
    end
    
end
