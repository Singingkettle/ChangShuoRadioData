classdef CPFSK < GFSK
    % https://www.mathworks.com/help/comm/ug/continuous-phase-modulation.html
    % MSK 和 GMSK 是CPFSK的特例，所以在构造数据集的时候不考虑更高阶，
    % https://blog.csdn.net/Insomnia_X/article/details/126333301
    % TODO: Support CPFSK in high order > 2

    methods

        function modulatorHandle = genModulator(obj)

            if obj.ModulatorConfig.order <= 2
                error("Value of Modulation order must be large than 2.");
            end

            obj.meanM = mean(0:obj.ModulatorConfig.order - 1);
            obj.pureModulator = comm.CPFSKModulator( ...
                ModulationOrder = obj.ModulatorConfig.order, ...
                ModulationIndex = obj.modulatorConfig.ModulationIndex, ...
                InitialPhaseOffset = obj.modulatorConfig.initialPhaseOffset, ...
                SamplesPerSymbol = obj.SamplePerSymbol);

            modulatorHandle = @(x)baseMdulator(x);
            obj.NumTransmitAntennnas = 1;
            obj.IsDigital = true;

        end

    end

end
