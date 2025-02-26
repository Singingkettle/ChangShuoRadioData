classdef SSBAM < blocks.physical.modulate.analog.AM.DSBSCAM
    % SSBAM Single Sideband Amplitude Modulation class
    %   Implements Single Sideband Amplitude Modulation (SSB-AM) which uses only
    %   one sideband (upper or lower) for transmission.
    %
    % Properties (inherited from DSBSCAM):
    %   SampleRate       - Sampling rate in Hz
    %   ModulatorConfig - Configuration structure for modulator settings
    %
    % Methods:
    %   genModulatorHandle - Generates the modulator function handle
    %   baseModulator     - Performs the actual SSB-AM modulation
    %
    % Notes:
    %   - More bandwidth efficient compared to other AM schemes
    %   - Uses Hilbert transform for sideband selection
    %   - Bandwidth equals the message bandwidth
    %   - Can operate in either upper sideband (USB) or lower sideband (LSB) mode
    %   - Requires more complex demodulation compared to standard AM
    %
    % Example:
    %   modulator = SSBAM();
    %   modulator.ModulatorConfig.mode = 'upper';  % Set to USB mode
    %   modulatedSignal = modulator.modulate(messageSignal);

    methods (Access = protected)

        function [y, bw] = baseModulator(obj, x)
            % Get message bandwidth
            msgBW = obw(x, obj.SampleRate);

            % Select sideband based on configuration
            if strcmp(obj.ModulatorConfig.mode, 'upper')
                % Upper sideband: Use positive frequencies
                y = complex(x, imag(hilbert(x)));
                % Bandwidth spans from 0 to message bandwidth
                bw = [0, msgBW];
            else
                % Lower sideband: Use negative frequencies
                y = complex(x, -imag(hilbert(x)));
                % Bandwidth spans from -message bandwidth to 0
                bw = [-msgBW, 0];
            end

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % Set analog modulation parameters
            obj.IsDigital = false;
            obj.NumTransmitAntennas = 1;

            % Randomly select upper or lower sideband if not specified
            if ~isfield(obj.ModulatorConfig, 'mode')
                obj.ModulatorConfig.mode = randsample(["upper", "lower"], 1);
            end

            modulatorHandle = @(x)obj.baseModulator(x);
        end

    end

end
