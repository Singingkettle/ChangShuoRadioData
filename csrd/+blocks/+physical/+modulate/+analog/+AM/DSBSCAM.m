classdef DSBSCAM < blocks.physical.modulate.BaseModulator
    % DSBSCAM Double Sideband Suppressed Carrier Amplitude Modulation class
    %   Implements Double Sideband Suppressed Carrier Amplitude Modulation (DSB-SC AM),
    %   a variant of amplitude modulation where the carrier is suppressed.
    %
    % Properties (inherited from BaseModulator):
    %   SampleRate       - Sampling rate in Hz
    %   ModulatorConfig - Configuration structure for modulator settings
    %
    % Methods:
    %   genModulatorHandle - Generates the modulator function handle
    %   baseModulator     - Performs the actual DSB-SC AM modulation
    %
    % Key Features:
    %   - No carrier component in output spectrum
    %   - Bandwidth = 2 * message_bandwidth
    %   - More power efficient than conventional AM due to suppressed carrier
    %   - Requires coherent detection at receiver
    %   - Simpler implementation compared to other AM variants
    %
    % Example:
    %   modulator = DSBSCAM();
    %   modulator.ModulatorConfig.initPhase = 0;  % Set initial phase
    %   modulatedSignal = modulator.modulate(messageSignal);

    methods (Access = protected)

        function [y, bw] = baseModulator(obj, x)
            % Modulate the signal
            % DSBSC: y(t) = m(t)cos(wct)
            y = x;

            % Calculate bandwidth
            % DSBSC bandwidth is twice the highest frequency
            % component of the modulating signal
            % Same as DSBAM but without carrier component
            bw = obw(x, obj.SampleRate) * 2;
        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % Set analog modulation parameters
            obj.IsDigital = false;
            obj.NumTransmitAntennas = 1;

            % Set default initial phase if not provided
            if ~isfield(obj.ModulatorConfig, 'initPhase')
                obj.ModulatorConfig.initPhase = 0;
            end

            modulatorHandle = @(x)obj.baseModulator(x);
        end

    end

end
