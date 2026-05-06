classdef TRFMatrixResampleContractTest < matlab.unittest.TestCase
    %TRFMATRIXRESAMPLECONTRACTTEST Phase 21 matrix resample contract.

    methods (Test)

        function matrixResampleMatchesPerAntennaReference(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(fullfile(root, 'tests', 'helpers'));

            inputFs = 1.25e6;
            targetFs = 5e6;
            n = (0:255).';
            input = [ ...
                exp(1j * 2 * pi * 100e3 * n / inputFs), ...
                0.5 * exp(1j * 2 * pi * 230e3 * n / inputFs), ...
                complex(randn(numel(n), 1), randn(numel(n), 1))];

            trf = TRFMatrixResampleProbe('TargetSampleRate', targetFs);
            cleanupObj = onCleanup(@() release(trf)); %#ok<NASGU>
            out = trf.exposeResampleToTarget(input, inputFs);

            [p, q] = rat(targetFs / inputFs, 1e-12);
            expected = zeros(size(out));
            for antIdx = 1:size(input, 2)
                expected(:, antIdx) = resample(input(:, antIdx), p, q);
            end

            testCase.verifySize(out, size(expected));
            testCase.verifyEqual(out, expected, 'AbsTol', 1e-10, ...
                ['Matrix resample must preserve the per-antenna numerical ', ...
                 'contract of the former column loop.']);
        end

    end
end
