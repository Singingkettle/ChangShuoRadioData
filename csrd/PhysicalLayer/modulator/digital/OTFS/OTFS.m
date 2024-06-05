classdef OTFS < BaseModulation
    % https://www.mathworks.com/help/comm/ug/otfs-modulation.html#d126e2615
    
    properties (Nontunable)
        Subcarrierspacing (1, 1) {mustBeReal, mustBePositive} = 30e3
        % DelayLength
        DelayLength (1, 1) {mustBeReal, mustBePositive} = 1024
    end
    
    properties
        
        firstStageModulation
        ostbc
        secondStageModulation
        NumSymbols
        
    end
    
    methods (Access = protected)
        
        function [y, bw] = baseModulation(obj, x)
            
            x = obj.firstStageModulation(x);
            x = obj.ostbc(x);
            obj.NumSymbols = fix(size(x, 1) / obj.DelayLength);
            x = x(1:obj.NumSymbols * obj.DelayLength, :);
            x = reshape(x, [obj.DelayLength, obj.NumSymbols, obj.NumTransmitAntennnas]);
            y = obj.secondStageModulation(x);
            M = length(y)/obj.NumSymbols;

            obj.TimeDuration = size(y, 1) / obj.SampleRate;

            bw = obw(y, obj.SampleRate, [], 98.5);
            bw = max(bw);
            scale_val = 2;
            src = dsp.SampleRateConverter( ...
                            Bandwidth=bw, ...
                            InputSampleRate=obj.SampleRate, ...
                            OutputSampleRate=obj.SampleRate*scale_val, ...
                            StopbandAttenuation=50);
            y1 = src(y);
            [delay, ~, ~] = outputDelay(src, Fc=0);
            y1 = circshift(y1, -fix(delay*(obj.SampleRate*scale_val)));
            % Delete the dealy part, the 3 is hand value to ensure the
            % delay part has been removed completely.
            y = y1(1:end-M*scale_val*3, :);
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
            bw = obj.DelayLength * obj.Subcarrierspacing;
            obj.SampleRate = obj.SampleRate*scale_val;
        end
        
     
        function ostbc = genOSTBC(obj)
            
            if obj.NumTransmitAntennnas > 1
                
                if obj.NumTransmitAntennnas == 2
                    ostbc = comm.OSTBCEncoder( ...
                        NumTransmitAntennas = obj.NumTransmitAntennnas);
                else
                    ostbc = comm.OSTBCEncoder( ...
                        NumTransmitAntennas = obj.NumTransmitAntennnas, ...
                        SymbolRate = obj.ModulationConfig.ostbcSymbolRate);
                end
                
            else
                ostbc = @(x)obj.placeHolder(x);
            end
            
        end
        
        function firstStageModulation = genFirstStageModulation(obj)
            
            if contains(lower(obj.ModulationConfig.base.mode), 'psk')
                firstStageModulation = @(x)pskmod(x, ...
                    obj.ModulationOrder, ...
                    obj.ModulationConfig.base.PhaseOffset, ...
                    obj.ModulationConfig.base.SymbolOrder);
            elseif contains(lower(mode), 'qam')
                firstStageModulation = @(x)qammod(x, ...
                    obj.ModulationOrder, ...
                    'UnitAveragePower', true);
            else
                error('Not implemented %s modulator in OFDM', mode);
            end
            
        end
        
        function secondStageModulation = genSecondStageModulation(obj)
            p = obj.ModulationConfig.otfs;
            secondStageModulation = @(x)otfsmod(x, ...
                obj.NumTransmitAntennnas, p.padLen, p.padType);
            obj.SampleRate = obj.DelayLength * obj.Subcarrierspacing;
        end
        
    end
    
    methods
        
        function modulatorHandle = genModulationHandle(obj)
            
            obj.IsDigital = true;
            obj.ostbc = obj.genOSTBC;
            obj.firstStageModulation = obj.genFirstStageModulation;
            obj.secondStageModulation = obj.genSecondStageModulation;
            
            modulatorHandle = @(x)obj.baseModulation(x);
            
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
