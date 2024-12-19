% DSBAM is a class that extends DSBSCAM. It represents a Double Sideband Amplitude Modulator.
classdef DSBAM < blocks.physical.modulate.analog.AM.DSBSCAM

    methods (Access = protected)

        % baseModulator is a method that performs the base modulation.
        % It takes two inputs: the object instance 'obj' and the input signal 'x'.
        % It returns two outputs: the modulated signal 'y' and the bandwidth 'bw'.
        function [y, bw] = baseModulator(obj, x)

            % The modulated signal 'y' is calculated by adding the carrier amplitude to the input signal.
            y = x + obj.ModulatorConfig.carramp;

            % The bandwidth 'bw' is calculated by doubling the occupied bandwidth of the input signal.
            bw = obw(x, obj.SampleRate) * 2;

        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)

            if ~isfield(obj.ModulatorConfig, 'carramp')
                obj.ModulatorConfig.carramp = 1 + rand(1) * 0.5;
                obj.ModulatorConfig.initPhase = 0;
            end

            obj.IsDigital = false;
            % donot consider multi-tx in analog modulation
            obj.NumTransmitAntennas = 1;
            modulatorHandle = @(x)obj.baseModulator(x);

        end

    end

end
