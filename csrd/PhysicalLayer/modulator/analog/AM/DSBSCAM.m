classdef DSBSCAM < BaseModulator
    
    methods (Access = protected)
        
        function [y, bw] = baseModulator(obj, x)

            y = x;
            bw = obw(y, obj.SampleRate)*2;
            
        end
        
    end
    
    methods
        
        function modulatorHandle = genModulatorHandle(obj)
            
            if ~isfield(obj.ModulatorConfig, 'initPhase')
                obj.ModulatorConfig.initPhase = 0;
            end
            obj.IsDigital = false;
            % donot consider multi-tx in analog modulation
            obj.NumTransmitAntennas = 1;
            modulatorHandle = @(x)obj.baseModulator(x);
            
        end
        
    end
    
end
