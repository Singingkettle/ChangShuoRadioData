classdef SegmentIdContractTest < matlab.unittest.TestCase
    % SegmentIdContractTest - Pin the SegmentId field convention.
    %
    %   Phase 17 makes `SegmentId` the only accepted spelling.

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

        function canonicalSpellingIsAcceptedByMessageFactory(testCase)
            segNew = struct();
            segNew.SegmentId = 'modern_id';
            segNew.Message = struct('Length', 256, 'SymbolRate', 100e3, 'Seed', 7);
            outNew = SegmentIdContractTest.runFactoryOnce(segNew);

            testCase.verifyNotEmpty(outNew.data);
        end

        function legacySpellingFailsFast(testCase)
            segLegacy = struct();
            segLegacy.SegmentID = 'legacy_id';
            segLegacy.Message = struct('Length', 256, 'SymbolRate', 100e3, 'Seed', 7);

            testCase.verifyError(@() SegmentIdContractTest.runFactoryOnce(segLegacy), ...
                'CSRD:Message:DeprecatedSegmentIDAlias');
        end

        function missingSegmentIdFailsFast(testCase)
            seg = struct();
            seg.Message = struct('Length', 64, 'SymbolRate', 100e3, 'Seed', 1);
            testCase.verifyError(@() SegmentIdContractTest.runFactoryOnce(seg), ...
                'CSRD:Message:MissingSegmentId');
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
