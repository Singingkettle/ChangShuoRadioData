classdef VSBAM < DSBSCAM

    properties (Access = private)
        hf
    end

    methods (Access = private)

        function y = basefiler(obj, x)

            if x <- obj.ModulatorConfig.fa
                y = 0;
            elseif x > obj.ModulatorConfig.fa && x <= 30e3
                y = 1;
            elseif x > 30e3
                y = 0;
            else
                y = (x + obj.ModulatorConfig.fa) / (2 * obj.ModulatorConfig.fa);
            end

        end

    end

    methods (Access = protected)

        function y = baseModulator(obj, x)

            x = lowpass(x, 30e3, obj.SampleRate, ImpulseResponse = "fir", Steepness = 0.99);

            if strcmp(obj.ModulatorConfig.mode, 'upper')
                imagP = fftshift(fft(x)) .* (flipud(obj.hf) - obj.hf);
            else
                imagP = fftshift(fft(x)) .* (obj.hf - flipud(obj.hf));
            end

            imagP = imag(ifft(ifftshift(imagP)));
            y = complex(x, imagP);

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)

            f = (-obj.SamplePerFrame / 2:obj.SamplePerFrame / 2 - 1) * (obj.SampleRate / obj.SamplePerFrame);
            f = f';
            obj.hf = arrayfun(@(x)obj.basefiler(x), f);
            modulatorHandle = @(x)obj.baseModulator(x);
            obj.IsDigital = false;
            % donot consider multi-tx in analog modulation
            obj.NumTransmitAntennnas = 1;

        end

    end

end
