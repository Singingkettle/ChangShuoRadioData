classdef MimoFadingDeterminismTest < matlab.unittest.TestCase
    % MimoFadingDeterminismTest
    %
    % The MIMO fading channel (which backs Rayleigh/Rician/MultiPath) must draw
    % its fading realisation from its own seeded RNG, NOT the process-global
    % stream. Without a Seed routed into comm.MIMOChannel the fading was
    % non-reproducible (drawn from the global RNG), breaking the
    % same-(Tx,Rx,Burst)-same-fading (H13) + cross-worker reproducibility
    % contract for every fading scenario.

    methods (Test)

        function fadingIsSeedDeterministicAndGlobalRngIndependent(testCase)
            sig = testCase.fixedSignal();
            a = testCase.runFading(42, 1, sig);
            b = testCase.runFading(42, 7, sig);   % same seed, perturbed global RNG
            c = testCase.runFading(43, 1, sig);   % different seed

            testCase.verifyEqual(a, b, ...
                'Same-seed fading must be identical regardless of the global RNG state');
            testCase.verifyFalse(isequal(a, c), ...
                'Different seeds must produce different fading');
        end

        function resetRestoresSameFadingAcrossFrames(testCase)
            % H13: the same channel block re-stepped each frame (reset between)
            % must reproduce the same fading realisation.
            sig = testCase.fixedSignal();
            ch = testCase.makeChannel(42);
            x = testCase.makeInput(sig);
            o1 = step(ch, x);
            reset(ch);
            o2 = step(ch, x);
            release(ch);
            testCase.verifyEqual(o1.Signal, o2.Signal, ...
                'reset() must restore the same fading (frame-stable per burst)');
        end

    end

    methods (Access = private)

        function sig = fixedSignal(~)
            s = RandStream('mt19937ar', 'Seed', 123);
            sig = (randn(s, 2000, 1) + 1j * randn(s, 2000, 1)) / sqrt(2);
        end

        function ch = makeChannel(~, seed)
            ch = csrd.blocks.physical.channel.MIMO('FadingDistribution', 'Rayleigh', ...
                'SampleRate', 1e6, 'PathDelays', [0 1e-6], 'AveragePathGains', [0 -3], ...
                'MaximumDopplerShift', 10, 'NumTransmitAntennas', 1, ...
                'NumReceiveAntennas', 1, 'Seed', seed);
        end

        function x = makeInput(~, sig)
            x = struct('Signal', sig, 'SampleRate', 1e6, 'StartTime', 0, ...
                'NumTransmitAntennas', 1);
        end

        function y = runFading(testCase, seed, globalSeed, sig)
            rng(globalSeed);   % perturb the global stream
            ch = testCase.makeChannel(seed);
            out = step(ch, testCase.makeInput(sig));
            y = out.Signal;
            release(ch);
        end

    end
end
