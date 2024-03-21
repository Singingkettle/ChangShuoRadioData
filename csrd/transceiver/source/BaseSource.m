classdef BaseSource < matlab.System

    properties
        % Below two properties are only used in the digital system
        order
        samplePerSymbol
        timeDuration
        sampleRate
    end

    properties (Dependent)
        samplePerFrame
    end

    methods

        function samplePerFrame = get.samplePerFrame(obj)
            samplePerFrame = obj.timeDuration * obj.sampleRate;
            samplePerFrame = round(samplePerFrame);
        end

    end

    methods (Abstract, Access = protected)

        stepImpl(obj)

    end

end
