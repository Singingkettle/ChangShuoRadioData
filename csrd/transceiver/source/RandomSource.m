classdef RandomSource < BaseSource

    methods

        function obj = RandomSource(param)
            obj.order = param.modulatorConfig.order;
            obj.samplePerSymbol = param.samplePerSymbol;
            obj.timeDuration = param.timeDuration;
            obj.sampleRate = param.sampleRate;
        end

    end

    methods (Access = protected)

        function y = stepImpl(obj)
            y = randi([0, obj.order - 1], ...
                round(obj.samplePerFrame / obj.samplePerSymbol), 1);
        end

    end

end
