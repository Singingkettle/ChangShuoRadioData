classdef PAM < BaseModulator
    
    properties
        
        SamplePerSymbol (1, 1) {mustBePositive, mustBeReal} = 2
        
    end
    
    properties (Access = protected)
        
        filterCoeffs
        
    end
    
    methods (Access = protected)
        
        function [y, bw] = baseModulator(obj, x)
            
            amp = 1 / sqrt(mean(abs(pammod(0:obj.ModulatorOrder - 1, obj.ModulatorOrder)) .^ 2));
            % Modulate
            x = amp * pammod(x, obj.ModulatorOrder);
            
            % Pulse shape
            y = filter(obj.filterCoeffs, 1, upsample(x, obj.SamplePerSymbol));

            bw = obw(y, obj.SampleRate)*2;
            if obj.NumTransmitAntennas > 1
                bw = max(bw);
            end
            
        end
        
    end
    
    methods
        
        function filterCoeffs = genFilterCoeffs(obj)
            
            filterCoeffs = rcosdesign(obj.ModulatorConfig.beta, ...
                obj.ModulatorConfig.span, ...
                obj.SamplePerSymbol);
            
        end
        
        function modulator = genModulatorHandle(obj)
            
            obj.IsDigital = true;
            obj.NumTransmitAntennas = 1;
            if ~isfield(obj.ModulatorConfig, 'beta')
                obj.ModulatorConfig.beta = rand(1);
                obj.ModulatorConfig.span = randi([2, 8])*2;
            end
            obj.filterCoeffs = obj.genFilterCoeffs;
            modulator = @(x)obj.baseModulator(x);
            
        end
        
    end
    
end
