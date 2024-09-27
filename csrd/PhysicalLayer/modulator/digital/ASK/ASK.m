classdef ASK < APSK
    % FILEPATH: ChangShuoRadioData/csrd/modulator/digital/ASK/ASK.m
    %
    % ASK class is a subclass of APSK class and represents an Amplitude Shift Keying (ASK) modulator.
    %
    % Methods:
    %   - baseModulator: Modulates the input signal using ASK modulation scheme.
    %
    % Properties:
    %   - ModulatorOrder: The order of modulation.
    %   - SamplePerSymbol: The number of samples per symbol.
    %   - SampleRate: The sample rate of the modulated signal.
    %   - NumTransmitAntennas: The number of transmit antennas.
    %   - filterCoeffs: The coefficients of the pulse shaping filter.
    %
    % Example usage:
    %   askModulator = ASK();
    %   inputSignal = [0 1 0 1 1];
    %   modulatedSignal = askModulator.baseModulator(inputSignal);
    %
    methods (Access = protected)
        
        function [y, bw] = baseModulator(obj, x)
            
            amp = 1 / sqrt(mean(abs(pammod(0:obj.ModulatorOrder - 1, obj.ModulatorOrder)) .^ 2));
            % Modulate
            x = amp * pammod(x, obj.ModulatorOrder);
            x = obj.ostbc(x);
            
            % Pulse shape
            y = filter(obj.filterCoeffs, 1, upsample(x, obj.SamplePerSymbol));
            
            bw = obw(y, obj.SampleRate)*2;
            if obj.NumTransmitAntennas > 1
                bw = max(bw);
            end
            
        end
        
    end
    
    methods
        
        function modulatorHandle = genModulatorHandle(obj)
            
            if ~isfield(obj.ModulatorConfig, 'beta')
                obj.ModulatorConfig.beta = rand(1);
                obj.ModulatorConfig.span = randi([2, 8])*2;
            end
            if obj.NumTransmitAntennas > 2
                if ~isfield(obj.ModulatorConfig, 'ostbcSymbolRate')
                    obj.ModulatorConfig.ostbcSymbolRate = randi([0, 1])*0.25+0.5;
                end
            end
            obj.IsDigital = true;
            obj.filterCoeffs = obj.genFilterCoeffs;
            obj.ostbc = obj.genOSTBC;
            modulatorHandle = @(x)obj.baseModulator(x);
            
        end
        
    end
    
end
