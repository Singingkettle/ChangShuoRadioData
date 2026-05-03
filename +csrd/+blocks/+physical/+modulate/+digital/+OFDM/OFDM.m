classdef OFDM < csrd.blocks.physical.modulate.BaseModulator
    % OFDM - Orthogonal Frequency Division Multiplexing Modulator
    % 中文说明：提供 CSRD 生产链路中的 OFDM 实现。
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
    % References / 参考资料:
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
            % baseModulator - Production declaration in CSRD.
            % 中文说明：baseModulator 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.

            x = obj.firstStageModulator(x);

            % Resolve the spatial abstraction before shaping the OFDM grid.
            % 中文说明：先明确多天线抽象，再整理 OFDM 资源栅格，避免隐式把多流当 OSTBC。
            spatialMode = obj.resolveSpatialMode();
            switch spatialMode
                case 'OSTBC'
                    obj.ostbc = obj.genOSTBC;
                    x = obj.ostbc(x);
                    if obj.NumTransmitAntennas == 1
                        x = x(:);
                    end
                case 'SpatialMultiplexing'
                    x = obj.reshapeSpatialMultiplexingStreams(x);
                otherwise
                    error('CSRD:Modulation:InvalidOFDMMimoMode', ...
                        'Unsupported OFDM spatial mode: %s.', spatialMode);
            end
            obj.NumSymbols = fix(size(x, 1) / obj.NumDataSubcarriers);
            if obj.NumSymbols < 1
                error('CSRD:Modulation:OFDMInsufficientPayload', ...
                    ['OFDM payload has %d symbols per stream, but at least ', ...
                     '%d data subcarriers are required.'], ...
                    size(x, 1), obj.NumDataSubcarriers);
            end
            x = x(1:obj.NumSymbols * obj.NumDataSubcarriers, :);
            x = reshape(x, [obj.NumDataSubcarriers, obj.NumSymbols, obj.NumTransmitAntennas]);

            if isempty(obj.secondStageModulator) || ...
                    obj.secondStageModulator.NumTransmitAntennas ~= obj.NumTransmitAntennas
                if ~isempty(obj.secondStageModulator) && ...
                        isLocked(obj.secondStageModulator)
                    release(obj.secondStageModulator);
                end
                obj.secondStageModulator = obj.genSecondStageModulator;
            end

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
            % genFirstStageModulator - Production declaration in CSRD.
            % 中文说明：genFirstStageModulator 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.

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
            % genPilotModulator - Production declaration in CSRD.
            % 中文说明：genPilotModulator 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.

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
            % genSecondStageModulator - Production declaration in CSRD.
            % 中文说明：genSecondStageModulator 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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
            % genModulatorHandle - Production declaration in CSRD.
            % 中文说明：genModulatorHandle 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
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
                        % Keep the configured hardware antenna count stable; reduce the
                        % per-antenna pilot count when the random pilot request is too large.
                        % 保持配置的硬件天线数量不变；随机 pilot 数过大时缩减每根天线的 pilot 数。
                        maxPilotsPerAntenna = floor(length(validRange) / obj.NumTransmitAntennas);
                        if maxPilotsPerAntenna < 1
                            error('CSRD:Modulation:OFDMInsufficientPilotCarriers', ...
                                ['OFDM valid pilot carrier range cannot support %d ', ...
                                 'transmit antennas.'], obj.NumTransmitAntennas);
                        end
                        nPilot = min(nPilot, maxPilotsPerAntenna);

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

        function mode = resolveSpatialMode(obj)
            % resolveSpatialMode - Return the explicit OFDM multi-antenna mode.
            % 中文说明：返回显式 OFDM 多天线模式；单天线等价为 OSTBC 直通。
            % Inputs / 输入: object ModulatorConfig.mimo.Mode.
            % 输出 / Outputs: 'OSTBC' or 'SpatialMultiplexing'.
            mode = 'OSTBC';
            if isfield(obj.ModulatorConfig, 'mimo') && ...
                    isstruct(obj.ModulatorConfig.mimo) && ...
                    isfield(obj.ModulatorConfig.mimo, 'Mode') && ...
                    ~isempty(obj.ModulatorConfig.mimo.Mode)
                mode = char(string(obj.ModulatorConfig.mimo.Mode));
            end
            allowed = {'OSTBC', 'SpatialMultiplexing'};
            idx = find(strcmpi(mode, allowed), 1, 'first');
            if isempty(idx)
                error('CSRD:Modulation:InvalidOFDMMimoMode', ...
                    'OFDM ModulatorConfig.mimo.Mode must be one of {%s}; got %s.', ...
                    strjoin(allowed, ', '), mode);
            end
            mode = allowed{idx};
            obj.ModulatorConfig.mimo.Mode = mode;
        end

        function streams = reshapeSpatialMultiplexingStreams(obj, symbols)
            % reshapeSpatialMultiplexingStreams - Split symbols into antenna streams.
            % 中文说明：把调制符号按列分配到发射流，直接匹配 comm.OFDMModulator 的第三维。
            % Inputs / 输入: column/vector of first-stage constellation symbols.
            % 输出 / Outputs: [symbolsPerStream x NumTransmitAntennas] stream matrix.
            symbols = symbols(:);
            nTx = obj.NumTransmitAntennas;
            usable = floor(numel(symbols) / nTx) * nTx;
            if usable < nTx
                error('CSRD:Modulation:OFDMMimoPayloadTooShort', ...
                    'SpatialMultiplexing needs at least one symbol per %d transmit streams.', nTx);
            end
            streams = reshape(symbols(1:usable), nTx, []).';
        end

    end

end

function shuffledArray = shuffleArray(array)
    % Generate random permutation of indices
    % 中文说明：shuffleArray 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    randomIndices = randperm(numel(array));
    % Reorder the original array using random indices
    shuffledArray = array(randomIndices);
end
