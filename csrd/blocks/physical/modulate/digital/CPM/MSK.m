classdef MSK < FSK
    
    methods (Access = protected)
        
        function [y, bw] = baseModulator(obj, x)
            [sigLen, nChan] = size(x);
            if ~strcmpi(obj.ModulatorConfig.DataEncode, 'diff') && mod(sigLen,2) ~= 0
                x = [x; zeros(1, nChan,'like', x)];
            end
            y = obj.pureModulator(x);
            bw = obw(y, obj.SampleRate);
        end
    end
    
    methods
        
        function modulatorHandle = genModulatorHandle(obj)
            
            obj.IsDigital = true;
            obj.NumTransmitAntennas = 1;
            if ~isfield(obj.ModulatorConfig, 'DataEncode')
                obj.ModulatorConfig.DataEncode = randsample(["diff", "nondiff"], 1);
                obj.ModulatorConfig.InitPhase = randi([0, 3])*pi/2;
            end
            obj.pureModulator = @(x)mskmod(x, ...
                obj.SamplePerSymbol, ...
                obj.ModulatorConfig.DataEncode, ...
                obj.ModulatorConfig.InitPhase);
            modulatorHandle = @(x)obj.baseModulator(x);
            
        end
        
    end
    
end
