classdef BaseChannel < matlab.System

    properties
        channelConfig
        channel
    end

    methods

        function obj = Rayleigh(param)
            obj.channelConfig = param.channelConfig;
            obj.channel = obj.getChannel;

        end

    end

    methods (Abstract)
        channel = getChannel(obj);
    end

    methods (Access = protected)

        function y = stepImpl(obj, x)
            y = obj.channel(x);
        end

    end

end
