classdef RealizeChannelNoiseTest < matlab.unittest.TestCase
    % RealizeChannelNoiseTest - the pipeline's only noise injection point.
    %
    %   csrd.pipeline.signal.realizeChannelNoise decides the realized SNR of every
    %   saved frame. Until it was extracted it lived as a local function inside a
    %   private method file, so nothing could call it and its behaviour was only
    %   ever observed through end-to-end statistics -- which cannot tell a seeding
    %   bug from a power-accounting bug, because both show up as "the SNR
    %   distribution looks a bit off".
    %
    %   The requirement asserted here is the one that used to be asserted on
    %   AWGNChannel's output before the measurement moved ahead of injection: the
    %   noise a link owes is realized at the power it was sized for, deterministically
    %   per frame and independently across frames.

    methods (Test)

        function realizedPowerMatchesTheRequestedPower(testCase)
            % The load-bearing assertion. If this drifts, every SNRdB label in the
            % dataset is wrong by the same factor, and nothing else would notice
            % because the label is computed from the PLANNED power while the
            % waveform carries the REALIZED one.
            n = 200000;
            clean = complex(zeros(n, 1));
            for powerW = [1e-6, 1e-3, 1, 25]
                pending = struct('PowerW', powerW, 'Seed', 4242, 'TargetSnrDb', 10);
                [noisy, info] = csrd.pipeline.signal.realizeChannelNoise(pending, clean);
                realized = mean(abs(noisy) .^ 2);
                testCase.verifyTrue(info.Applied, 'Noise must have been applied.');
                testCase.verifyEqual(realized, powerW, 'RelTol', 0.02, sprintf( ...
                    ['Requested %.6g W of noise but realized %.6g W. PowerW is the ', ...
                     'total complex noise power, so each of the real and imaginary ', ...
                     'parts must carry PowerW/2 -- a factor-of-2 error here shifts ', ...
                     'every SNR label by 3 dB.'], powerW, realized));
                testCase.verifyEqual(info.RealizedPowerW, realized, 'RelTol', 1e-9, ...
                    'info.RealizedPowerW must report what was actually drawn.');
            end
        end

        function sameSeedReproducesTheIdenticalRealization(testCase)
            clean = complex(zeros(4096, 1));
            pending = struct('PowerW', 0.5, 'Seed', 991, 'TargetSnrDb', 3);
            a = csrd.pipeline.signal.realizeChannelNoise(pending, clean);
            b = csrd.pipeline.signal.realizeChannelNoise(pending, clean);
            testCase.verifyEqual(a, b, ...
                'One descriptor must realize one sequence, byte for byte.');
        end

        function differentSeedsGiveIndependentRealizations(testCase)
            clean = complex(zeros(65536, 1));
            a = csrd.pipeline.signal.realizeChannelNoise( ...
                struct('PowerW', 1, 'Seed', 1), clean);
            b = csrd.pipeline.signal.realizeChannelNoise( ...
                struct('PowerW', 1, 'Seed', 2), clean);
            testCase.verifyFalse(isequal(a, b), ...
                'Different seeds must give different noise.');
            % Independent, not merely different: a shifted or sign-flipped copy of
            % the same sequence would pass an inequality test while still giving
            % every frame the same memorable fingerprint.
            c = abs(corr(real(a), real(b)));
            testCase.verifyLessThan(c, 0.05, sprintf( ...
                ['Realizations from different seeds correlate at %.4f. They must be ', ...
                 'independent draws, not transformations of one sequence.'], c));
        end

        function doesNotDisturbTheGlobalRandomStream(testCase)
            % A dedicated RandStream is used on purpose: drawing from the global
            % stream would make the dataset depend on how many random numbers every
            % earlier stage happened to consume, so a change anywhere upstream would
            % silently change the noise everywhere.
            clean = complex(zeros(1024, 1));
            rng(12345);
            before = rand();
            rng(12345);
            csrd.pipeline.signal.realizeChannelNoise( ...
                struct('PowerW', 1, 'Seed', 7), clean);
            after = rand();
            testCase.verifyEqual(after, before, 'AbsTol', 0, ...
                ['realizeChannelNoise must not consume the global stream, or the ', ...
                 'noise becomes a function of unrelated upstream call counts.']);
        end

        function noiseAddsToTheSignalRatherThanReplacingIt(testCase)
            clean = complex(ones(8192, 1), 2 * ones(8192, 1));
            pending = struct('PowerW', 1e-4, 'Seed', 55);
            noisy = csrd.pipeline.signal.realizeChannelNoise(pending, clean);
            testCase.verifyEqual(mean(noisy), mean(clean), 'AbsTol', 5e-3, ...
                'The signal must survive: noise is additive and zero-mean.');
            testCase.verifyEqual(size(noisy), size(clean), ...
                'Shape must be preserved, including the antenna axis.');
        end

        function multiColumnBuffersAreNoisedPerColumn(testCase)
            clean = complex(zeros(16384, 3));
            pending = struct('PowerW', 4, 'Seed', 808);
            noisy = csrd.pipeline.signal.realizeChannelNoise(pending, clean);
            testCase.verifyEqual(size(noisy), size(clean));
            colPowers = mean(abs(noisy) .^ 2, 1);
            for k = 1:numel(colPowers)
                testCase.verifyEqual(colPowers(k), 4, 'RelTol', 0.05, sprintf( ...
                    'Column %d realized %.4g W, expected the requested 4 W.', ...
                    k, colPowers(k)));
            end
            testCase.verifyFalse(isequal(noisy(:, 1), noisy(:, 2)), ...
                'Columns must carry independent noise, not a replicated column.');
        end

        function malformedDescriptorPassesThroughAndSaysWhy(testCase)
            % A link that owes no noise is a real case, not a defect -- a
            % distance-based SNR that resolved to nothing finite, for instance. It
            % must be reported rather than being indistinguishable from a noise
            % power that happened to be tiny.
            clean = complex(ones(256, 1));
            cases = { ...
                [],                                        'no descriptor'; ...
                struct('Seed', 1),                         'PowerW'; ...
                struct('PowerW', 0, 'Seed', 1),            'PowerW'; ...
                struct('PowerW', -1, 'Seed', 1),           'PowerW'; ...
                struct('PowerW', NaN, 'Seed', 1),          'PowerW'; ...
                struct('PowerW', 1),                       'Seed'; ...
                struct('PowerW', 1, 'Seed', NaN),          'Seed'};
            for k = 1:size(cases, 1)
                [noisy, info] = csrd.pipeline.signal.realizeChannelNoise( ...
                    cases{k, 1}, clean);
                testCase.verifyEqual(noisy, clean, sprintf( ...
                    'Case %d must pass the signal through unchanged.', k));
                testCase.verifyFalse(info.Applied, sprintf( ...
                    'Case %d must report Applied = false.', k));
                testCase.verifyTrue(contains(info.Reason, cases{k, 2}), sprintf( ...
                    'Case %d reason "%s" must name the missing field (%s).', ...
                    k, info.Reason, cases{k, 2}));
                testCase.verifyEqual(info.NoisePowerW, 0, sprintf( ...
                    'Case %d must report zero noise power.', k));
            end
        end

        function targetSnrIsCarriedThroughForAuditing(testCase)
            clean = complex(zeros(1024, 1));
            [~, info] = csrd.pipeline.signal.realizeChannelNoise( ...
                struct('PowerW', 1, 'Seed', 3, 'TargetSnrDb', -7.25), clean);
            testCase.verifyEqual(info.TargetSnrDb, -7.25, 'AbsTol', 1e-12, ...
                'The target SNR must survive so a realized value can be audited against it.');
            [~, infoNoTarget] = csrd.pipeline.signal.realizeChannelNoise( ...
                struct('PowerW', 1, 'Seed', 3), clean);
            testCase.verifyTrue(isnan(infoNoTarget.TargetSnrDb), ...
                'An absent target must read NaN, not a silently invented default.');
        end

    end

end
