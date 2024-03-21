classdef OFDM < BaseModulator
    % https://www.mathworks.com/help/5g/ug/resampling-filter-design-in-ofdm-functions.html
    % https://www.mathworks.com/help/dsp/ug/overview-of-multirate-filters.html
    properties
        sampler
        firstStageModulator
        secondStageModulator
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
                InsertDCNull = p.InsertDCNull, ...
                PilotInputPort = p.pilotInputPort, ...
                PilotCarrierIndices = p.pilotCarrierIndices, ...
                CyclicPrefixLength = p.cyclicPrefixLength, ...
                Windowing = p.windowing, ...
                WindowLength = p.windowLength, ...
                OversamplingFactor = p.oversamplingFactor, ...
                NumSymbols = p.numSymbols, ...
                NumTransmitAntennas = p.numTransmitAntennnas);
        end

        function modulator = getModulator(obj)
           obj.sampler = obj.getSampler;
           obj.firstStageModulator = obj.getFirstStageModulator;
           obj.secondStageModulator = obj.getSecondStageModulator;

           modulator = @(x)baseOFDMModulator(x, ...
               obj.firstStageModulator, ...
               obj.secondStageModulator, ...
               obj.sampler);

        end
        
        
        function bw = bandWidth(obj, x)

            bw = obw(x, obj.sampleRate);

        end

        function y = passBand(obj, x)
            y = real(x .* obj.carrierWave);
        end

    end

end


function y = baseOFDMModulator(x, m1, m2, s)

x = m1(x);
x = m2(x);
y = s(x);

end
