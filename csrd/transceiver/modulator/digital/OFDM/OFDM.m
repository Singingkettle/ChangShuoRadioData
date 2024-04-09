classdef OFDM < BaseModulator
    % https://www.mathworks.com/help/5g/ug/resampling-filter-design-in-ofdm-functions.html
    % https://www.mathworks.com/help/dsp/ug/overview-of-multirate-filters.html  关于如何实现对OFDM信号采样的仿真，本质上是一个转换
    % https://github.com/wonderfulnx/acousticOFDM/blob/main/Matlab/IQmod.m      关于如何实现对OFDM信号采样的仿真
    % https://www.mathworks.com/help/comm/ug/introduction-to-mimo-systems.html 基于这个例子确定OFDM-MIMO的整体流程

    properties (Nontunable)
        SamplePerSymbol (1, 1) {mustBeReal, mustBePositive} = 4
    end

    properties

        firstStageModulator
        ostbc
        secondStageModulator
        sampler
        NumDataSubcarriers
        NumSymbols
    end

    methods (Access = protected)

        function y = baseModulator(obj, x)

            x = obj.firstStageModulator(x);
            x = obj.ostbc(x);
            obj.NumSymbols = fix(size(x, 1) / obj.NumDataSubcarriers);
            x = x(1:obj.NumSymbols * obj.NumDataSubcarriers, :);
            x = reshape(x, [obj.NumDataSubcarriers, obj.NumSymbols, obj.NumTransmitAntennnas]);

            obj.secondStageModulator.NumSymbols = obj.NumSymbols;
            x = obj.secondStageModulator(x);
            y = obj.sampler(x);

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

        function sampler = genSampler(obj)

            L = obj.SamplePerSymbol;
            M = 1;
            TW = 0.001;
            AStop = 70;
            h = designMultirateFIR(L, M, TW, AStop);
            sampler = @(x)resample(x, L, M, h);

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

            if p.PilotInputPort
                secondStageModulator.PilotInputPort = p.PilotInputPort;
                secondStageModulator.PilotCarrierIndices = p.PilotCarrierIndices;
            end

            if p.Windowing
                secondStageModulator.Windowing = true;
                secondStageModulator.WindowLength = p.WindowLength;
            end

            ofdmInfo = info(secondStageModulator);
            obj.NumDataSubcarriers = ofdmInfo.DataInputSize(1);
        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)

            obj.ostbc = obj.genOSTBC;
            obj.sampler = obj.genSampler;
            obj.firstStageModulator = obj.genFirstStageModulator;
            obj.secondStageModulator = obj.genSecondStageModulator;

            modulatorHandle = @(x)obj.baseModulator(x);
            obj.IsDigital = true;

        end

    end

end
