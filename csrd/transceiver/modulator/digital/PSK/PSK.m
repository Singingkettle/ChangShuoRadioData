classdef PSK < APSK
    % 关于ostbc 与PRC的关系https://publik.tuwien.ac.at/files/pub-et_8438.pdf
    methods (Access = protected)

        function y = baseModulator(obj, x)

            if differential
                x = dpskmod(x, obj.ModulatorConfig.order);
            else
                x = pskmod(x, obj.ModulatorConfig.order);
            end

            x = obj.ostbc(x);

            % Pulse shape
            y = filter(obj.filterCoeffs, 1, upsample(x, obj.SamplePerSymbol));

        end

    end

end
