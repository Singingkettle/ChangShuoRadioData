classdef OFDM < BaseModulator
    % https://www.mathworks.com/help/5g/ug/resampling-filter-design-in-ofdm-functions.html
    % https://www.mathworks.com/help/dsp/ug/overview-of-multirate-filters.html  关于如何实现对OFDM信号采样的仿真，本质上是一个转换
    % https://github.com/wonderfulnx/acousticOFDM/blob/main/Matlab/IQmod.m      关于如何实现对OFDM信号采样的仿真
    % https://www.mathworks.com/help/comm/ug/introduction-to-mimo-systems.html 基于这个例子确定OFDM-MIMO的整体流程
    properties
        sampler
        firstStageModulator
        ostbc
        secondStageModulator
        numDatas
    end

    methods

        function sampler = getSampler(obj)

            L = obj.samplePerSymbol;
            M = 1;
            TW = 0.001;
            AStop = 70;
            h = designMultirateFIR(L, M, TW, AStop);
            sampler = @(x)resample(x, L, M, h);

        end

        function firstStageModulator = getFirstStageModulator(obj)

            if contains(lower(obj.modulatorConfig.mode), 'psk')
                firstStageModulator = @(x)pskmod(x, ...
                    obj.modulatorConfig.order);
            elseif contains(lower(mode), 'qam')
                firstStageModulator = @(x)qammod(x, ...
                    obj.modulatorConfig.order, ...
                    'UnitAveragePower', true);
            else
                error('Not implemented %s modulator in OFDM', mode);
            end

        end

        function secondStageModulator = getSecondStageModulator(obj)
            p = obj.modulatorConfig.ofdm;

            secondStageModulator = comm.OFDMModulator( ...
                FFTLength = p.fftLength, ...
                NumGuardBandCarriers = p.numGuardBandCarriers, ...
                InsertDCNull = p.insertDCNull, ...
                CyclicPrefixLength = p.cyclicPrefixLength, ...
                OversamplingFactor = p.oversamplingFactor, ...
                NumTransmitAntennas = p.numTransmitAntennnas);

            if p.pilotInputPort
                secondStageModulator.PilotInputPort = p.pilotInputPort;
                secondStageModulator.PilotCarrierIndices = p.pilotCarrierIndices;
            end

            if p.windowing
                secondStageModulator.Windowing = true;
                secondStageModulator.WindowLength = p.windowLength;
            end

            ofdmInfo = info(secondStageModulator);
            obj.numDatas = ofdmInfo.DataInputSize(1);
        end

        function modulator = getModulator(obj)

            if obj.numTransmitAntennnas > 1

                if obj.numTransmitAntennnas == 2
                    obj.ostbc = comm.OSTBCEncoder( ...
                        NumTransmitAntennas = obj.numTransmitAntennnas);
                else
                    obj.ostbc = comm.OSTBCEncoder( ...
                        NumTransmitAntennas = obj.numTransmitAntennnas, ...
                        SymbolRate = obj.modulatorConfig.ostbcSymbolRate);
                end

            else
                obj.ostbc = @(x)obj.placeHolder(x);
            end

            obj.sampler = obj.getSampler;
            obj.firstStageModulator = obj.getFirstStageModulator;
            obj.secondStageModulator = obj.getSecondStageModulator;

            modulator = @(x)baseOFDMModulator(x, ...
                obj.numDatas, ...
                obj.numTransmitAntennnas, ...
                obj.firstStageModulator, ...
                obj.secondStageModulator, ...
                obj.sampler);
            obj.isDigital = true;

        end

        function bw = bandWidth(obj, x)

            bw = obw(x, obj.sampleRate);

        end

        function y = passBand(obj, x)
            y = real(x .* obj.carrierWave);
        end

    end

end

function y = baseOFDMModulator(x, nd, nt, m1, m2, s)

    x = m1(x);
    x = ostbc(x);
    ns = fix(size(x, 1) / nd);
    x = x(1:ns * nd, :);
    x = reshape(x, [ns, nd, nt]);

    m2.NumSymbols = ns;
    x = m2(x);
    y = s(x);

end
