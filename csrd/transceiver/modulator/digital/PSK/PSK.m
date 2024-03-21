classdef PSK < BaseModulator

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
            modulator = @(x)basPSKModulator(x, ...
                obj.modulatorConfig.order, ...
                obj.samplePerSymbol, ...
                obj.filterCoeffs, ...
                obj.modulatorConfig.differential);

            obj.isDigital = true;

        end

        function bw = bandWidth(obj, x)

            bw = obw(x, obj.sampleRate);

        end

        function y = passBand(obj, x)
            y = real(x .* obj.carrierWave);
        end

    end

end

function y = basPSKModulator(x, order, sps, filterCoeffs, differential)

    if differential
        y = dpskmod(x, order);
    else
        y = pskmod(x, order);
    end

    % Pulse shape
    y = filter(filterCoeffs, 1, upsample(y, sps));

end
