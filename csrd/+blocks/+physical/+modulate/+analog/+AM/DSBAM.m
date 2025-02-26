% DSBAM is a class that extends DSBSCAM. It represents a Double Sideband Amplitude Modulator.
classdef DSBAM < blocks.physical.modulate.analog.AM.DSBSCAM
    % DSBAM Double Sideband Amplitude Modulation class
    %   Implements conventional Double Sideband Amplitude Modulation (DSB-AM),
    %   which includes both sidebands and the carrier component.
    %
    % Properties (inherited from DSBSCAM):
    %   SampleRate       - Sampling rate in Hz
    %   ModulatorConfig - Configuration structure containing:
    %       carramp     - Carrier amplitude (default: 1 + random offset)
    %       initPhase  - Initial phase (default: 0)
    %
    % Methods:
    %   genModulatorHandle - Configures and returns the modulator function
    %   baseModulator     - Implements DSB-AM modulation: y(t) = Ac[1 + m(t)]cos(wct)
    %
    % Key Features:
    %   - Classic analog modulation scheme
    %   - Includes carrier and both sidebands
    %   - Bandwidth = 2 * message_bandwidth
    %   - Simple envelope detection possible at receiver
    %   - Less power efficient due to carrier transmission
    %
    % Example:
    %   modulator = DSBAM();
    %   modulator.ModulatorConfig.carramp = 1.2;  % Set carrier amplitude
    %   modulatedSignal = modulator.modulate(messageSignal);

    methods (Access = protected)

        function [y, bw] = baseModulator(obj, x)
            % Implements DSB-AM modulation
            %
            % Args:
            %   x: Input message signal
            %
            % Returns:
            %   y: Modulated signal y(t) = Ac[1 + m(t)]cos(wct)
            %   bw: Signal bandwidth (2 * message_bandwidth)

            % Get carrier amplitude
            carrAmp = obj.ModulatorConfig.carramp;

            % Modulate the signal
            % DSBAM: y(t) = Ac[1 + m(t)]cos(wct)
            y = x + carrAmp;

            % Calculate bandwidth
            % DSBAM bandwidth is twice the highest frequency
            % component of the modulating signal
            bw = obw(x, obj.SampleRate) * 2;
        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % Configures the modulator and returns function handle
            %
            % Sets analog modulation parameters and initializes carrier
            % amplitude if not provided
            %
            % Returns:
            %   modulatorHandle: Function handle to baseModulator

            % Set analog modulation parameters
            obj.IsDigital = false;
            obj.NumTransmitAntennas = 1;

            % Set default carrier amplitude if not provided
            if ~isfield(obj.ModulatorConfig, 'carramp')
                obj.ModulatorConfig.carramp = 1 + rand(1) * 0.5;
                obj.ModulatorConfig.initPhase = 0;
            end

            modulatorHandle = @(x)obj.baseModulator(x);
        end

    end

end
