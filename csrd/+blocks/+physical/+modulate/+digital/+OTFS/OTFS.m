classdef OTFS < blocks.physical.modulate.BaseModulator
    % https://www.mathworks.com/help/comm/ug/otfs-modulation.html#d126e2615

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
            obj.NumSymbols = fix(size(x, 1) / obj.ModulatorConfig.otfs.DelayLength);
            x = x(1:obj.NumSymbols * obj.ModulatorConfig.otfs.DelayLength, :);
            x = reshape(x, [obj.ModulatorConfig.otfs.DelayLength, obj.NumSymbols, obj.NumTransmitAntennas]);
            y = obj.secondStageModulator(x);

            % bw = obw(y, obj.SampleRate, [], 98.5);
            % bw = max(bw);
            % scale_val = 1.5;
            % src = dsp.SampleRateConverter( ...
            %     Bandwidth=bw, ...
            %     InputSampleRate=obj.SampleRate, ...
            %     OutputSampleRate=obj.SampleRate*scale_val, ...
            %     StopbandAttenuation=50);
            % y1 = src(y);
            % [delay, ~, ~] = outputDelay(src, Fc=0);
            % y1 = circshift(y1, -fix(delay*(obj.SampleRate*scale_val)));
            % % Delete the dealy part, the 3 is hand value to ensure the
            % % delay part has been removed completely.
            % y = y1(1:end-obj.ModulatorConfig.otfs.DelayLength*scale_val*3, :);
            % src = dsp.FIRRateConverter(2,1);
            % [SRCoutMag,SRCFreq] = freqzmr(src);
            % plot(SRCFreq/1e3,db(SRCoutMag));
            %

            % [delay,FsOut] = outputDelay(src,FsIn=obj.SampleRate);
            % tx = (0:length(y)-1)./obj.SampleRate;
            % ty = (0:length(y1)-1)./(FsOut);
            % ty = ty-delay;
            % y = y1(ty>=0&ty<=tx(end));
            % ty = ty(ty>=0&ty<=tx(end));
            % signalAnalyzer(y, 'SampleRate', obj.SampleRate, 'StartTime', 0);
            % signalAnalyzer(y1, 'SampleRate', obj.SampleRate*scale_val, 'StartTime', -delay);
            % signalAnalyzer(y2, 'SampleRate', obj.SampleRate*scale_val, 'StartTime', ty(1));
            % 这里面计算带宽的数字8是一个经验值，只是为了保证进入发射机后，进行采样速率转换的时候不报警告信息
            % 这个警告信息是由于带宽和采样速率太接近导致的
            bw = (obj.ModulatorConfig.otfs.DelayLength - 8) * obj.ModulatorConfig.otfs.Subcarrierspacing;
            % obj.SampleRate = obj.SampleRate*scale_val;
        end

        function firstStageModulator = genFirstStageModulator(obj)

            if contains(lower(obj.ModulatorConfig.base.mode), 'psk')
                firstStageModulator = @(x)pskmod(x, ...
                    obj.ModulatorOrder, ...
                    obj.ModulatorConfig.base.PhaseOffset, ...
                    obj.ModulatorConfig.base.SymbolOrder);
            elseif contains(lower(obj.ModulatorConfig.base.mode), 'qam')
                firstStageModulator = @(x)qammod(x, ...
                    obj.ModulatorOrder, ...
                    'UnitAveragePower', true);
            else
                error('Not implemented %s modulator in OFDM', mode);
            end

        end

        function secondStageModulator = genSecondStageModulator(obj)
            p = obj.ModulatorConfig.otfs;
            secondStageModulator = @(x)otfsmod(x, ...
                obj.NumTransmitAntennas, p.padLen, p.padType);
            obj.SampleRate = obj.ModulatorConfig.otfs.DelayLength * obj.ModulatorConfig.otfs.Subcarrierspacing;
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

            if ~isfield(obj.ModulatorConfig, "base")
                obj.ModulatorConfig.base.mode = randsample(["psk", "qam"], 1);

                if strcmpi(obj.ModulatorConfig.base.mode, "psk")
                    obj.ModulatorConfig.base.PhaseOffset = rand(1) * 2 * pi;
                    obj.ModulatorConfig.base.SymbolOrder = randsample(["bin", "gray"], 1);
                end

                obj.ModulatorConfig.otfs.padType = randsample(["CP", "ZP", "RZP", "RCP", "NONE"], 1);
                obj.ModulatorConfig.otfs.padLen = randi([12, 32], 1);
                obj.ModulatorConfig.otfs.DelayLength = randsample([128, 256, 512, 1024, 2048], 1);
                obj.ModulatorConfig.otfs.Subcarrierspacing = randsample([2, 4], 1) * 1e2;
            end

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
