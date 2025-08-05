classdef PM < csrd.blocks.physical.modulate.BaseModulator
    % PM - Phase Modulation Modulator
    %
    % This class implements Phase Modulation (PM) as a subclass of the BaseModulator.
    % PM is an analog modulation technique where the instantaneous phase of the
    % carrier signal is varied in proportion to the amplitude of the modulating
    % signal. PM is closely related to frequency modulation (FM) but directly
    % modulates the phase rather than the frequency.
    %
    % Phase modulation provides constant amplitude transmission with information
    % encoded in the phase variations. Unlike FM, PM does not require integration
    % of the message signal, making it simpler to implement in some applications.
    % PM is commonly used in digital communication systems and phase-locked loop
    % applications.
    %
    % Key Features:
    %   - Constant envelope modulation for power-efficient amplification
    %   - Direct phase modulation without frequency integration
    %   - Configurable phase deviation for sensitivity control
    %   - Bandwidth depends on phase deviation and message signal characteristics
    %   - Single antenna transmission (inherently analog)
    %
    % Syntax:
    %   pmModulator = PM()
    %   pmModulator = PM('PropertyName', PropertyValue, ...)
    %   modulatedSignal = pmModulator.step(inputData)
    %
    % Properties:
    %   ModulatorConfig - Configuration structure for PM parameters
    %     .PhaseDeviation - Maximum phase deviation in radians
    %     .InitPhase - Initial carrier phase in radians
    %
    % Methods:
    %   baseModulator - Core PM modulation implementation
    %   genModulatorHandle - Generate configured modulator function handle
    %
    % Example:
    %   % Create PM modulator for voice transmission
    %   pmMod = csrd.blocks.physical.modulate.analog.PM.PM();
    %   pmMod.SampleRate = 48000; % 48 kHz sampling rate
    %
    %   % Configure phase deviation and initial phase
    %   pmMod.ModulatorConfig.PhaseDeviation = pi/2; % 90-degree max deviation
    %   pmMod.ModulatorConfig.InitPhase = 0;         % Zero initial phase
    %
    %   % Create input audio signal
    %   t = (0:999)' / pmMod.SampleRate;
    %   audioSignal = sin(2*pi*1000*t); % 1 kHz tone
    %
    %   % Modulate the signal
    %   modulatedSignal = pmMod.step(audioSignal);
    %
    % See also: csrd.blocks.physical.modulate.analog.FM.FM,
    %           csrd.blocks.physical.modulate.BaseModulator

    methods (Access = protected)

        function [modulatedSignal, bandWidth] = baseModulator(obj, messageSignal)
            % baseModulator - Core PM modulation implementation
            %
            % This method performs phase modulation by directly varying the
            % instantaneous phase of a complex carrier signal in proportion
            % to the amplitude of the input message signal.
            %
            % Syntax:
            %   [modulatedSignal, bandWidth] = baseModulator(obj, messageSignal)
            %
            % Input Arguments:
            %   messageSignal - Input message signal to be modulated
            %                   Type: real-valued numeric array
            %
            % Output Arguments:
            %   modulatedSignal - PM modulated complex signal
            %                     Type: complex array
            %   bandWidth - Occupied bandwidth of the modulated signal in Hz
            %               Type: positive scalar
            %
            % Processing Steps:
            %   1. Scale message signal by phase deviation factor
            %   2. Add initial carrier phase offset
            %   3. Generate complex exponential for phase modulation
            %   4. Calculate occupied bandwidth of the modulated signal
            %
            % PM Signal Equation:
            %   s(t) = exp(j * (k_p * m(t) + phi_0))
            %   where k_p is phase deviation, m(t) is message signal,
            %   and phi_0 is initial phase
            %
            % Bandwidth Characteristics:
            %   PM bandwidth depends on both the phase deviation and the
            %   spectral characteristics of the message signal. Higher
            %   phase deviation results in wider bandwidth.
            %
            % Example:
            %   messageSignal = sin(2*pi*1000*(0:999)'/48000); % 1 kHz tone
            %   [signal, bw] = obj.baseModulator(messageSignal);

            % Apply phase modulation with configured deviation and initial phase
            instantaneousPhase = obj.ModulatorConfig.PhaseDeviation * messageSignal + ...
                obj.ModulatorConfig.InitPhase;

            % Generate complex PM signal using Euler's formula
            modulatedSignal = exp(1j * instantaneousPhase);

            % Calculate occupied bandwidth of the modulated signal
            bandWidth = obw(modulatedSignal, obj.SampleRate);

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % genModulatorHandle - Generate configured PM modulator function handle
            %
            % This method configures the PM modulator with default parameters if not
            % specified and returns a function handle for the complete modulation
            % process. PM modulation is inherently analog and single-antenna.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            %   modulatorHandle - Function handle for PM modulation
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(message)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - PhaseDeviation: Maximum phase deviation in radians
            %   - InitPhase: Initial carrier phase (typically 0)
            %
            % Default Configuration:
            %   - PhaseDeviation: Random value between π/4 and π/2 radians
            %   - InitPhase: 0 radians (no initial phase offset)
            %   - IsDigital: false (analog modulation)
            %   - NumTransmitAntennas: 1 (single antenna)
            %
            % Phase Deviation Guidelines:
            %   - Small values (π/8 to π/4): Narrow bandwidth, lower distortion
            %   - Medium values (π/4 to π/2): Balanced bandwidth and sensitivity
            %   - Large values (>π/2): Wide bandwidth, high sensitivity
            %
            % Example:
            %   pmMod = csrd.blocks.physical.modulate.analog.PM.PM();
            %   modHandle = pmMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle(audioData);

            % Set modulation type flags
            obj.IsDigital = false; % PM is analog modulation
            obj.NumTransmitAntennas = 1; % Single antenna transmission

            % Configure PM parameters if not provided
            if ~isfield(obj.ModulatorConfig, 'PhaseDeviation')
                % Random phase deviation between π/4 and π/2 radians (45-90 degrees)
                obj.ModulatorConfig.PhaseDeviation = (pi / 4) + rand(1) * (pi / 4);

                % Set initial phase to zero (no phase offset)
                obj.ModulatorConfig.InitPhase = 0;
            end

            % Create function handle for modulation
            modulatorHandle = @(messageSignal)obj.baseModulator(messageSignal);

        end

    end

end
