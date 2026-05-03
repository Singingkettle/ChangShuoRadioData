classdef MessageFactorySeedAliasTest < matlab.unittest.TestCase
    % MessageFactorySeedAliasTest - Phase 17 rejects the old SeedValue alias.

    methods (TestMethodSetup)

        function configureLogging(~)
            csrd.runtime.logger.GlobalLogManager.reset();
            logCfg = struct( ...
                'Level', 'ERROR', ...
                'SaveToFile', false, ...
                'DisplayInConsole', false);
            csrd.runtime.logger.GlobalLogManager.initialize(logCfg);
        end

    end

    methods (TestMethodTeardown)

        function teardown(~)
            csrd.runtime.logger.GlobalLogManager.reset();
        end

    end

    methods (Test)

        function seedValueAliasFailsFast(testCase)
            seedValue = 4242;
            seg = struct();
            seg.SegmentId = 'aliased';
            seg.Message = struct('Length', 1024, 'SymbolRate', 100e3, ...
                'SeedValue', seedValue);

            testCase.verifyError(@() MessageFactorySeedAliasTest.runFactoryOnce(seg), ...
                'CSRD:Message:DeprecatedSeedValueAlias');
        end

        function differentSeedsProduceDifferentSequences(testCase)
            seg = struct();
            seg.SegmentId = 'A';
            seg.Message = struct('Length', 1024, 'SymbolRate', 100e3, 'Seed', 11);
            outA = MessageFactorySeedAliasTest.runFactoryOnce(seg);

            seg.SegmentId = 'B';
            seg.Message = struct('Length', 1024, 'SymbolRate', 100e3, 'Seed', 22);
            outB = MessageFactorySeedAliasTest.runFactoryOnce(seg);

            testCase.verifyFalse(isequal(outA.data, outB.data), ...
                'Different seeds must produce different bit sequences.');
        end

        function reSeedingAfterFirstStepIsHonoured(testCase)
            % Same factory instance: change Seed mid-life. Pre-fix the
            % cached, locked block kept its initial RNG state and
            % silently ignored the new Seed.
            cfg = struct();
            cfg.MessageTypes.RandomBit.handle = 'csrd.blocks.physical.message.RandomBit';
            cfg.MessageTypes.RandomBit.Config = struct();
            factory = csrd.factories.MessageFactory('Config', cfg);
            cleanupObj = onCleanup(@() release(factory)); %#ok<NASGU>
            setup(factory);

            seg = struct('SegmentId', 's', 'Message', ...
                struct('Length', 512, 'SymbolRate', 100e3, 'Seed', 100));
            firstA = step(factory, 1, seg, 'RandomBit');

            seg.Message.Seed = 999;
            secondB = step(factory, 2, seg, 'RandomBit');

            seg.Message.Seed = 100;
            thirdAgain = step(factory, 3, seg, 'RandomBit');

            testCase.verifyFalse(isequal(firstA.data, secondB.data), ...
                'Re-seeding mid-life must change the RNG output.');
            testCase.verifyEqual(firstA.data, thirdAgain.data, ...
                'Returning to the original seed must reproduce the original sequence.');
        end

    end

    methods (Static, Access = private)

        function out = runFactoryOnce(segmentInfo)
            cfg = struct();
            cfg.MessageTypes.RandomBit.handle = 'csrd.blocks.physical.message.RandomBit';
            cfg.MessageTypes.RandomBit.Config = struct();
            factory = csrd.factories.MessageFactory('Config', cfg);
            cleanupObj = onCleanup(@() release(factory)); %#ok<NASGU>
            setup(factory);
            out = step(factory, 1, segmentInfo, 'RandomBit');
        end

    end

end
