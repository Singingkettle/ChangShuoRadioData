classdef CPFSK < GFSK
    % https://www.mathworks.com/help/comm/ug/continuous-phase-modulation.html
    % MSK 和 GMSK 是CPFSK的特例，所以在构造数据集的时候不考虑更低阶，
    % https://blog.csdn.net/Insomnia_X/article/details/126333301
    % TODO: Support CPFSK in high order > 2
    
    methods
        
        function modulatorHandle = genModulatorHandle(obj)
            
            if obj.ModulationOrder <= 2
                error("Value of Modulation order must be large than 2.");
            end
            obj.NumTransmitAntennnas = 1;
            obj.IsDigital = true;
            
            obj.const = (- (obj.ModulationOrder - 1):2:(obj.ModulationOrder - 1))';
            obj.pureModulator = comm.CPFSKModulator( ...
                ModulationOrder = obj.ModulationOrder, ...
                ModulationIndex = obj.ModulatorConfig.ModulationIndex, ...
                InitialPhaseOffset = obj.ModulatorConfig.InitialPhaseOffset, ...
                SamplesPerSymbol = obj.SamplePerSymbol);
            
            modulatorHandle = @(x)obj.baseModulator(x);
            
            
        end
        
    end
    
end
