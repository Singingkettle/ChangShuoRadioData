classdef PM < blocks.physical.modulate.BaseModulator
    % PM (Phase Modulation)
    % - Bandwidth depends on phase deviation and message bandwidth
    % - Similar to FM but modulates phase directly
    % - Message signal directly affects phase (no integration needed)

    methods (Access = protected)

        function [y, bw] = baseModulator(obj, x)
            % Phase modulation
            y = exp(1i * (obj.ModulatorConfig.PhaseDeviation * x + ...
                obj.ModulatorConfig.InitPhase));

            % Calculate bandwidth
            % Get message signal parameters
            bw = obw(y, obj.SampleRate);
            
        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % Set analog modulation parameters
            obj.IsDigital = false;
            obj.NumTransmitAntennas = 1;

            % Set default phase deviation if not provided
            if ~isfield(obj.ModulatorConfig, 'PhaseDeviation')
                % Random phase deviation between π/4 and π/2
                obj.ModulatorConfig.PhaseDeviation = (pi / 4) + rand(1) * (pi / 4);
                obj.ModulatorConfig.InitPhase = 0;
            end

            modulatorHandle = @(x)obj.baseModulator(x);
        end

    end

end
