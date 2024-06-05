classdef APSK < BaseModulation
    
    properties
        
        SamplePerSymbol (1, 1) {mustBePositive, mustBeReal} = 2
        
    end
    
    properties (Access = protected)
        
        filterCoeffs
        ostbc
        
    end
    
    methods (Access = protected)
        
        function [y, bw] = baseModulation(obj, x)
            
            x = apskmod(x, obj.ModulationOrder, obj.ModulationConfig.Radii, obj.ModulationConfig.PhaseOffset);
            x = obj.ostbc(x);
            
            % Pulse shape
            y = filter(obj.filterCoeffs, 1, upsample(x, obj.SamplePerSymbol));

            bw = obw(y, obj.SampleRate);
            if obj.NumTransmitAntennnas > 1
                bw = max(bw);
            end
            
        end
        
    end
    
    methods
        
        function filterCoeffs = genFilterCoeffs(obj)
            
            filterCoeffs = rcosdesign(obj.ModulationConfig.beta, ...
                obj.ModulationConfig.span, ...
                obj.SamplePerSymbol);
            
        end
        
        function ostbc = genOSTBC(obj)
            
            if obj.NumTransmitAntennnas > 1
                
                if obj.NumTransmitAntennnas == 2
                    ostbc = comm.OSTBCEncoder( ...
                        NumTransmitAntennas = obj.NumTransmitAntennnas);
                else
                    ostbc = comm.OSTBCEncoder( ...
                        NumTransmitAntennas = obj.NumTransmitAntennnas, ...
                        SymbolRate = obj.ModulationConfig.ostbcSymbolRate);
                end
                
            else
                ostbc = @(x)obj.placeHolder(x);
            end
            
        end
        
        function modulatorHandle = genModulationHandle(obj)
            
            obj.IsDigital = true;
            obj.filterCoeffs = obj.genFilterCoeffs;
            obj.ostbc = obj.genOSTBC;
            modulatorHandle = @(x)obj.baseModulation(x);
            
        end
        
    end
    
end
