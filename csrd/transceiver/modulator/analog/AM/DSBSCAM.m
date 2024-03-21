classdef DSBSCAM < DSBAM

    methods

        function modulator = getModulator(obj)
            modulator = @(x)obj.placeHolder(x);
            obj.isDigital = false;
        end

    end

end
