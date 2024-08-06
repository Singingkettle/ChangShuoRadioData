classdef VSBAM < DSBSCAM
    
    properties (Access = private)
        hf
    end
    
    methods (Access = private)
        
        function y = basefiler(obj, x, bw)
            
            if x <- obj.ModulatorConfig.fa
                y = 0;
            elseif x > obj.ModulatorConfig.fa && x <= bw
                y = 1;
            elseif x > bw
                y = 0;
            else
                y = (x + obj.ModulatorConfig.fa) / (2 * obj.ModulatorConfig.fa);
            end
            
        end
        
    end
    
    methods (Access = protected)
        
        function [y, bw] = baseModulator(obj, x)

            SamplePerFrame = length(x);
            
            f = (-SamplePerFrame / 2:SamplePerFrame / 2 - 1) * (obj.SampleRate / SamplePerFrame);
            f = f';
            % tools = TCBUN.instance();
            obj.hf = arrayfun(@(x)obj.basefiler(x, 30e3/2), f);
            if strcmp(obj.ModulatorConfig.mode, 'upper')
                imagP = fftshift(fft(x)) .* (flipud(obj.hf) - obj.hf);
                bw = [-obj.ModulatorConfig.fa, obw(x, obj.SampleRate)];
            else
                imagP = fftshift(fft(x)) .* (obj.hf - flipud(obj.hf));
                bw = [-obw(x, obj.SampleRate), obj.ModulatorConfig.fa];
            end
            
            imagP = imag(ifft(ifftshift(imagP)));
            y = complex(x, imagP);

        end
        
    end
    
    methods
        
        function modulatorHandle = genModulatorHandle(obj)
            
            if ~isfield(obj.ModulatorConfig, 'mode')
                obj.ModulatorConfig.mode = randsample(["upper", "lower"], 1);
                % 15e3 is base on the Audio block's bandwidth (one side = two side /2)
                obj.ModulatorConfig.fa = (rand(1)*0.01+0.01)*15e3;
            end

            obj.IsDigital = false;
            % donot consider multi-tx in analog modulation
            obj.NumTransmitAntennas = 1;
            modulatorHandle = @(x)obj.baseModulator(x);
            
        end
        
    end
    
end
