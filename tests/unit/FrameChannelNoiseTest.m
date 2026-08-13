classdef FrameChannelNoiseTest < matlab.unittest.TestCase
    % FrameChannelNoiseTest - the one-noise-floor-per-frame contract.
    %
    %   applyFrameChannelNoise realizes the channel noise ONCE per receiver
    %   frame, across the whole buffer, from the frame's reference descriptor
    %   (first noise-owing component in construction order). The per-component
    %   slice injection it replaced had two measured defects:
    %     * K overlapping bursts summed K independent realizations, so the
    %       saved frame carried ~K times the noise the SNRdB labels described
    %       (labels optimistic by ~10*log10(K) dB, correlated with the hidden
    %       overlap count);
    %     * samples outside every burst carried NO channel noise, so the
    %       frame's noise floor was a step function of the instantaneous
    %       overlap count -- a directly learnable leak of the GT burst timing.
    %   These cases pin both properties plus the reference choice and the
    %   pass-through.

    methods (Test)

        function noiseFloorIsIndependentOfOverlapCount(testCase)
            % K = 1, 2, 4 fully-overlapping bursts: the realized noise power
            % must equal the reference request every time, never K times it.
            n = 32768; powerW = 0.04;
            clean = complex(zeros(n, 1));
            realized = zeros(1, 3);
            kValues = [1, 2, 4];
            for i = 1:3
                comps = cell(1, kValues(i));
                for k = 1:kValues(i)
                    comps{k} = struct('PendingChannelNoise', struct( ...
                        'PowerW', powerW, 'Seed', 777, 'TargetSnrDb', 10));
                end
                [noisy, info] = csrd.pipeline.signal.applyFrameChannelNoise( ...
                    comps, clean);
                testCase.verifyTrue(info.Applied);
                realized(i) = mean(abs(noisy - clean) .^ 2);
            end
            testCase.verifyEqual(realized, powerW * ones(1, 3), ...
                'RelTol', 0.05, sprintf( ...
                ['Realized noise power must equal the reference request for ', ...
                 'K = 1/2/4 overlapping bursts (got %s W for %.3g W ', ...
                 'requested); K-proportional power is the summed-realizations ', ...
                 'defect.'], mat2str(realized, 3), powerW));
        end

        function gapsCarryTheSameNoiseFloor(testCase)
            % A burst covering only the first quarter of the frame: the noise
            % floor in the GAP (no burst) must equal the floor inside the
            % burst region. Zero-noise gaps are the learnable-timing leak.
            n = 32768; powerW = 0.09;
            clean = [ones(n / 4, 1); zeros(3 * n / 4, 1)];
            comps = {struct('PendingChannelNoise', struct( ...
                'PowerW', powerW, 'Seed', 31, 'TargetSnrDb', 0))};
            [noisy, info] = csrd.pipeline.signal.applyFrameChannelNoise( ...
                comps, complex(clean));
            testCase.verifyTrue(info.Applied);
            noise = noisy - clean;
            inBurst = mean(abs(noise(1:n / 4)) .^ 2);
            inGap = mean(abs(noise(n / 4 + 1:end)) .^ 2);
            testCase.verifyEqual(inGap, inBurst, 'RelTol', 0.05, sprintf( ...
                ['The gap''s noise floor (%.3g W) must equal the burst ', ...
                 'region''s (%.3g W): a floor that steps with burst timing ', ...
                 'leaks the GT.'], inGap, inBurst));
            testCase.verifyEqual(inGap, powerW, 'RelTol', 0.05, ...
                'The whole-frame floor must be the reference request.');
        end

        function referenceIsTheFirstNoiseOwingComponent(testCase)
            % Construction order decides: the first component WITH a
            % descriptor is the reference, deterministically.
            n = 16384;
            noNoise = struct('SomethingElse', 1);
            second = struct('PendingChannelNoise', struct( ...
                'PowerW', 0.25, 'Seed', 5, 'TargetSnrDb', 3));
            third = struct('PendingChannelNoise', struct( ...
                'PowerW', 4.0, 'Seed', 6, 'TargetSnrDb', -7));
            [noisy, info] = csrd.pipeline.signal.applyFrameChannelNoise( ...
                {noNoise, second, third}, complex(zeros(n, 1)));
            testCase.verifyEqual(info.ReferenceComponentIndex, 2, ...
                'The first noise-owing component must be the reference.');
            testCase.verifyEqual(mean(abs(noisy) .^ 2), 0.25, 'RelTol', 0.05, ...
                'The realization must be sized by the REFERENCE descriptor.');
            testCase.verifyEqual(info.TargetSnrDb, 3, ...
                'The reference descriptor''s target rides along in info.');
        end

        function framesWithoutNoiseOwingComponentsPassThrough(testCase)
            x = complex(randn(512, 1), randn(512, 1));
            [noisy, info] = csrd.pipeline.signal.applyFrameChannelNoise( ...
                {struct('NoDescriptorHere', true)}, x);
            testCase.verifyEqual(noisy, x, ...
                'A frame owing no channel noise must pass through unchanged.');
            testCase.verifyFalse(info.Applied);
            testCase.verifyTrue(isnan(info.ReferenceComponentIndex));
        end

    end

end
