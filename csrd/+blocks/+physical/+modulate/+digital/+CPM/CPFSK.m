classdef CPFSK < blocks.physical.modulate.digital.CPM.GFSK
    % CPFSK Continuous Phase Frequency Shift Keying Modulator
    %
    % References:
    % - https://www.mathworks.com/help/comm/ug/continuous-phase-modulation.html
    % - MSK and GMSK are special cases of CPFSK, so lower orders are not considered
    %   when constructing the dataset
    % - For implementation details:
    %   https://blog.csdn.net/Insomnia_X/article/details/126333301
    % TODO: Support CPFSK in high order > 2

    methods

        function modulatorHandle = genModulatorHandle(obj)
            % Validate modulation order
            if obj.ModulatorOrder <= 2
                error("Modulation order must be greater than or equal to 2");
            end

            % Initialize modulator parameters
            obj.NumTransmitAntennas = 1;
            obj.IsDigital = true;

            % Create constellation for M-ary CPFSK
            obj.const = (- (obj.ModulatorOrder - 1):2:(obj.ModulatorOrder - 1))';

            % Set default modulator configuration if not provided
            if ~isfield(obj.ModulatorConfig, 'ModulationIndex')
                % Modulation index typically ranges from 0.5 to 1
                obj.ModulatorConfig.ModulationIndex = 0.5 + rand(1) * 0.5;
                obj.ModulatorConfig.InitialPhaseOffset = rand(1) * 2 * pi;
            end

            % Create CPFSK modulator
            obj.pureModulator = comm.CPFSKModulator( ...
                ModulationOrder = obj.ModulatorOrder, ...
                ModulationIndex = obj.ModulatorConfig.ModulationIndex, ...
                InitialPhaseOffset = obj.ModulatorConfig.InitialPhaseOffset, ...
                SamplesPerSymbol = obj.SamplePerSymbol);

            modulatorHandle = @(x)obj.baseModulator(x);
        end

    end

end
