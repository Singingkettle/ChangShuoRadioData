classdef DVBSAPSK < APSK
    % For the modulator parameters of DVBSAPSK, please refer:
    % https://www.mathworks.com/help/comm/ref/dvbsapskmod.html#mw_c8c83d0e-4cb9-4aa7-bf44-92d4e39be3c9
    
    methods (Access = protected)
        
        function [y, bw] = baseModulator(obj, x)
            
            % Modulate
            x = dvbsapskmod(x, obj.ModulatorOrder, ...
                obj.ModulatorConfig.stdSuffix, ...
                obj.ModulatorConfig.codeIDF, ...
                obj.ModulatorConfig.frameLength, ...
                UnitAveragePower = true);
            x = obj.ostbc(x);
            
            % Pulse shape
            y = filter(obj.filterCoeffs, 1, upsample(x, obj.SamplePerSymbol));
            
            bw = obw(y, obj.SampleRate);
            if obj.NumTransmitAntennas > 1
                bw = max(bw);
            end
            
        end
        
    end
    
    methods
        function modulatorHandle = genModulatorHandle(obj)
            % About the valid values for DVABSAPSK the doc in matlab is not
            % consistent with the official code, we use the official code
            % to define the config parameters' range. As a result, there
            % are bugs about codeIDF about doc link: https://www.mathworks.com/help/comm/ref/dvbsapskmod.html
            if ~isfield(obj.ModulatorConfig, "stdSuffix")
                if obj.ModulatorOrder <= 16
                    obj.ModulatorConfig.stdSuffix = randsample(["s2", "s2x", "sh"], 1);
                elseif obj.ModulatorOrder <= 32
                    obj.ModulatorConfig.stdSuffix = randsample(["s2x", "s2"], 1);
                else
                    obj.ModulatorConfig.stdSuffix = "s2x";
                end
                obj.ModulatorConfig.frameLength = randsample(["normal", "short"], 1);
                % obj.ModulatorConfig.stdSuffix = "s2x";
                % obj.ModulatorOrder = 64;
                if strcmpi(obj.ModulatorConfig.stdSuffix, "s2x")
                    if ((obj.ModulatorOrder == 16) || (obj.ModulatorOrder== 32))
                        obj.ModulatorConfig.frameLength = "short";
                    else
                        obj.ModulatorConfig.frameLength = "normal";
                    end
                end
                obj.ModulatorConfig.codeIDF = randomSelectCodeIDF(obj.ModulatorOrder, obj.ModulatorConfig.stdSuffix, obj.ModulatorConfig.frameLength);
                
                obj.ModulatorConfig.beta = rand(1);
                % Product of SPS and SPAN must be even.
                obj.ModulatorConfig.span = randi([2, 8])*2;
            end
            
            obj.IsDigital = true;
            obj.filterCoeffs = obj.genFilterCoeffs;
            obj.ostbc = obj.genOSTBC;
            modulatorHandle = @(x)obj.baseModulator(x);
            
        end
    end
    
end


function y = randomSelectCodeIDF(order, stdSuffix, frameLength)

if strcmpi(stdSuffix,'sh')
    
    validSHCodeIDFList = {'1/5','2/9','1/4','2/7','1/3','2/5','1/2','2/3'};
    
    y =  randsample(validSHCodeIDFList, 1);
    
elseif strcmpi(stdSuffix,'s2')
    
    Midx = order/16;
    % Code Identifiers applicable to DVB-S2 for normal frame-length tag
    % First for 16-APSK and next for 32-APSK
    validS2CodeIDFNList = {{'2/3','3/4','4/5','5/6','8/9','9/10'}; ...
        {'3/4','4/5','5/6','8/9','9/10'}};
    
    % Code Identifiers applicable to DVB-S2 for short frame length tag
    % First for 16-APSK and next for 32-APSK
    validS2CodeIDFSList = {{'2/3','3/4','4/5','5/6','8/9'}; ...
        {'3/4','4/5','5/6','8/9'}};
    
    if strcmpi(frameLength, 'short')
        y =  randsample(validS2CodeIDFSList{Midx}, 1);
    else
        y =  randsample(validS2CodeIDFNList{Midx}, 1);
    end
    
else
    
    Mnidx = log2(double(order))-2;
    isM16or32 = (order == 16) || (order == 32);
    if isM16or32
        Msidx = order/16;
    else
        Msidx = cast(1, 'like', order);
    end
    % Code Identifiers applicable to DVB-S2X for normal frame-length tag
    % For 8-APSK, 16, 32, 64, 128, 256-APSK
    validS2XCodeIDFNList = {{'100/180','104/180'};
        {'2/3','3/4','4/5','5/6','8/9','9/10','90/180','96/180', ...
        '100/180','26/45','3/5','18/30','28/45','23/36','20/30', ...
        '25/36','13/18','140/180','154/180'}; ...
        {'3/4','4/5','5/6','8/9','9/10','2/3','128/180','132/180','140/180'}; ...
        {'128/180','132/180','7/9','4/5','5/6'};{'135/180','140/180'}; ...
        {'116/180','20/30','124/180','128/180','22/30','135/180'}};
    
    % Code Identifiers applicable to DVB-S2X for short frame-length tag
    % For 16 & 32-APSK
    validS2XCodeIDFSList =  {{'2/3','3/4','4/5','5/6','8/9','7/15','8/15','26/45',...
        '3/5','32/45'}; {'3/4','4/5','5/6','8/9','2/3','32/45'}};
    
    if strcmpi(frameLength, 'short')
        y =  randsample(validS2XCodeIDFSList{Msidx}, 1);
    else
        y =  randsample(validS2XCodeIDFNList{Mnidx}, 1);
    end
end

y = y{1};
end