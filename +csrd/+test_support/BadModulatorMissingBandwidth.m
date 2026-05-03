classdef BadModulatorMissingBandwidth < matlab.System
    % BadModulatorMissingBandwidth - Test double for fail-fast factory tests.
    % 中文说明：用于验证调制器缺少带宽输出时工厂必须 fail-fast 的测试替身。
    properties
        NumTransmitAntennas = 1
        TargetBandwidth = 1e3
    end

    methods (Access = protected)
        function out = stepImpl(obj, ~)
            % stepImpl - Return a modulator output intentionally missing bandwidth.
            % 中文说明：返回故意缺少带宽字段的调制器输出。
            % Inputs / 输入: obj is the test double; message input is ignored.
            % Outputs / 输出: out is a signal struct missing Bandwidth metadata.
            out = struct();
            out.Signal = complex(ones(8, obj.NumTransmitAntennas));
            out.SampleRate = 10e3;
            out.NumTransmitAntennas = obj.NumTransmitAntennas;
        end
    end
end
