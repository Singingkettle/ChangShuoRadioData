classdef GFSK < blocks.physical.modulate.BaseModulator
    % GFSK (Gaussian Frequency Shift Keying) Modulator
    % References:
    % - https://www.mathworks.com/help/comm/ug/continuous-phase-modulation.html
    % - MSK and GMSK are special cases of CPFSK
    % - GFSK implementation refers to: https://www.mathworks.com/help/deeplearning/ug/modulation-classification-with-deep-learning.html
    % - For M-ary GFSK, bandwidth increases with modulation order

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
            % Initialize modulator parameters
            obj.NumTransmitAntennas = 1;
            obj.IsDigital = true;

            % Create constellation for M-ary GFSK
            obj.const = (- (obj.ModulatorOrder - 1):2:(obj.ModulatorOrder - 1))';

            % Set default Bandwidth-Time product (BT)
            if ~isfield(obj.ModulatorConfig, 'BandwidthTimeProduct')
                % BT typically ranges from 0.2 to 0.5
                obj.ModulatorConfig.BandwidthTimeProduct = rand(1) * 0.2 + 0.2;
            end

            % Create GFSK modulator with M-ary support
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
