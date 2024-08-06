classdef PSK < APSK
    % 关于ostbc 与PRC的关系https://publik.tuwien.ac.at/files/pub-et_8438.pdf
    methods (Access = protected)
        
        function [y, bw] = baseModulator(obj, x)
            
            if obj.ModulatorConfig.Differential
                x = dpskmod(x, obj.ModulatorOrder, obj.ModulatorConfig.PhaseOffset, obj.ModulatorConfig.SymbolOrder);
            else
                x = pskmod(x, obj.ModulatorOrder, obj.ModulatorConfig.PhaseOffset, obj.ModulatorConfig.SymbolOrder);
            end
            
            x = obj.ostbc(x);
            
            % Pulse shape
            y = filter(obj.filterCoeffs, 1, upsample(x, obj.SamplePerSymbol));

            bw = obw(y, obj.SampleRate);
            if obj.NumTransmitAntennas > 1
                bw = max(bw);
            end
            
        end
        
    end

    methods
        function modulatorHandle = genModulatorHandle(obj)
            
            if ~isfield(obj.ModulatorConfig, "beta")
                obj.ModulatorConfig.Differential = randsample([true, false], 1);
                obj.ModulatorConfig.SymbolOrder = randsample(["bin", "gray"], 1);
                obj.ModulatorConfig.PhaseOffset = rand(1)*2*pi;
                obj.ModulatorConfig.beta = rand(1);
                obj.ModulatorConfig.span = randi([2, 8])*2;
            end
            if obj.NumTransmitAntennas > 2
                if ~isfield(obj.ModulatorConfig, 'ostbcSymbolRate')
                    obj.ModulatorConfig.ostbcSymbolRate = randi([0, 1])*0.25+0.5;
                end
            end
            obj.IsDigital = true;
            obj.filterCoeffs = obj.genFilterCoeffs;
            obj.ostbc = obj.genOSTBC;
            modulatorHandle = @(x)obj.baseModulator(x);
            
        end
    end

    
end
