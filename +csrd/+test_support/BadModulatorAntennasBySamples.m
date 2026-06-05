classdef BadModulatorAntennasBySamples < matlab.System
    % BadModulatorAntennasBySamples - Test double returning transposed MIMO signal.
    properties
        NumTransmitAntennas = 2
        TargetBandwidth = 1e3
    end

    methods (Access = protected)
        function out = stepImpl(obj, ~)
            % stepImpl - Return samples-by-antenna contract violation.
            % Inputs: obj plus ignored input payload.
            % Outputs: malformed modulator output struct.
            out = struct();
            out.Signal = complex(ones(obj.NumTransmitAntennas, 8));
            out.Bandwidth = obj.TargetBandwidth;
            out.SampleRate = 10e3;
            out.NumTransmitAntennas = obj.NumTransmitAntennas;
        end
    end
end
