classdef OFDM < BaseModulator
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

        firstStageModulator
        ostbc
        secondStageModulator
        NumDataSubcarriers
        NumSymbols
        UsedSubCarr
    end

    methods (Access = protected)

        function [y, bw] = baseModulator(obj, x)

            x = obj.firstStageModulator(x);
            x = obj.ostbc(x);
            obj.NumSymbols = fix(size(x, 1) / obj.NumDataSubcarriers);
            x = x(1:obj.NumSymbols * obj.NumDataSubcarriers, :);
            x = reshape(x, [obj.NumDataSubcarriers, obj.NumSymbols, obj.NumTransmitAntennnas]);

            obj.secondStageModulator.NumSymbols = obj.NumSymbols;
            y = obj.secondStageModulator(x);
            
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
                        SymbolRate = obj.ModulatorConfig.ostbcSymbolRate);
                end

            else
                ostbc = @(x)obj.placeHolder(x);
            end

        end

        function firstStageModulator = genFirstStageModulator(obj)

            if contains(lower(obj.ModulatorConfig.base.mode), 'psk')
                firstStageModulator = @(x)pskmod(x, ...
                    obj.ModulationOrder, ...
                    obj.ModulatorConfig.base.PhaseOffset, ...
                    obj.ModulatorConfig.base.SymbolOrder);
            elseif contains(lower(mode), 'qam')
                firstStageModulator = @(x)qammod(x, ...
                    obj.ModulationOrder, ...
                    'UnitAveragePower', true);
            else
                error('Not implemented %s modulator in OFDM', mode);
            end

        end

        function secondStageModulator = genSecondStageModulator(obj)
            p = obj.ModulatorConfig.ofdm;

            secondStageModulator = comm.OFDMModulator( ...
                FFTLength = p.FFTLength, ...
                NumGuardBandCarriers = p.NumGuardBandCarriers, ...
                InsertDCNull = p.InsertDCNull, ...
                CyclicPrefixLength = p.CyclicPrefixLength, ...
                OversamplingFactor = p.OversamplingFactor, ...
                NumTransmitAntennas = obj.NumTransmitAntennnas);
            % TODO: Support insert pilot
            % if p.PilotInputPort
            %     secondStageModulator.PilotInputPort = p.PilotInputPort;
            %     secondStageModulator.PilotCarrierIndices = p.PilotCarrierIndices;
            % end

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
            % TODO: Support insert pilot
            % if p.PilotInputPort
            %     obj.NumDataSubcarriers = obj.NumDataSubcarriers - sum(p.PilotCarrierIndices);
            % end

            obj.SampleRate = obj.Subcarrierspacing * p.FFTLength;
        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            
            obj.IsDigital = true;
            obj.ostbc = obj.genOSTBC;
            obj.firstStageModulator = obj.genFirstStageModulator;
            obj.secondStageModulator = obj.genSecondStageModulator;
            modulatorHandle = @(x)obj.baseModulator(x);
            
        end

    end

end
