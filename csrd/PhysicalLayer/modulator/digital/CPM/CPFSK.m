classdef CPFSK < GFSK
    % https://www.mathworks.com/help/comm/ug/continuous-phase-modulation.html
    % MSK 和 GMSK 是CPFSK的特例，所以在构造数据集的时候不考虑更低阶，
    % https://blog.csdn.net/Insomnia_X/article/details/126333301
    % TODO: Support CPFSK in high order > 2
    
    methods
        
        function modulatorHandle = genModulatorHandle(obj)
            
            if obj.ModulatorOrder <= 2
                error("Value of Modulator order must be large than 2.");
            end
            obj.NumTransmitAntennas = 1;
            obj.IsDigital = true;
            
            if ~isfield(obj.ModulatorConfig, 'ModulatorIndex')
                obj.ModulatorConfig.ModulatorIndex = rand(1)*10;
                obj.ModulatorConfig.InitialPhaseOffset = rand(1)*2*pi;
            end

            obj.const = (- (obj.ModulatorOrder - 1):2:(obj.ModulatorOrder - 1))';
            obj.pureModulator = comm.CPFSKModulator( ...
                ModulationOrder = obj.ModulatorOrder, ...
                ModulationIndex = obj.ModulatorConfig.ModulatorIndex, ...
                InitialPhaseOffset = obj.ModulatorConfig.InitialPhaseOffset, ...
                SamplesPerSymbol = obj.SamplePerSymbol);
            
            modulatorHandle = @(x)obj.baseModulator(x);
            
            
        end
        
    end
    
end
