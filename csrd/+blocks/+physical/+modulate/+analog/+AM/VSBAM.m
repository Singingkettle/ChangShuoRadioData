classdef VSBAM < blocks.physical.modulate.analog.AM.DSBSCAM
    % VSBAM Vestigial Sideband Amplitude Modulation
    %   Implements VSB-AM modulation by filtering one sideband partially while
    %   maintaining the other sideband completely. Inherits from DSBSCAM.
    %
    % Properties:
    %   vf - Vestigial filter response array
    %
    % Methods:
    %   genModulatorHandle - Generates the modulator function handle
    %   baseModulator - Performs the core VSB-AM modulation
    %   vestigialFilter - Implements the vestigial filter response

    properties (Access = private)
        vf % Vestigial filter response array
    end

    methods (Access = private)

        function h = vestigialFilter(obj, f, bw)
            % Implements the vestigial filter response
            % Args:
            %   f: Frequency point to evaluate
            %   bw: Bandwidth parameter (typically half of desired bandwidth)
            % Returns:
            %   h: Filter response value (0 to 1)

            if f <- obj.ModulatorConfig.cutoff
                h = 0; % Complete attenuation below cutoff
            elseif f > obj.ModulatorConfig.cutoff && f <= bw
                h = 1; % Complete passthrough in passband
            elseif f > bw
                h = 0; % Complete attenuation above bandwidth
            else
                % Linear transition region
                h = (f + obj.ModulatorConfig.cutoff) / (2 * obj.ModulatorConfig.cutoff);
            end

        end

    end

    methods (Access = protected)

        function [y, bw] = baseModulator(obj, x)
            % Performs VSB-AM modulation on input signal
            % Args:
            %   x: Input signal in time domain
            % Returns:
            %   y: Complex modulated signal
            %   bw: Bandwidth limits of modulated signal [lower, upper]

            SamplePerFrame = length(x);

            % Generate frequency axis
            f = (-SamplePerFrame / 2:SamplePerFrame / 2 - 1)' * (obj.SampleRate / SamplePerFrame);

            % Generate vestigial filter response
            obj.vf = arrayfun(@(x)obj.vestigialFilter(x, 30e3/2), f);

            % Transform input to frequency domain
            X = fftshift(fft(x));

            % Apply appropriate sideband filtering based on mode
            if strcmp(obj.ModulatorConfig.mode, 'upper')
                % Keep upper sideband, partially filter lower
                imagP = X .* (flipud(obj.vf) - obj.vf);
                bw = [-obj.ModulatorConfig.cutoff, obw(x, obj.SampleRate)];
            else
                % Keep lower sideband, partially filter upper
                imagP = X .* (obj.vf - flipud(obj.vf));
                bw = [-obw(x, obj.SampleRate), obj.ModulatorConfig.cutoff];
            end

            % Convert back to time domain and create complex signal
            imagP = imag(ifft(ifftshift(imagP)));
            y = complex(x, imagP);
        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % Generates a function handle for the VSB-AM modulator
            % Returns:
            %   modulatorHandle: Function handle to perform modulation

            % Set default configuration if not specified
            if ~isfield(obj.ModulatorConfig, 'mode')
                % Randomly select upper or lower sideband mode
                obj.ModulatorConfig.mode = randsample(["upper", "lower"], 1);
                % Set cutoff frequency (1-2% of 15kHz audio bandwidth)
                obj.ModulatorConfig.cutoff = (rand(1) * 0.01 + 0.01) * 15e3;
            end

            % Configure as analog modulation with single antenna
            obj.IsDigital = false;
            obj.NumTransmitAntennas = 1;

            % Return modulator function handle
            modulatorHandle = @(x)obj.baseModulator(x);
        end

    end

end
