classdef ASK < PAM

    methods

        function y = passBand(obj, x)

            t = (0:1 / obj.sampleRate:((size(x, 1) - 1) / obj.sampleRate))';
            t = t(:, ones(1, size(x, 2)));
            y = x .* cos(2 * pi * obj.carrierFrequency * t);

        end

    end

end
