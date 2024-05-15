classdef DSBAM < DSBSCAM

    methods (Access = protected)

        function [y, bw] = baseModulator(obj, x)
            
            y = x + obj.ModulatorConfig.carramp;
            bw = obw(x, obj.SampleRate)*2;

        end

    end

end
