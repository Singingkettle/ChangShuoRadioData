classdef OTFS < BaseModulator
    % https://www.mathworks.com/help/comm/ug/otfs-modulation.html#d126e2615

    properties (Nontunable)
        Subcarrierspacing (1, 1) {mustBeReal, mustBePositive} = 30e3
        % Transmit parameters
        NumTransmitAntennnas = 1
        % DelayLength
        DelayLength (1, 1) {mustBeReal, mustBePositive} = 1024
    end

    properties

        firstStageModulator
        ostbc
        secondStageModulator
        NumSymbols

    end

    methods (Access = protected)

        function [y, bw] = baseModulator(obj, x)

            x = obj.firstStageModulator(x);
            x = obj.ostbc(x);
            obj.NumSymbols = fix(size(x, 1) / obj.DelayLength);
            x = x(1:obj.NumSymbols * obj.DelayLength, :);
            x = reshape(x, [obj.DelayLength, obj.NumSymbols]);

            y = obj.secondStageModulator(x);
            bw = obj.DelayLength * obj.Subcarrierspacing;
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
            p = obj.ModulatorConfig.otfs;
            secondStageModulator = @(x)otfsmod(x, ...
                obj.NumTransmitAntennnas, p.padLen, p.padType);
            obj.SampleRate = obj.DelayLength * obj.Subcarrierspacing;
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


function [y, isfftout] = otfsmod(x, numTx, padlen, varargin)

    M = size(x, 1);

    if isempty(varargin)
        padtype = 'CP';
    else
        padtype = varargin{1};
    end

    % Inverse Zak transform
    y = pagetranspose(ifft(pagetranspose(x))) / M;

    % ISFFT to produce the TF grid output
    isfftout = fft(y);

    % Add cyclic prefix/zero padding according to padtype
    switch padtype
        case 'CP'
            % % CP before each OTFS column (like OFDM) then serialize
            y = [y(end - padlen + 1:end, :, 1:numTx); y]; % cyclic prefix
            y = reshape(y, [], numTx); % serialize
        case 'ZP'
            % Zeros after each OTFS column then serialize
            N = size(x, 2);
            y = [y; zeros(padlen, N, numTx)]; % zero padding
            y = reshape(y, [], numTx); % serialize
        case 'RZP'
            % Serialize then append OTFS symbol with zeros
            y = reshape(y, [], numTx); % serialize
            y = [y; zeros(padlen, numTx)]; % zero padding
        case 'RCP'
            % Reduced CP
            % Serialize then prepend cyclic prefix
            y = reshape(y, [], numTx); % serialize
            y = [y(end - padlen + 1:end, 1:numTx); y]; % cyclic prefix
        case 'NONE'
            y = reshape(y, [], numTx); % no CP/ZP
        otherwise
            error('Invalid pad type');
    end

end
