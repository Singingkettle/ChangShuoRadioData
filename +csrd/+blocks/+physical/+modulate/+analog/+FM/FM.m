classdef FM < csrd.blocks.physical.modulate.BaseModulator
    % FM - Frequency Modulation Modulator
    %
    % This class implements Frequency Modulation (FM) as a subclass of the BaseModulator.
    % FM is an analog modulation technique where the instantaneous frequency of the
    % carrier signal is varied in proportion to the amplitude of the modulating
    % signal. FM provides excellent noise immunity and is widely used in broadcasting,
    % mobile communications, and high-fidelity audio transmission.
    %
    % Frequency modulation achieves superior noise performance compared to amplitude
    % modulation because information is encoded in frequency variations rather than
    % amplitude changes. This makes FM particularly suitable for applications requiring
    % high signal quality in noisy environments.
    %
    % Key Features:
    %   - Excellent noise immunity and signal quality
    %   - Constant envelope modulation for efficient amplification
    %   - Configurable frequency deviation for bandwidth control
    %   - Wide dynamic range and low distortion
    %   - Single antenna transmission (inherently analog)
    %
    % Syntax:
    %   fmModulator = FM()
    %   fmModulator = FM('PropertyName', PropertyValue, ...)
    %   modulatedSignal = fmModulator.step(inputData)
    %
    % Properties:
    %   ModulatorConfig - Configuration structure for FM parameters
    %     .FrequencyDeviation - Maximum frequency deviation in Hz
    %
    % Methods:
    %   baseModulator - Core FM modulation implementation
    %   genModulatorHandle - Generate configured modulator function handle
    %
    % Example:
    %   % Create FM modulator for high-fidelity audio broadcasting
    %   fmMod = csrd.blocks.physical.modulate.analog.FM.FM();
    %   fmMod.SampleRate = 192000; % High-quality audio sampling rate
    %
    %   % Configure for wideband FM (broadcast quality)
    %   fmMod.ModulatorConfig.FrequencyDeviation = 75000; % 75 kHz deviation
    %
    %   % Create input audio signal
    %   t = (0:999)' / fmMod.SampleRate;
    %   audioSignal = sin(2*pi*15000*t); % 15 kHz audio tone
    %
    %   % Modulate the signal
    %   modulatedSignal = fmMod.step(audioSignal);
    %
    % See also: csrd.blocks.physical.modulate.analog.PM.PM,
    %           csrd.blocks.physical.modulate.BaseModulator

    methods (Access = protected)

        function [modulatedSignal, bandWidth] = baseModulator(obj, messageSignal)
            % baseModulator - Core FM modulation implementation
            %
            % This method performs frequency modulation by integrating the message
            % signal and using it to modulate the instantaneous frequency of a
            % complex carrier signal. The integration is essential to convert
            % amplitude variations into frequency variations.
            %
            % Syntax:
            %   [modulatedSignal, bandWidth] = baseModulator(obj, messageSignal)
            %
            % Input Arguments:
            %   messageSignal - Input message signal to be modulated
            %                   Type: real-valued numeric array
            %
            % Output Arguments:
            %   modulatedSignal - FM modulated complex signal
            %                     Type: complex array
            %   bandWidth - Occupied bandwidth of the modulated signal in Hz
            %               Type: positive scalar
            %
            % Processing Steps:
            %   1. Integrate message signal with respect to time
            %   2. Scale integrated signal by frequency deviation
            %   3. Generate complex exponential for frequency modulation
            %   4. Calculate occupied bandwidth of the modulated signal
            %
            % FM Signal Equation:
            %   s(t) = exp(j * 2π * k_f * ∫m(τ)dτ)
            %   where k_f is frequency deviation and m(t) is message signal
            %
            % Bandwidth Estimation:
            %   FM bandwidth follows Carson's rule: BW ≈ 2(Δf + f_m)
            %   where Δf is frequency deviation and f_m is message bandwidth
            %
            % Example:
            %   messageSignal = sin(2*pi*1000*(0:999)'/48000); % 1 kHz tone
            %   [signal, bw] = obj.baseModulator(messageSignal);

            % Integrate message signal with respect to time (numerical integration)
            % Use cumulative sum divided by sample rate for discrete-time integration
            integratedSignal = cast(0, class(messageSignal)) + cumsum(messageSignal) / obj.SampleRate;

            % Apply frequency modulation using the integrated signal
            instantaneousPhase = 2 * pi * obj.ModulatorConfig.FrequencyDeviation * integratedSignal;

            % Generate complex FM signal using Euler's formula
            modulatedSignal = exp(1j * instantaneousPhase);

            % Calculate occupied bandwidth of the modulated signal
            bandWidth = obw(modulatedSignal, obj.SampleRate);

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % genModulatorHandle - Generate configured FM modulator function handle
            %
            % This method configures the FM modulator with default parameters if not
            % specified and returns a function handle for the complete modulation
            % process. FM modulation is inherently analog and single-antenna.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            %   modulatorHandle - Function handle for FM modulation
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(message)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - FrequencyDeviation: Maximum frequency deviation in Hz
            %
            % Default Configuration:
            %   - FrequencyDeviation: Random value between 5 kHz and 75 kHz
            %   - IsDigital: false (analog modulation)
            %   - NumTransmitAntennas: 1 (single antenna)
            %
            % Frequency Deviation Standards:
            %   - Narrowband FM: 5-25 kHz (mobile communications)
            %   - Wideband FM: 75 kHz (audio broadcasting standards)
            %   - Data applications: 1-100 kHz depending on requirements
            %
            % Bandwidth Considerations:
            %   Higher frequency deviation provides better noise immunity but
            %   requires wider bandwidth. Selection depends on available spectrum
            %   and noise performance requirements.
            %
            % Example:
            %   fmMod = csrd.blocks.physical.modulate.analog.FM.FM();
            %   modHandle = fmMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle(audioData);

            % Set modulation type flags
            obj.IsDigital = false; % FM is analog modulation
            obj.NumTransmitAntennas = 1; % Single antenna transmission (analog modulation constraint)

            % Configure FM parameters if not provided
            if ~isfield(obj.ModulatorConfig, 'FrequencyDeviation')
                % For FM modulation, frequency deviation typically ranges:
                % - Narrowband FM: 5 kHz (mobile communications)
                % - Wideband FM: 75 kHz (audio broadcasting standards)
                % - Data applications: 1-100 kHz depending on requirements
                % Using a range of 5-75 kHz to cover most practical applications
                obj.ModulatorConfig.FrequencyDeviation = randi([5000, 75000]);
            end

            % Create function handle for modulation
            modulatorHandle = @(messageSignal)obj.baseModulator(messageSignal);

        end

    end

end
