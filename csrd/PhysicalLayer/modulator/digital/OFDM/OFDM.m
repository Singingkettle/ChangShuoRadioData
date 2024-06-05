classdef OFDM < BaseModulation
    % https://www.mathworks.com/help/5g/ug/resampling-filter-design-in-ofdm-functions.html
    % https://www.mathworks.com/help/dsp/ug/overview-of-multirate-filters.html  关于如何实现对OFDM信号采样的仿真，本质上是一个转换
    % https://github.com/wonderfulnx/acousticOFDM/blob/main/Matlab/IQmod.m      关于如何实现对OFDM信号采样的仿真
    % https://www.mathworks.com/help/comm/ug/introduction-to-mimo-systems.html 基于这个例子确定OFDM-MIMO的整体流程
    % https://www.mathworks.com/help/comm/ug/ofdm-transmitter-and-receiver.html
    % 这个链接里面详细介绍了如何定义OFDM调制信号的采样率以及带宽
    
    properties (Nontunable)
        Subcarrierspacing (1, 1) {mustBeReal, mustBePositive} = 30e3
    end
    
    properties
        
        firstStageModulation
        ostbc
        secondStageModulation
        NumDataSubcarriers
        NumSymbols
        UsedSubCarr
    end
    
    methods (Access = protected)
        
        function [y, bw] = baseModulation(obj, x)
            
            x = obj.firstStageModulation(x);
            x = obj.ostbc(x);
            obj.NumSymbols = fix(size(x, 1) / obj.NumDataSubcarriers);
            x = x(1:obj.NumSymbols * obj.NumDataSubcarriers, :);
            x = reshape(x, [obj.NumDataSubcarriers, obj.NumSymbols, obj.NumTransmitAntennnas]);
            
            obj.secondStageModulation.NumSymbols = obj.NumSymbols;
            y = obj.secondStageModulation(x);
            
            bw = obj.Subcarrierspacing * obj.UsedSubCarr;
            obj.TimeDuration = size(y, 1) / obj.SampleRate;
            
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
        
        function firstStageModulation = genFirstStageModulation(obj)
            
            if contains(lower(obj.ModulationConfig.base.mode), 'psk')
                firstStageModulation = @(x)pskmod(x, ...
                    obj.ModulationOrder, ...
                    obj.ModulationConfig.base.PhaseOffset, ...
                    obj.ModulationConfig.base.SymbolOrder);
            elseif contains(lower(mode), 'qam')
                firstStageModulation = @(x)qammod(x, ...
                    obj.ModulationOrder, ...
                    'UnitAveragePower', true);
            else
                error('Not implemented %s modulator in OFDM', mode);
            end
            
        end
        
        function secondStageModulation = genSecondStageModulation(obj)
            p = obj.ModulationConfig.ofdm;
            
            secondStageModulation = comm.OFDMModulation( ...
                FFTLength = p.FFTLength, ...
                NumGuardBandCarriers = p.NumGuardBandCarriers, ...
                InsertDCNull = p.InsertDCNull, ...
                CyclicPrefixLength = p.CyclicPrefixLength, ...
                OversamplingFactor = p.OversamplingFactor, ...
                NumTransmitAntennas = obj.NumTransmitAntennnas);
            % TODO: Support insert pilot
            % if p.PilotInputPort
            %     secondStageModulation.PilotInputPort = p.PilotInputPort;
            %     secondStageModulation.PilotCarrierIndices = p.PilotCarrierIndices;
            % end
            
            if p.Windowing
                secondStageModulation.Windowing = true;
                secondStageModulation.WindowLength = p.WindowLength;
            end
            
            % Without pilot, the UsedSubCarr is equal NumDataSubcarriers
            obj.UsedSubCarr = p.FFTLength - sum(secondStageModulation.NumGuardBandCarriers);
            if p.InsertDCNull
                obj.UsedSubCarr = obj.UsedSubCarr - 1;
            end
            
            obj.NumDataSubcarriers = obj.UsedSubCarr;
            % TODO: Support insert pilot
            % if p.PilotInputPort
            %     obj.NumDataSubcarriers = obj.NumDataSubcarriers - sum(p.PilotCarrierIndices);
            % end
            
            obj.SampleRate = obj.Subcarrierspacing * p.FFTLength;
        end
        
    end
    
    methods
        
        function modulatorHandle = genModulationHandle(obj)
            
            obj.IsDigital = true;
            obj.ostbc = obj.genOSTBC;
            obj.firstStageModulation = obj.genFirstStageModulation;
            obj.secondStageModulation = obj.genSecondStageModulation;
            modulatorHandle = @(x)obj.baseModulation(x);
            
        end
        
    end
    
end
