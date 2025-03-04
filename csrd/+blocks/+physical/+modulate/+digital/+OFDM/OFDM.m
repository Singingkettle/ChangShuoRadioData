classdef OFDM < blocks.physical.modulate.BaseModulator
    % OFDM - Orthogonal Frequency Division Multiplexing Modulator
    %
    % This class implements OFDM modulation with configurable parameters and
    % support for MIMO transmission.
    %
    % Properties:
    %   firstStageModulator - Primary modulation (PSK/QAM)
    %   ostbc - Orthogonal Space-Time Block Coding
    %   secondStageModulator - OFDM modulation stage
    %   NumDataSubcarriers - Number of data subcarriers
    %   usePilot - Flag for pilot usage
    %   acrossSymbol - Flag for pilot pattern across symbols
    %   pilotModulator - Pilot signal modulator
    %   NumSymbols - Number of OFDM symbols (default: 100)
    %
    % Methods:
    %   genModulatorHandle - Configures modulation parameters
    %   baseModulator - Implements core OFDM modulation
    %   genFirstStageModulator - Creates primary modulation stage
    %   genPilotModulator - Creates pilot modulation
    %   genSecondStageModulator - Creates OFDM modulation stage

    %
    % References:
    % - https://www.mathworks.com/help/5g/ug/resampling-filter-design-in-ofdm-functions.html
    % - Regarding OFDM signal sampling simulation, essentially a conversion process:
    %   https://www.mathworks.com/help/dsp/ug/overview-of-multirate-filters.html
    % - OFDM signal sampling simulation implementation:
    %   https://github.com/wonderfulnx/acousticOFDM/blob/main/Matlab/IQmod.m
    % - OFDM-MIMO overall process based on:
    %   https://www.mathworks.com/help/comm/ug/introduction-to-mimo-systems.html
    % - Detailed explanation of OFDM modulation signal sampling rate and bandwidth:
    %   https://www.mathworks.com/help/comm/ug/ofdm-transmitter-and-receiver.html

    properties
        firstStageModulator
        ostbc
        secondStageModulator
        NumDataSubcarriers
        usePilot
        acrossSymbol
        pilotModulator
        NumSymbols = 100
    end

    methods (Access = protected)

        function [y, bw] = baseModulator(obj, x)

            x = obj.firstStageModulator(x);
            x = obj.ostbc(x);
            obj.NumSymbols = fix(size(x, 1) / obj.NumDataSubcarriers);
            x = x(1:obj.NumSymbols * obj.NumDataSubcarriers, :);
            x = reshape(x, [obj.NumDataSubcarriers, obj.NumSymbols, obj.NumTransmitAntennas]);

            % Ensure the object is released before changing non-tunable properties
            if isLocked(obj.secondStageModulator)
                release(obj.secondStageModulator);
            end

            if obj.NumSymbols > obj.secondStageModulator.NumSymbols
                x = x(:, 1:obj.secondStageModulator.NumSymbols, :);
                obj.NumSymbols = obj.secondStageModulator.NumSymbols;
            else
                obj.secondStageModulator.NumSymbols = obj.NumSymbols;
            end

            if obj.usePilot

                if obj.acrossSymbol
                    obj.secondStageModulator.PilotCarrierIndices = obj.secondStageModulator.PilotCarrierIndices(:, 1:obj.NumSymbols, :);
                end

                px = randi([0, obj.ModulatorConfig.pilot.ModulatorOrder - 1], ...
                    size(obj.secondStageModulator.PilotCarrierIndices, 1), obj.NumSymbols, obj.NumTransmitAntennas);
                px = obj.pilotModulator(px);
                y = obj.secondStageModulator(x, px);
            else
                y = obj.secondStageModulator(x);
            end

            bw = obj.ModulatorConfig.ofdm.FFTLength / 2 - obj.ModulatorConfig.ofdm.NumGuardBandCarriers;
            bw(1) = bw(1) * -1;
            bw = bw .* obj.ModulatorConfig.ofdm.Subcarrierspacing;

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
                NumSymbols = obj.NumSymbols);

            if isfield(p, 'PilotCarrierIndices')
                secondStageModulator.PilotInputPort = true;
                secondStageModulator.PilotCarrierIndices = p.PilotCarrierIndices;
            end

            if p.Windowing
                secondStageModulator.Windowing = true;
                secondStageModulator.WindowLength = p.WindowLength;
            end

            % Without pilot, the UsedSubCarr is equal NumDataSubcarriers
            obj.NumDataSubcarriers = info(secondStageModulator).DataInputSize(1);

            obj.SampleRate = obj.ModulatorConfig.ofdm.Subcarrierspacing * p.FFTLength;
        end

    end

    methods

        function modulatorHandle = genModulatorHandle(obj)
            obj.NumTransmitAntennas = 2;
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

                obj.ModulatorConfig.ofdm.FFTLength = randsample([128, 256, 512, 1024, 2048], 1);
                obj.ModulatorConfig.ofdm.NumGuardBandCarriers = [0; 0];
                obj.ModulatorConfig.ofdm.NumGuardBandCarriers(1) = randi([5, 12], 1);
                obj.ModulatorConfig.ofdm.NumGuardBandCarriers(2) = randi([5, 12], 1);
                obj.ModulatorConfig.ofdm.InsertDCNull = randsample([true, false], 1);
                obj.ModulatorConfig.ofdm.CyclicPrefixLength = randi([12, 32], 1);
                obj.ModulatorConfig.ofdm.Subcarrierspacing = randsample([2, 4], 1) * 1e2;
                obj.usePilot = randsample([true, false], 1);

                if obj.usePilot
                    obj.acrossSymbol = randsample([true, false], 1);
                    obj.ModulatorConfig.pilot.mode = randsample(["psk", "qam"], 1);

                    if strcmpi(obj.ModulatorConfig.pilot.mode, "psk")
                        obj.ModulatorConfig.pilot.PhaseOffset = rand(1) * 2 * pi;
                        obj.ModulatorConfig.pilot.SymbolOrder = randsample(["bin", "gray"], 1);
                    end

                    nPilot = randi([4, 32], 1);
                    validRangeLeft = obj.ModulatorConfig.ofdm.NumGuardBandCarriers(1) + 1:floor(obj.ModulatorConfig.ofdm.FFTLength / 2);
                    validRangeRight = floor(obj.ModulatorConfig.ofdm.FFTLength / 2) + 2:obj.ModulatorConfig.ofdm.FFTLength - obj.ModulatorConfig.ofdm.NumGuardBandCarriers(2);
                    validRange = cat(2, validRangeLeft, validRangeRight);

                    if obj.NumTransmitAntennas > 1
                        % To avoid bugs in multi-antenna scenarios, pilot settings are temporarily not considered
                        % Pilots are different for each symbol, but ensure pilots are different across antennas
                        if floor(length(validRange) / nPilot) < obj.NumTransmitAntennas
                            obj.NumTransmitAntennas = floor(length(validRange) / nPilot);
                        end

                        validRange = shuffleArray(validRange);
                        validRange = sort(validRange(1:nPilot * obj.NumTransmitAntennas));
                        PilotCarrierIndices = reshape(validRange, nPilot, obj.NumTransmitAntennas);
                        obj.acrossSymbol = false;
                    else
                        repeatTimes = 1;

                        if obj.acrossSymbol
                            repeatTimes = repeatTimes * obj.NumSymbols;
                        end

                        PilotCarrierIndices = zeros(repeatTimes, nPilot);
                        valid_num = 0;

                        while valid_num < repeatTimes
                            p = sort(randsample(validRange, nPilot));
                            valid_num = valid_num + 1;
                            PilotCarrierIndices(valid_num, :) = p;
                        end

                        PilotCarrierIndices = PilotCarrierIndices';
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
                obj.pilotModulator = obj.genPilotModulator;
            end

            modulatorHandle = @(x)obj.baseModulator(x);
        end

    end

end

function shuffledArray = shuffleArray(array)
    % Generate random permutation of indices
    randomIndices = randperm(numel(array));
    % Reorder the original array using random indices
    shuffledArray = array(randomIndices);
end
