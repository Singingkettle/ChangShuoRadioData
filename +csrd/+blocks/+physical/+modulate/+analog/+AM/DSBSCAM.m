classdef DSBSCAM < csrd.blocks.physical.modulate.BaseModulator
    % DSBSCAM - Double Sideband Suppressed Carrier Amplitude Modulator
    %
    % This class implements Double Sideband Suppressed Carrier Amplitude Modulation
    % (DSB-SC AM) as a subclass of the BaseModulator. DSB-SC AM is a bandwidth-efficient
    % form of amplitude modulation where the carrier signal is completely suppressed,
    % transmitting only the two sidebands containing the information signal.
    %
    % DSB-SC AM provides better power efficiency compared to conventional AM since
    % no power is wasted on the carrier component. However, it requires more complex
    % coherent detection at the receiver since the carrier must be regenerated for
    % proper demodulation. This modulation is commonly used in stereo FM broadcasting
    % and professional audio applications where power efficiency is important.
    %
    % Key Features:
    %   - Complete carrier suppression for power efficiency
    %   - Bandwidth = 2 × message signal bandwidth
    %   - Superior power efficiency compared to conventional AM
    %   - Requires coherent detection for demodulation
    %   - Maintains both sidebands for full information recovery
    %   - Single antenna transmission (analog modulation)
    %
    % Technical Specifications:
    %   - Modulation Equation: s(t) = m(t) × cos(2πfct + φ)
    %   - Carrier Suppression: Complete (infinite dB suppression)
    %   - Bandwidth: 2 × B_m (where B_m is message bandwidth)
    %   - Power Efficiency: 100% of power in information sidebands
    %   - Phase Continuity: Maintained through configuration
    %
    % Syntax:
    %   dsbscModulator = DSBSCAM()
    %   dsbscModulator = DSBSCAM('PropertyName', PropertyValue, ...)
    %   modulatedSignal = dsbscModulator.step(inputData)
    %
    % Properties (Inherited from BaseModulator):
    %   SampleRate - Sampling rate of the modulated signal in Hz
    %   ModulatorConfig - Configuration structure for DSB-SC AM parameters
    %     .initPhase - Initial carrier phase in radians (default: 0)
    %     .carrierPhase - Additional carrier phase offset (optional)
    %
    % Methods:
    %   baseModulator - Core DSB-SC AM modulation implementation
    %   genModulatorHandle - Generate configured modulator function handle
    %
    % Example:
    %   % Create DSB-SC AM modulator for stereo audio transmission
    %   dsbscMod = csrd.blocks.physical.modulate.analog.AM.DSBSCAM();
    %   dsbscMod.SampleRate = 48000; % 48 kHz audio sampling rate
    %
    %   % Configure phase parameters
    %   dsbscMod.ModulatorConfig.initPhase = 0; % Zero initial phase
    %
    %   % Create input audio signal (L-R stereo difference signal)
    %   t = (0:4799)' / dsbscMod.SampleRate; % 100 ms audio segment
    %   audioSignal = sin(2*pi*1000*t) + 0.5*sin(2*pi*3000*t); % Mixed audio content
    %
    %   % Modulate the signal
    %   modulatedSignal = dsbscMod.step(audioSignal);
    %
    % Applications:
    %   - Stereo FM broadcasting (L-R channel transmission)
    %   - Professional audio systems requiring power efficiency
    %   - Communication systems with coherent detection capability
    %   - Laboratory and educational demonstrations of AM techniques
    %   - Point-to-point communication links with known carrier frequency
    %
    % Power Efficiency Comparison:
    %   - Conventional AM: ~33% efficiency (2/3 power in carrier)
    %   - DSB-SC AM: 100% efficiency (all power in information sidebands)
    %   - SSB AM: 50% efficiency compared to DSB-SC (single sideband)
    %
    % Receiver Requirements:
    %   - Coherent detection with carrier recovery
    %   - Phase-locked loop (PLL) for carrier regeneration
    %   - Costas loop or pilot tone for phase synchronization
    %   - Higher complexity compared to envelope detection
    %
    % See also: csrd.blocks.physical.modulate.analog.AM.DSBAM,
    %           csrd.blocks.physical.modulate.analog.AM.SSBAM,
    %           csrd.blocks.physical.modulate.analog.AM.VSBAM,
    %           csrd.blocks.physical.modulate.BaseModulator

    methods (Access = protected)

        function [modulatedSignal, bandWidth] = baseModulator(obj, messageSignal)
            % baseModulator - Core DSB-SC AM modulation implementation
            %
            % This method performs DSB-SC AM modulation by directly multiplying the
            % message signal with a suppressed carrier, creating both upper and lower
            % sidebands without any carrier component in the output spectrum.
            %
            % Syntax:
            %   [modulatedSignal, bandWidth] = baseModulator(obj, messageSignal)
            %
            % Input Arguments:
            %   messageSignal - Input message signal to be modulated
            %                   Type: real-valued numeric array
            %
            % Output Arguments:
            %   modulatedSignal - DSB-SC AM modulated signal
            %                     Type: real array (suppressed carrier)
            %   bandWidth - Occupied bandwidth of the modulated signal in Hz
            %               Type: positive scalar
            %
            % Processing Steps:
            %   1. Apply message signal directly (carrier multiplication implicit)
            %   2. Calculate bandwidth as twice the message signal bandwidth
            %   3. Return real-valued modulated signal
            %
            % DSB-SC AM Mathematical Model:
            %   s(t) = m(t) × cos(2πfct + φ)
            %   Where:
            %   - m(t) is the message signal
            %   - fc is the carrier frequency (applied at transmission)
            %   - φ is the initial phase
            %
            % Bandwidth Characteristics:
            %   DSB-SC AM bandwidth equals twice the highest frequency component
            %   of the message signal since both upper and lower sidebands are
            %   transmitted: BW = 2 × max(f_message)
            %
            % Spectrum Analysis:
            %   - Lower Sideband: fc - f_max to fc
            %   - Upper Sideband: fc to fc + f_max
            %   - Carrier: Completely suppressed at fc
            %   - Total Bandwidth: 2 × f_max
            %
            % Example:
            %   messageSignal = sin(2*pi*1000*(0:999)'/48000); % 1 kHz tone
            %   [signal, bw] = obj.baseModulator(messageSignal);

            % Apply DSB-SC AM modulation (message signal passes through directly)
            % The actual carrier multiplication occurs in the RF stage
            modulatedSignal = messageSignal;

            % Calculate DSB-SC AM bandwidth
            % Bandwidth is twice the message signal bandwidth due to double sideband transmission
            messageBandwidth = obw(messageSignal, obj.SampleRate);
            bandWidth = 2 * messageBandwidth;

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % genModulatorHandle - Generate configured DSB-SC AM modulator function handle
            %
            % This method configures the DSB-SC AM modulator with default parameters if not
            % specified and returns a function handle for the complete modulation process.
            % DSB-SC AM modulation is inherently analog and single-antenna.
            %
            % Syntax:
            %   modulatorHandle = genModulatorHandle(obj)
            %
            % Output Arguments:
            %   modulatorHandle - Function handle for DSB-SC AM modulation
            %                     Type: function_handle
            %                     Usage: [signal, bw] = modulatorHandle(message)
            %
            % Configuration Parameters:
            %   The method automatically configures missing parameters:
            %   - initPhase: Initial carrier phase (default: 0 radians)
            %   - carrierPhase: Additional phase offset (optional)
            %
            % Default Configuration:
            %   - initPhase: 0 radians (in-phase carrier)
            %   - IsDigital: false (analog modulation)
            %   - NumTransmitAntennas: 1 (single antenna)
            %
            % Phase Configuration Guidelines:
            %   - 0 radians: Standard in-phase transmission
            %   - π/2 radians: Quadrature phase (90-degree shift)
            %   - π radians: Inverted phase (180-degree shift)
            %   - Random phase: For secure or spread spectrum applications
            %
            % Implementation Notes:
            %   The baseModulator returns the message signal directly since
            %   carrier multiplication is typically performed in the RF stage.
            %   This approach maintains system modularity and flexibility.
            %
            % Example:
            %   dsbscMod = csrd.blocks.physical.modulate.analog.AM.DSBSCAM();
            %   modHandle = dsbscMod.genModulatorHandle();
            %   [modSignal, bandwidth] = modHandle(audioData);

            % Set modulation type flags
            obj.IsDigital = false; % DSB-SC AM is analog modulation
            obj.NumTransmitAntennas = 1; % Single antenna transmission

            % Configure DSB-SC AM parameters if not provided
            if ~isfield(obj.ModulatorConfig, 'initPhase')
                % Set default initial phase to zero (in-phase carrier)
                obj.ModulatorConfig.initPhase = 0;
            end

            % Optional: Add carrier phase offset for advanced applications
            if ~isfield(obj.ModulatorConfig, 'carrierPhase')
                % No additional carrier phase offset by default
                obj.ModulatorConfig.carrierPhase = 0;
            end

            % Create function handle for modulation
            modulatorHandle = @(messageSignal)obj.baseModulator(messageSignal);

        end

    end

end
