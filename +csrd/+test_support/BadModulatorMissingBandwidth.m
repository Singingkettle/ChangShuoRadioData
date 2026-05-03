classdef BadModulatorMissingBandwidth < matlab.System
    % BadModulatorMissingBandwidth - Test double for fail-fast factory tests.
    properties
        NumTransmitAntennas = 1
        TargetBandwidth = 1e3
    end

    methods (Access = protected)
        function out = stepImpl(obj, ~)
            out = struct();
            out.Signal = complex(ones(8, obj.NumTransmitAntennas));
            out.SampleRate = 10e3;
            out.NumTransmitAntennas = obj.NumTransmitAntennas;
        end
    end
end
