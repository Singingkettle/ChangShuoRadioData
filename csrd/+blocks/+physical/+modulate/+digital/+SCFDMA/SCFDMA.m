classdef SCFDMA < blocks.physical.modulate.digital.OFDM.OFDM
    % This class is based on https://www.mathworks.com/help/comm/ug/scfdma-vs-ofdm.html

    properties (Nontunable)
        SubcarrierMappingInterval (1, 1) {mustBeReal, mustBePositive} = 1
    end

    methods (Access = protected)

        function [y, bw] = baseModulator(obj, x)
            x = obj.firstStageModulator(x);
            x = obj.ostbc(x);
            obj.NumSymbols = fix(size(x, 1) / obj.ModulatorConfig.scfdma.NumDataSubcarriers);
            x = x(1:obj.NumSymbols * obj.ModulatorConfig.scfdma.NumDataSubcarriers, :);
            x = reshape(x, [obj.ModulatorConfig.scfdma.NumDataSubcarriers, obj.NumSymbols, obj.NumTransmitAntennas]);
            x = cat(1, x, zeros(obj.ModulatorConfig.scfdma.FFTLength - obj.ModulatorConfig.scfdma.NumDataSubcarriers, obj.NumSymbols, obj.NumTransmitAntennas));
            x = fft(x(1:obj.ModulatorConfig.scfdma.NumDataSubcarriers, :, :), obj.ModulatorConfig.scfdma.NumDataSubcarriers);
            x_ = zeros(obj.ModulatorConfig.scfdma.FFTLength, obj.NumSymbols, obj.NumTransmitAntennas, 'like', x);

            leftGuardBand = floor((obj.ModulatorConfig.scfdma.FFTLength - obj.NumDataSubcarriers) / 2);
            rightGuardBand = obj.ModulatorConfig.scfdma.FFTLength - obj.NumDataSubcarriers - leftGuardBand;
            x_ (leftGuardBand + 1:obj.ModulatorConfig.scfdma.SubcarrierMappingInterval:leftGuardBand + obj.ModulatorConfig.scfdma.NumDataSubcarriers * obj.ModulatorConfig.scfdma.SubcarrierMappingInterval, :, :) = x;

            if isLocked(obj.secondStageModulator)
                release(obj.secondStageModulator);
            end

            obj.secondStageModulator.NumSymbols = obj.NumSymbols;
            y = obj.secondStageModulator(x_);
            bw = zeros(1, 2);
            bw(1) = -obj.ModulatorConfig.scfdma.Subcarrierspacing * (obj.ModulatorConfig.scfdma.FFTLength / 2 - leftGuardBand);
            bw(2) = obj.ModulatorConfig.scfdma.Subcarrierspacing * (obj.ModulatorConfig.scfdma.FFTLength / 2 - rightGuardBand);

        end

        function secondStageModulator = genSecondStageModulator(obj)
            p = obj.ModulatorConfig.scfdma;
            secondStageModulator = comm.OFDMModulator( ...
                FFTLength = p.FFTLength, ...
                NumGuardBandCarriers = [0; 0], ...
                CyclicPrefixLength = p.CyclicPrefixLength, ...
                NumTransmitAntennas = obj.NumTransmitAntennas);

            obj.NumDataSubcarriers = (obj.ModulatorConfig.scfdma.NumDataSubcarriers -1) * obj.ModulatorConfig.scfdma.SubcarrierMappingInterval + 1;
            obj.SampleRate = obj.ModulatorConfig.scfdma.Subcarrierspacing * p.FFTLength;
        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)

            obj.IsDigital = true;

            if obj.NumTransmitAntennas > 2

                if ~isfield(obj.ModulatorConfig, 'ostbcSymbolRate')
                    obj.ModulatorConfig.ostbcSymbolRate = randi([0, 1]) * 0.25 + 0.5;
                end

            end

            obj.ostbc = obj.genOSTBC;

            if ~isfield(obj.ModulatorConfig, 'base')
                obj.ModulatorConfig.base.mode = randsample(["psk", "qam"], 1);

                if strcmpi(obj.ModulatorConfig.base.mode, "psk")
                    obj.ModulatorConfig.base.PhaseOffset = rand(1) * 2 * pi;
                    obj.ModulatorConfig.base.SymbolOrder = randsample(["bin", "gray"], 1);
                end

                obj.ModulatorConfig.scfdma.FFTLength = randsample([128, 256, 512, 1024, 2048], 1);
                obj.ModulatorConfig.scfdma.CyclicPrefixLength = randi([12, 32], 1);
                obj.ModulatorConfig.scfdma.Subcarrierspacing = randsample([2, 4], 1) * 1e2;
                obj.ModulatorConfig.scfdma.SubcarrierMappingInterval = randi([1, 2], 1);
                maxNumDataSubcarriers = fix((obj.ModulatorConfig.scfdma.FFTLength - 1) / obj.ModulatorConfig.scfdma.SubcarrierMappingInterval) + 1;
                % 48 is a number randomly selected
                obj.ModulatorConfig.scfdma.NumDataSubcarriers = randi([48, maxNumDataSubcarriers], 1);
            end

            obj.firstStageModulator = obj.genFirstStageModulator;
            obj.secondStageModulator = obj.genSecondStageModulator;
            modulatorHandle = @(x)obj.baseModulator(x);
        end

    end

end
