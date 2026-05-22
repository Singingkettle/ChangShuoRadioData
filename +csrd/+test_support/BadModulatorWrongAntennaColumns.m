classdef BadModulatorWrongAntennaColumns < matlab.System
    % BadModulatorWrongAntennaColumns - Test double for antenna-shape fail-fast.
    properties
        NumTransmitAntennas = 2
        TargetBandwidth = 1e3
    end

    methods (Access = protected)
        function out = stepImpl(obj, ~)
            % stepImpl - Return a signal with the wrong antenna column count.
            % Inputs: obj plus ignored input payload.
            % Outputs: malformed modulator output struct.
            out = struct();
            out.Signal = complex(ones(8, obj.NumTransmitAntennas + 1));
            out.Bandwidth = obj.TargetBandwidth;
            out.SampleRate = 10e3;
            out.NumTransmitAntennas = obj.NumTransmitAntennas;
        end
    end
end
