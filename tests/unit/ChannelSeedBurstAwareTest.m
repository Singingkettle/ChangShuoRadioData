classdef ChannelSeedBurstAwareTest < matlab.unittest.TestCase
    % ChannelSeedBurstAwareTest
    %
    % Phase 1 / H13 regression: ChannelFactory.deriveChannelSeed must
    % produce a burst-aware deterministic seed.
    %
    % Required behaviour (see docs/audits/phases/phase-1-dataflow.md §3.4):
    %   1. Same (txId, rxId, BurstId) triple => same seed regardless of
    %      frameId. Consecutive frames carrying the same burst do NOT
    %      re-randomise the fading process.
    %   2. Same (txId, rxId, frameId) but different BurstId => different
    %      seeds. Two distinct bursts on the same link in the same frame
    %      see independent fading.
    %   3. When BurstId is absent the implementation falls back to
    %      "frame_<frameId>" so the legacy 1-burst-per-frame path keeps
    %      a deterministic seed.
    %   4. Output is a finite double in [1, 2^31 - 1].

    properties
        Factory
    end

    methods (TestMethodSetup)
        function createFactory(testCase)
            cfg.ChannelModels.AWGN = struct('handle', 'csrd.blocks.physical.channel.AWGN');
            testCase.Factory = csrd.factories.ChannelFactory('Config', cfg);
        end
    end

    methods (Test)

        function sameBurstSameSeedAcrossFrames(testCase)
            link = struct('BurstId', 'Tx1.B7');
            s1 = testCase.Factory.deriveChannelSeed(1, 'Tx1', 'Rx1', link);
            s2 = testCase.Factory.deriveChannelSeed(2, 'Tx1', 'Rx1', link);
            s3 = testCase.Factory.deriveChannelSeed(99, 'Tx1', 'Rx1', link);
            testCase.verifyEqual(s1, s2, ...
                'Same BurstId must keep the seed stable across frames.');
            testCase.verifyEqual(s1, s3, ...
                'Same BurstId must keep the seed stable across many frames.');
        end

        function differentBurstsDifferentSeedsSameFrame(testCase)
            linkA = struct('BurstId', 'Tx1.B1');
            linkB = struct('BurstId', 'Tx1.B2');
            sA = testCase.Factory.deriveChannelSeed(5, 'Tx1', 'Rx1', linkA);
            sB = testCase.Factory.deriveChannelSeed(5, 'Tx1', 'Rx1', linkB);
            testCase.verifyNotEqual(sA, sB, ...
                'Two distinct bursts on the same link/frame must yield different seeds.');
        end

        function differentLinksDifferentSeeds(testCase)
            link = struct('BurstId', 'Tx1.B1');
            s1 = testCase.Factory.deriveChannelSeed(3, 'Tx1', 'Rx1', link);
            s2 = testCase.Factory.deriveChannelSeed(3, 'Tx2', 'Rx1', link);
            s3 = testCase.Factory.deriveChannelSeed(3, 'Tx1', 'Rx2', link);
            testCase.verifyNotEqual(s1, s2, ...
                'Different transmitters must yield different seeds.');
            testCase.verifyNotEqual(s1, s3, ...
                'Different receivers must yield different seeds.');
            testCase.verifyNotEqual(s2, s3, ...
                'Distinct (Tx, Rx) pairs must yield distinct seeds.');
        end

        function fallbackUsesFrameIdWhenBurstIdMissing(testCase)
            link = struct();  % no BurstId
            s1 = testCase.Factory.deriveChannelSeed(1, 'Tx1', 'Rx1', link);
            s2 = testCase.Factory.deriveChannelSeed(2, 'Tx1', 'Rx1', link);
            testCase.verifyNotEqual(s1, s2, ...
                'Without BurstId the fallback must include frameId so distinct frames differ.');

            % Fallback must match the documented "frame_<frameId>" formula.
            expected = csrd.utils.hash.shortInt32Hash('Tx=Tx1|Rx=Rx1|Burst=frame_1');
            if expected <= 0; expected = 1; end
            testCase.verifyEqual(s1, expected, ...
                'Fallback formula must be Tx=...|Rx=...|Burst=frame_<frameId>.');
        end

        function fallbackUsesFrameIdWhenBurstIdEmpty(testCase)
            link = struct('BurstId', '');
            s = testCase.Factory.deriveChannelSeed(7, 'Tx1', 'Rx1', link);
            expected = csrd.utils.hash.shortInt32Hash('Tx=Tx1|Rx=Rx1|Burst=frame_7');
            if expected <= 0; expected = 1; end
            testCase.verifyEqual(s, expected, ...
                'Empty BurstId must trigger the frame_<frameId> fallback.');
        end

        function seedRangeIsValid(testCase)
            for frameId = 1:5
                link = struct('BurstId', sprintf('Tx%d.B%d', frameId, frameId));
                s = testCase.Factory.deriveChannelSeed(frameId, ...
                    sprintf('Tx%d', frameId), sprintf('Rx%d', frameId), link);
                testCase.verifyClass(s, 'double');
                testCase.verifyGreaterThanOrEqual(s, 1);
                testCase.verifyLessThanOrEqual(s, 2^31 - 1);
                testCase.verifyTrue(isfinite(s), 'Seed must be finite.');
                testCase.verifyEqual(s, floor(s), 'Seed must be an integer-valued double.');
            end
        end

    end

end
