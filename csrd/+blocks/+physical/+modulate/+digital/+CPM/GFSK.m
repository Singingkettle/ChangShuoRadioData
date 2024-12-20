classdef GFSK < blocks.physical.modulate.BaseModulator
    % https://www.mathworks.com/help/comm/ug/continuous-phase-modulation.html
    % MSK 和 GMSK 是CPFSK的特例，所以在构造数据集的时候不考虑更低阶，
    % https://blog.csdn.net/Insomnia_X/article/details/126333301
    % https://www.eevblog.com/forum/beginners/need-some-help-with-si4362-(gfsk-vs-gmsk)/
    % 上面的链接是关于GFSK与GMSK的区别
    % GFSK 的实现参考了: https://www.mathworks.com/help/deeplearning/ug/modulation-classification-with-deep-learning.html
    % TODO: Support CPFSK in high order > 2

    properties

        pureModulator
        const

    end

    methods (Access = protected)

        function [y, bw] = baseModulator(obj, x)

            y = obj.pureModulator(obj.const(x(:) + 1));
            bw = obw(y, obj.SampleRate);
        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)

            % if obj.ModulatorOrder <= 2
            %     error("Value of Modulator order must be large than 2.");
            % end
            obj.NumTransmitAntennas = 1;
            obj.IsDigital = true;
            obj.const = (- (obj.ModulatorOrder - 1):2:(obj.ModulatorOrder - 1))';

            if ~isfield(obj.ModulatorConfig, 'BandwidthTimeProduct')
                obj.ModulatorConfig.BandwidthTimeProduct = rand(1) * 0.2 + 0.2;
            end

            obj.pureModulator = comm.CPMModulator( ...
                ModulationOrder = obj.ModulatorOrder, ...
                FrequencyPulse = "Gaussian", ...
                ModulationIndex = 1, ...
                BandwidthTimeProduct = obj.ModulatorConfig.BandwidthTimeProduct, ...
                SamplesPerSymbol = obj.SamplePerSymbol);

            modulatorHandle = @(x)obj.baseModulator(x);

        end

    end

end
