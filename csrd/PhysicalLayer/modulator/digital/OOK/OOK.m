classdef OOK < APSK
    
    methods (Access = protected)
        
        function [y, bw] = baseModulator(obj, x)
            
            % Pulse shape
            y = filter(obj.filterCoeffs, 1, upsample(x, obj.SamplePerSymbol));
            
            bw = obw(y, obj.SampleRate)*2;
            if obj.NumTransmitAntennas > 1
                bw = max(bw);
            end
            
        end
        
    end
    
    methods
        
        function modulatorHandle = genModulatorHandle(obj)
            
            obj.IsDigital = true;
            obj.NumTransmitAntennas = 1;
            if ~isfield(obj.ModulatorConfig, 'beta')
                obj.ModulatorConfig.beta = rand(1);
                obj.ModulatorConfig.span = randi([2, 8])*2;
            end
            obj.ModulatorOrder = 2;
            obj.filterCoeffs = obj.genFilterCoeffs;
            modulatorHandle = @(x)obj.baseModulator(x);
            
        end
        
    end
    
end
