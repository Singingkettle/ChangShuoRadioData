% DSBAM is a class that extends DSBSCAM. It represents a Double Sideband Amplitude Modulation.
classdef DSBAM < DSBSCAM
   
    methods (Access = protected)
        
        % baseModulator is a method that performs the base modulation.
        % It takes two inputs: the object instance 'obj' and the input signal 'x'.
        % It returns two outputs: the modulated signal 'y' and the bandwidth 'bw'.
        function [y, bw] = baseModulator(obj, x)
            
            % The modulated signal 'y' is calculated by adding the carrier amplitude to the input signal.
            y = x + obj.ModulatorConfig.carramp;
            
            % The bandwidth 'bw' is calculated by doubling the occupied bandwidth of the input signal.
            bw = obw(x, obj.SampleRate)*2;
            
        end
        
    end
    
end