classdef TRFMatrixResampleProbe < csrd.blocks.physical.txRadioFront.TRFSimulator
    %TRFMATRIXRESAMPLEPROBE Test-only protected-method probe.

    methods
        function y = exposeResampleToTarget(obj, x, fs)
            y = obj.resampleToTarget(x, fs);
        end
    end
end
