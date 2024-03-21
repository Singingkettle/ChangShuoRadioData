classdef PAM < BaseModulator

    properties (Dependent = false)
        filterCoeffs
    end

    methods

        function filterCoeffs = get.filterCoeffs(obj)

            filterCoeffs = rcosdesign(obj.modulatorConfig.beta, ...
                obj.modulatorConfig.span, ...
                obj.samplePerSymbol);

        end

        function modulator = getModulator(obj)
            modulator = @(x)basePamModulator(x, ...
                obj.modulatorConfig.order, ...
                obj.samplePerSymbol, ...
                obj.filterCoeffs);
            obj.isDigital = true;
        end

        function bw = bandWidth(obj, x)

            bw = obw(x, obj.sampleRate) * 2;

        end

        function y = passBand(obj, x)
            y = x;
        end

    end

end

function y = basePamModulator(x, order, sps, filterCoeffs)

    amp = 1 / sqrt(mean(abs(pammod(0:order - 1, order)) .^ 2));
    % Modulate
    syms = amp * pammod(x, order);
    % Pulse shape
    y = filter(filterCoeffs, 1, upsample(syms, sps));

end
