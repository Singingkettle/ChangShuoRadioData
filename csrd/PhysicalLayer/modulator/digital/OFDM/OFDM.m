classdef OFDM < BaseModulator
    % https://www.mathworks.com/help/5g/ug/resampling-filter-design-in-ofdm-functions.html
    % https://www.mathworks.com/help/dsp/ug/overview-of-multirate-filters.html  关于如何实现对OFDM信号采样的仿真，本质上是一个转换
    % https://github.com/wonderfulnx/acousticOFDM/blob/main/Matlab/IQmod.m      关于如何实现对OFDM信号采样的仿真
    % https://www.mathworks.com/help/comm/ug/introduction-to-mimo-systems.html 基于这个例子确定OFDM-MIMO的整体流程
    % https://www.mathworks.com/help/comm/ug/ofdm-transmitter-and-receiver.html
    % 这个链接里面详细介绍了如何定义OFDM调制信号的采样率以及带宽
    
    properties
        firstStageModulator
        ostbc
        secondStageModulator
        NumDataSubcarriers
        NumSymbols
        UsedSubCarr
        usePilot
        acrossSymbol
        pilotModulator
    end
    
    methods (Access = protected)
        
        function [y, bw] = baseModulator(obj, x)
            
            x = obj.firstStageModulator(x);
            x = obj.ostbc(x);
            obj.NumSymbols = fix(size(x, 1) / obj.NumDataSubcarriers);
            x = x(1:obj.NumSymbols * obj.NumDataSubcarriers, :);
            x = reshape(x, [obj.NumDataSubcarriers, obj.NumSymbols, obj.NumTransmitAntennas]);
            
            obj.secondStageModulator.NumSymbols = obj.NumSymbols;
            if obj.acrossSymbol
                obj.secondStageModulator.PilotCarrierIndices = obj.secondStageModulator.PilotCarrierIndices(:, 1:obj.NumSymbols, :);
            end
            if obj.usePilot
                px = randi([0, obj.ModulatorConfig.pilot.ModulatorOrder - 1], ...
                    size(obj.secondStageModulator.PilotCarrierIndices, 1), obj.NumSymbols, obj.NumTransmitAntennas);
                px = obj.pilotModulator(px);
                y = obj.secondStageModulator(x, px);
            else
                y = obj.secondStageModulator(x);
            end
            bw = obj.ModulatorConfig.ofdm.FFTLength / 2 - obj.ModulatorConfig.ofdm.NumGuardBandCarriers;
            bw(1) = bw(1)*-1;
            bw = bw.*obj.ModulatorConfig.ofdm.Subcarrierspacing;
            obj.TimeDuration = size(y, 1) / obj.SampleRate;
            
        end
        
        function ostbc = genOSTBC(obj)
            
            if obj.NumTransmitAntennas > 1
                
                if obj.NumTransmitAntennas == 2
                    ostbc = comm.OSTBCEncoder( ...
                        NumTransmitAntennas = obj.NumTransmitAntennas);
                else
                    ostbc = comm.OSTBCEncoder( ...
                        NumTransmitAntennas = obj.NumTransmitAntennas, ...
                        SymbolRate = obj.ModulatorConfig.ostbcSymbolRate);
                end
                
            else
                ostbc = @(x)obj.placeHolder(x);
            end
            
        end
        
        function firstStageModulator = genFirstStageModulator(obj)
            
            if contains(lower(obj.ModulatorConfig.base.mode), "psk")
                firstStageModulator = @(x)pskmod(x, ...
                    obj.ModulatorOrder, ...
                    obj.ModulatorConfig.base.PhaseOffset, ...
                    obj.ModulatorConfig.base.SymbolOrder);
            elseif contains(lower(obj.ModulatorConfig.base.mode), "qam")
                firstStageModulator = @(x)qammod(x, ...
                    obj.ModulatorOrder, ...
                    'UnitAveragePower', true);
            else
                error('Not implemented %s modulator in OFDM', mode);
            end
            
        end

        function pilotModulator = genPilotModulator(obj)
            
            if contains(lower(obj.ModulatorConfig.pilot.mode), "psk")
                pilotModulatorOrder = randsample([2, 4, 8, 16, 32, 64], 1);
                pilotModulator = @(x)pskmod(x, ...
                    pilotModulatorOrder, ...
                    obj.ModulatorConfig.pilot.PhaseOffset, ...
                    obj.ModulatorConfig.pilot.SymbolOrder);
            elseif contains(lower(obj.ModulatorConfig.pilot.mode), "qam")
                pilotModulatorOrder = randsample([8, 16, 32, 64, 128], 1);
                pilotModulator = @(x)qammod(x, ...
                    pilotModulatorOrder, ...
                    'UnitAveragePower', true);
            else

                error('Not implemented %s modulator in OFDM', mode);
            end
            obj.ModulatorConfig.pilot.ModulatorOrder = pilotModulatorOrder;
        end

        function secondStageModulator = genSecondStageModulator(obj)
            p = obj.ModulatorConfig.ofdm;
            
            secondStageModulator = comm.OFDMModulator( ...
                FFTLength = p.FFTLength, ...
                NumGuardBandCarriers = p.NumGuardBandCarriers, ...
                InsertDCNull = p.InsertDCNull, ...
                CyclicPrefixLength = p.CyclicPrefixLength, ...
                NumTransmitAntennas = obj.NumTransmitAntennas, ...
                NumSymbols=100000);

            if isfield(p, 'PilotCarrierIndices')
                secondStageModulator.PilotCarrierIndices = p.PilotCarrierIndices;
            end
            if p.Windowing
                secondStageModulator.Windowing = true;
                secondStageModulator.WindowLength = p.WindowLength;
            end
            
            % Without pilot, the UsedSubCarr is equal NumDataSubcarriers
            obj.UsedSubCarr = p.FFTLength - sum(secondStageModulator.NumGuardBandCarriers);
            if p.InsertDCNull
                obj.UsedSubCarr = obj.UsedSubCarr - 1;
            end
            
            obj.NumDataSubcarriers = obj.UsedSubCarr;
            if isfield(p, 'PilotCarrierIndices')
                obj.NumDataSubcarriers = obj.NumDataSubcarriers - size(p.PilotCarrierIndices, 1);
            end
            
            obj.SampleRate = obj.ModulatorConfig.ofdm.Subcarrierspacing * p.FFTLength;
        end
        
    end
    
    methods
        
        function modulatorHandle = genModulatorHandle(obj)
            
            obj.IsDigital = true;
            if ~isfield(obj.ModulatorConfig, 'ostbcSymbolRate')
                if obj.NumTransmitAntennas > 2
                    obj.ModulatorConfig.ostbcSymbolRate = randi([0, 1])*0.25+0.5;
                end
            end
            obj.ostbc = obj.genOSTBC;
            if ~isfield(obj.ModulatorConfig, 'base')
                obj.ModulatorConfig.base.mode = randsample(["psk", "qam"], 1);
                if strcmpi(obj.ModulatorConfig.base.mode, "psk")
                    obj.ModulatorConfig.base.PhaseOffset = rand(1)*2*pi;
                    obj.ModulatorConfig.base.SymbolOrder = randsample(["bin", "gray"], 1);
                end
                obj.ModulatorConfig.ofdm.FFTLength = randsample([128, 256, 512, 1024, 2048], 1);
                obj.ModulatorConfig.ofdm.NumGuardBandCarriers = [0; 0];
                obj.ModulatorConfig.ofdm.NumGuardBandCarriers(1) = randi([5, 12], 1);
                obj.ModulatorConfig.ofdm.NumGuardBandCarriers(2) = randi([5, 12], 1);
                obj.ModulatorConfig.ofdm.InsertDCNull = true;%randsample([true, false], 1);
                obj.ModulatorConfig.ofdm.CyclicPrefixLength = randi([12, 32], 1);
                obj.ModulatorConfig.ofdm.Subcarrierspacing = randsample([20, 40], 1)*1e3;
                obj.usePilot = true; %randsample([true, false], 1);
                obj.acrossSymbol = randsample([true, false], 1);
                if obj.usePilot
                    obj.ModulatorConfig.pilot.mode = randsample(["psk", "qam"], 1);
                    if strcmpi(obj.ModulatorConfig.pilot.mode, "psk")
                        obj.ModulatorConfig.pilot.PhaseOffset = rand(1)*2*pi;
                        obj.ModulatorConfig.pilot.SymbolOrder = randsample(["bin", "gray"], 1);
                    end
                    nPilot = randi([4, 32], 1);
                    validRangeLeft = obj.ModulatorConfig.ofdm.NumGuardBandCarriers(1)+1:floor(obj.ModulatorConfig.ofdm.FFTLength/2); 
                    validRangeRight = floor(obj.ModulatorConfig.ofdm.FFTLength/2)+2:obj.ModulatorConfig.ofdm.FFTLength-obj.ModulatorConfig.ofdm.NumGuardBandCarriers(2); 
                    validRange = cat(2, validRangeLeft, validRangeRight);

                    repeatTimes = obj.NumTransmitAntennas;
                    if obj.acrossSymbol
                        repeatTimes = repeatTimes * 100000;
                    end
                    PilotCarrierIndices = zeros(nPilot, repeatTimes);
                    for i=1:repeatTimes
                        PilotCarrierIndices(:, i) = randsample(validRange, nPilot);
                    end
                    obj.ModulatorConfig.ofdm.PilotCarrierIndices = reshape(PilotCarrierIndices, nPilot, [], obj.NumTransmitAntennas);
                end
                obj.ModulatorConfig.ofdm.Windowing = randsample([true, false], 1);
                if obj.ModulatorConfig.ofdm.Windowing
                    obj.ModulatorConfig.ofdm.WindowLength = randi(min(obj.ModulatorConfig.ofdm.CyclicPrefixLength), 1);
                end
            else
                if ~isfield(obj.ModulatorConfig.ofdm, 'PilotCarrierIndices')
                    obj.usePilot = false;
                else
                    obj.usePilot = true;
                    if size(obj.ModulatorConfig.ofdm.PilotCarrierIndices, 2) > 1
                        obj.acrossSymbol = true;
                    else
                        obj.acrossSymbol = false;
                    end
                end
            end
            obj.firstStageModulator = obj.genFirstStageModulator;
            obj.secondStageModulator = obj.genSecondStageModulator;
            if obj.usePilot
                obj.secondStageModulator.PilotInputPort = true;
            end
            if obj.usePilot
                obj.pilotModulator = obj.genPilotModulator;
            end
            modulatorHandle = @(x)obj.baseModulator(x);
        end
        
    end
    
end
