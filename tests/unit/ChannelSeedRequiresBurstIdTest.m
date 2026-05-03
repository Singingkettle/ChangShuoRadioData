classdef ChannelSeedRequiresBurstIdTest < matlab.unittest.TestCase
    % ChannelSeedRequiresBurstIdTest - No frame-id seed fallback after Phase 17.
    % 中文说明：信道种子必须由 Tx/Rx/Burst 三元组决定。

    methods (Test)
        function missingBurstIdIsRejected(testCase)
            f = csrd.factories.ChannelFactory('Config', localChannelConfig());
            testCase.verifyError(@() f.deriveChannelSeed(3, 'Tx1', 'Rx1', struct()), ...
                'CSRD:Channel:MissingBurstId');
        end

        function nonEmptyBurstIdIsStableAcrossFrames(testCase)
            f = csrd.factories.ChannelFactory('Config', localChannelConfig());
            link = struct('BurstId', 'Tx1.Burst003');
            s1 = f.deriveChannelSeed(1, 'Tx1', 'Rx1', link);
            s2 = f.deriveChannelSeed(9, 'Tx1', 'Rx1', link);
            testCase.verifyEqual(s1, s2);
        end
    end
end

function cfg = localChannelConfig()
cfg = struct();
cfg.ChannelModels.AWGN.handle = 'csrd.blocks.physical.channel.AWGNChannel';
end
