classdef GFSK < BaseModulator
    % https://www.mathworks.com/help/comm/ug/continuous-phase-modulation.html
    % MSK 和 GMSK 是CPFSK的特例，所以在构造数据集的时候不考虑更高阶，
    % https://blog.csdn.net/Insomnia_X/article/details/126333301
    % TODO: Support CPFSK in high order > 2
    methods

        function modulator = getModulator(obj)

            modulator = @(x)baseGFSKMdulator(x, obj.modulatorConfig, ...
                obj.samplePerSymbol);

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

function y = baseGFSKMdulator(x, modulatorConfig, sps)

    modulator = comm.CPMModulator( ...
        ModulationOrder = modulatorConfig.order, ...
        FrequencyPulse = "Gaussian", ...
        ModulationIndex = 1, ...
        BandwidthTimeProduct = modulatorConfig.bandwidthTimeProduct, ...
        SamplesPerSymbol = sps);
    meanM = mean(0:modulatorConfig.order - 1);
    y = modulator(2 * (x - meanM));

end
