classdef VSBAM < csrd.blocks.physical.modulate.analog.AM.DSBSCAM
    % VSBAM - Vestigial Sideband Amplitude Modulation Modulator
    %
    % This class implements Vestigial Sideband Amplitude Modulation (VSB-AM) as a
    % subclass of DSBSCAM. VSB-AM is a bandwidth-efficient form of amplitude modulation
    % that transmits one complete sideband and a portion (vestige) of the other
    % sideband. This approach provides a good compromise between bandwidth efficiency
    % and implementation complexity.
    %
    % VSB-AM is widely used in television broadcasting (analog TV) and high-speed
    % data transmission systems where bandwidth efficiency is crucial. The vestigial
    % portion of the partially transmitted sideband helps maintain carrier recovery
    % and reduces the complexity of the receiver compared to pure SSB systems.
    %
    % Key Features:
    %   - Bandwidth efficiency better than DSB-AM but not as efficient as SSB-AM
    %   - Easier demodulation compared to SSB-AM
    %   - Configurable sideband selection (upper or lower)
    %   - Adjustable vestigial filter characteristics
    %   - Suitable for television and high-speed data applications
    %
    % Syntax:
    %   vsbModulator = VSBAM()
    %   vsbModulator = VSBAM('PropertyName', PropertyValue, ...)
    %   modulatedSignal = vsbModulator.step(inputData)
    %
    % Properties (Inherited from DSBSCAM):
    %   ModulatorConfig - Configuration structure for VSB-AM parameters
    %     .mode - Sideband mode ('upper' or 'lower')
    %     .cutoff - Cutoff frequency for vestigial filtering (Hz)
    %
    % Properties (Access = private):
    %   vestigialFilterResponse - Vestigial filter frequency response array
    %
    % Methods:
    %   baseModulator - Core VSB-AM modulation implementation
    %   vestigialFilter - Generate vestigial filter frequency response
    %   genModulatorHandle - Generate configured modulator function handle
    %
    % Example:
    %   % Create VSB-AM modulator for television-like transmission
    %   vsbMod = csrd.blocks.physical.modulate.analog.AM.VSBAM();
    %   vsbMod.SampleRate = 48000; % Audio sampling rate
    %
    %   % Configure for upper sideband with specific cutoff
    %   vsbMod.ModulatorConfig.mode = 'upper';
    %   vsbMod.ModulatorConfig.cutoff = 150; % 150 Hz vestigial cutoff
    %
    %   % Create input audio signal
    %   t = (0:999)' / vsbMod.SampleRate;
    %   audioSignal = sin(2*pi*5000*t); % 5 kHz audio tone
    %
    %   % Modulate the signal
    %   modulatedSignal = vsbMod.step(audioSignal);
    %
    % See also: csrd.blocks.physical.modulate.analog.AM.DSBSCAM,
    %           csrd.blocks.physical.modulate.analog.AM.SSBAM,
    %           csrd.blocks.physical.modulate.BaseModulator

    properties (Access = private)
        % vestigialFilterResponse - Vestigial filter frequency response array
        % Type: numeric array
        % This array contains the frequency response of the vestigial filter
        % used to shape the transmitted spectrum for VSB-AM modulation
        vestigialFilterResponse
    end

    methods (Access = private)

        function filterResponse = vestigialFilter(obj, frequency, bandwidthParameter)
            % vestigialFilter - Generate vestigial filter frequency response
            %
            % This method implements the characteristic vestigial filter response
            % that defines VSB-AM modulation. The filter completely attenuates
            % frequencies below the cutoff, provides full transmission in the
            % passband, and creates a linear transition region.
            %
            % Syntax:
            %   filterResponse = vestigialFilter(obj, frequency, bandwidthParameter)
            %
            % Input Arguments:
            %   frequency - Frequency point to evaluate (Hz)
            %   bandwidthParameter - Bandwidth parameter (typically half of desired BW)
            %
            % Output Arguments:
            %   filterResponse - Filter response value (0 to 1)
            %                    Type: scalar in range [0, 1]
            %
            % Filter Characteristics:
            %   - Complete attenuation below cutoff frequency
            %   - Linear transition through vestigial region
            %   - Full transmission in main passband
            %   - Complete attenuation above bandwidth limit

            if frequency < -obj.ModulatorConfig.cutoff
                % Complete attenuation below negative cutoff
                filterResponse = 0;
            elseif frequency > -obj.ModulatorConfig.cutoff && frequency <= bandwidthParameter
                % Complete passthrough in main passband
                filterResponse = 1;
            elseif frequency > bandwidthParameter
                % Complete attenuation above bandwidth limit
                filterResponse = 0;
            else
                % Linear transition region (vestigial portion)
                filterResponse = (frequency + obj.ModulatorConfig.cutoff) / (2 * obj.ModulatorConfig.cutoff);
            end

        end

    end

    methods (Access = protected)

        function [modulatedSignal, bandWidth] = baseModulator(obj, messageSignal)
            % baseModulator - Core VSB-AM modulation implementation
            %
            % This method performs VSB-AM modulation by applying vestigial filtering
            % in the frequency domain to create the characteristic VSB spectrum with
            % one complete sideband and a partial vestigial sideband.
            %
            % Syntax:
            %   [modulatedSignal, bandWidth] = baseModulator(obj, messageSignal)
            %
            % Input Arguments:
            %   messageSignal - Input message signal to be modulated
            %                   Type: real-valued numeric array
            %
            % Output Arguments:
            %   modulatedSignal - VSB-AM modulated complex signal
            %                     Type: complex array
            %   bandWidth - Occupied bandwidth as [lower, upper] bounds in Hz
            %               Type: 1x2 numeric array
            %
            % Processing Steps:
            %   1. Transform input signal to frequency domain using FFT
            %   2. Generate vestigial filter response across frequency axis
            %   3. Apply asymmetric filtering based on sideband mode
            %   4. Convert filtered spectrum back to time domain
            %   5. Create complex signal with real and imaginary components
            %   6. Calculate bandwidth bounds based on filter characteristics
            %
            % VSB Spectrum Characteristics:
            %   - One complete sideband for full information recovery
            %   - Vestigial portion prevents spectral overlap
            %   - Asymmetric spectrum around carrier frequency

            samplesPerFrame = length(messageSignal);

            % Generate frequency axis for FFT analysis
            frequencyAxis = (-samplesPerFrame / 2:samplesPerFrame / 2 - 1)' * ...
                (obj.SampleRate / samplesPerFrame);

            % Generate vestigial filter response across frequency axis
            obj.vestigialFilterResponse = arrayfun(@(freq)obj.vestigialFilter(freq, 30e3/2), frequencyAxis);

            % Transform input signal to frequency domain
            messageSpectrum = fftshift(fft(messageSignal));

            % Apply vestigial filtering based on sideband mode configuration
            if strcmp(obj.ModulatorConfig.mode, 'upper')
                % Upper sideband mode: keep upper sideband, partially filter lower
                imaginaryComponent = messageSpectrum .* (flipud(obj.vestigialFilterResponse) - obj.vestigialFilterResponse);
                bandWidth = [-obj.ModulatorConfig.cutoff, obw(messageSignal, obj.SampleRate)];
            else
                % Lower sideband mode: keep lower sideband, partially filter upper
                imaginaryComponent = messageSpectrum .* (obj.vestigialFilterResponse - flipud(obj.vestigialFilterResponse));
                bandWidth = [-obw(messageSignal, obj.SampleRate), obj.ModulatorConfig.cutoff];
            end

            % Convert filtered spectrum back to time domain
            imaginaryTimeDomain = imag(ifft(ifftshift(imaginaryComponent)));

            % Create complex VSB-AM signal with real message and filtered imaginary part
            modulatedSignal = complex(messageSignal, imaginaryTimeDomain);

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % genModulatorHandle - Generate configured VSB-AM modulator function handle
            %
            % This method configures the VSB-AM modulator with default parameters if not
            % specified and returns a function handle for the complete modulation process.
            % VSB-AM modulation is inherently analog and single-antenna.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            %   modulatorHandle - Function handle for VSB-AM modulation
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(message)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - mode: Sideband selection ('upper' or 'lower')
            %   - cutoff: Vestigial filter cutoff frequency (Hz)
            %
            % Default Configuration:
            %   - mode: Random selection between 'upper' and 'lower'
            %   - cutoff: Random value (1-2% of 15 kHz audio bandwidth)
            %   - IsDigital: false (analog modulation)
            %   - NumTransmitAntennas: 1 (single antenna)
            %
            % Vestigial Filter Design:
            %   The cutoff frequency determines the width of the vestigial portion.
            %   Typical values are 1-2% of the message bandwidth for television
            %   applications, providing adequate carrier recovery information.
            %
            % Example:
            %   vsbMod = csrd.blocks.physical.modulate.analog.AM.VSBAM();
            %   modHandle = vsbMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle(audioData);

            % Configure VSB-AM parameters if not provided
            if ~isfield(obj.ModulatorConfig, 'mode')
                % Randomly select upper or lower sideband mode
                obj.ModulatorConfig.mode = randsample(["upper", "lower"], 1);

                % Set vestigial cutoff frequency (1-2% of 15 kHz audio bandwidth)
                % This provides adequate vestigial information for carrier recovery
                obj.ModulatorConfig.cutoff = (rand(1) * 0.01 + 0.01) * 15e3;
            end

            % Set modulation type flags
            obj.IsDigital = false; % VSB-AM is analog modulation
            obj.NumTransmitAntennas = 1; % Single antenna transmission

            % Create function handle for modulation
            modulatorHandle = @(messageSignal)obj.baseModulator(messageSignal);

        end

    end

end
