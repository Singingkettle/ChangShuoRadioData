classdef PAM < BaseModulation
    
    properties
        
        SamplePerSymbol (1, 1) {mustBePositive, mustBeReal} = 2
        
    end
    
    properties (Access = protected)
        
        filterCoeffs
        
    end
    
    methods (Access = protected)
        
        function [y, bw] = baseModulation(obj, x)
            
            amp = 1 / sqrt(mean(abs(pammod(0:obj.ModulationOrder - 1, obj.ModulationOrder)) .^ 2));
            % Modulate
            x = amp * pammod(x, obj.ModulationOrder);
            
            % Pulse shape
            y = filter(obj.filterCoeffs, 1, upsample(x, obj.SamplePerSymbol));

            bw = obw(y, obj.SampleRate)*2;
            if obj.NumTransmitAntennnas > 1
                bw = max(bw);
            end
            
        end
        
    end
    
    methods
        
        function filterCoeffs = genFilterCoeffs(obj)
            
            filterCoeffs = rcosdesign(obj.ModulationConfig.beta, ...
                obj.ModulationConfig.span, ...
                obj.SamplePerSymbol);
            
        end
        
        function modulator = genModulationHandle(obj)
            
            obj.IsDigital = true;
            obj.NumTransmitAntennnas = 1;
            obj.filterCoeffs = obj.genFilterCoeffs;
            modulator = @(x)obj.baseModulation(x);
            
        end
        
    end
    
end
