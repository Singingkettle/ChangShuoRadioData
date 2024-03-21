classdef VSBAM < DSBSCAM
    
    
    properties (Dependent=false)
        hf
    end

    methods
        
        function hf = get.hf(obj)
            f = (-obj.samplePerFrame/2:obj.samplePerFrame/2-1)*(obj.sampleRate/obj.samplePerFrame);
            f = f';
            hf = arrayfun(@(x)vsb_filer(x, obj.carrierFrequency, obj.modulatorConfig.fa, obj.modulatorConfig.mode), f);
            
        end 

        function bw = bandWidth(obj, x)
            bw = obw(x, obj.sampleRate) + obj.modulatorConfig.fa;
        end
        
        function  y = passBand(obj, x)
            yf = obj.hf .* fftshift(fft(x));
            y = ifft(ifftshift(yf));
        end
    end
    
end


function y = vsb_filer(x, fc, fa, mode)

x  = abs(x);

if strcmp(mode, 'upper')
    if x < fc - fa
        y = 0;
    elseif x > fc + fa
        y = 1;
    else
        y = (x - fc + fa) /(2 * fa);
    end
else
     if x < fc - fa
        y = 1;
    elseif x > fc + fa
        y = 0;
    else
        y = (fc - fa - x) /(2 * fa) +  1;
     end

end

end
