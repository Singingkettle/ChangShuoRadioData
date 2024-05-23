classdef ASK < APSK
    % FILEPATH: /e:/Projects/ChangShuoRadioData/csrd/modulator/digital/ASK/ASK.m
    %
    % ASK class is a subclass of APSK class and represents an Amplitude Shift Keying (ASK) modulator.
    %
    % Methods:
    %   - baseModulator: Modulates the input signal using ASK modulation scheme.
    %
    % Properties:
    %   - ModulationOrder: The order of modulation.
    %   - SamplePerSymbol: The number of samples per symbol.
    %   - SampleRate: The sample rate of the modulated signal.
    %   - NumTransmitAntennnas: The number of transmit antennas.
    %   - filterCoeffs: The coefficients of the pulse shaping filter.
    %
    % Example usage:
    %   askModulator = ASK();
    %   inputSignal = [0 1 0 1 1];
    %   modulatedSignal = askModulator.baseModulator(inputSignal);
    %
    methods (Access = protected)
        
        function [y, bw] = baseModulator(obj, x)
            
            amp = 1 / sqrt(mean(abs(pammod(0:obj.ModulationOrder - 1, obj.ModulationOrder)) .^ 2));
            % Modulate
            x = amp * pammod(x, obj.ModulationOrder);
            x = obj.ostbc(x);
            
            % Pulse shape
            y = filter(obj.filterCoeffs, 1, upsample(x, obj.SamplePerSymbol));
            
            bw = obw(y, obj.SampleRate)*2;
            if obj.NumTransmitAntennnas > 1
                bw = max(bw);
            end
            
        end
        
    end
    
end
