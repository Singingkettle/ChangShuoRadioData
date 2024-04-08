classdef PAM < BaseModulator

    properties

        SamplePerSymbol (1, 1) {mustBePositive, mustBeReal} = 2

    end

    properties (Access = protected)

        filterCoeffs

    end

    methods (Access = protected)

        function y = baseModulator(obj, x)

            amp = 1 / sqrt(mean(abs(pammod(0:obj.ModulatorConfig.order - 1, obj.ModulatorConfig.order)) .^ 2));
            % Modulate
            x = amp * pammod(x, order);

            % Pulse shape
            y = filter(obj.filterCoeffs, 1, upsample(x, obj.SamplePerSymbol));

        end

    end

    methods

        function filterCoeffs = genFilterCoeffs(obj)

            filterCoeffs = rcosdesign(obj.ModulatorConfig.beta, ...
                obj.ModulatorConfig.span, ...
                obj.SamplePerSymbol);

        end

        function modulator = genModulator(obj)

            obj.filterCoeffs = obj.getFilterCoeffs;
            modulator = @(x)baseModulator(x);
            obj.NumTransmitAntennnas = 1;
            obj.IsDigital = true;

        end

    end

end
