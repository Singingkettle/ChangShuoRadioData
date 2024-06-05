classdef VSBAM < DSBSCAM
    
    properties (Access = private)
        hf
    end
    
    methods (Access = private)
        
        function y = basefiler(obj, x)
            
            if x <- obj.ModulationConfig.fa
                y = 0;
            elseif x > obj.ModulationConfig.fa && x <= 30e3
                y = 1;
            elseif x > 30e3
                y = 0;
            else
                y = (x + obj.ModulationConfig.fa) / (2 * obj.ModulationConfig.fa);
            end
            
        end
        
    end
    
    methods (Access = protected)
        
        function [y, bw] = baseModulation(obj, x)
            SamplePerFrame = length(x);
            f = (-SamplePerFrame / 2:SamplePerFrame / 2 - 1) * (obj.SampleRate / SamplePerFrame);
            f = f';
            obj.hf = arrayfun(@(x)obj.basefiler(x), f);
            if strcmp(obj.ModulationConfig.mode, 'upper')
                imagP = fftshift(fft(x)) .* (flipud(obj.hf) - obj.hf);
            else
                imagP = fftshift(fft(x)) .* (obj.hf - flipud(obj.hf));
            end
            
            imagP = imag(ifft(ifftshift(imagP)));
            y = complex(x, imagP);
            
            bw = obw(x, obj.SampleRate)*2;
        end
        
    end
    
    methods
        
        function modulatorHandle = genModulationHandle(obj)
            
            obj.IsDigital = false;
            % donot consider multi-tx in analog modulation
            obj.NumTransmitAntennnas = 1;
            modulatorHandle = @(x)obj.baseModulation(x);
            
        end
        
    end
    
end
