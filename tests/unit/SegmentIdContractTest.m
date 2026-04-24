classdef SegmentIdContractTest < matlab.unittest.TestCase
    % SegmentIdContractTest - Pin the SegmentId field convention.
    %
    %   The codebase converged on `SegmentId` (lower-case d) but the
    %   MessageFactory historically read `SegmentID` (upper-case ID).
    %   Both spellings must keep working so that the rename can roll
    %   out without breaking external configurations, but the new
    %   spelling MUST be the one written by all internal producers.

    methods (TestMethodSetup)

        function configureLogging(~)
            csrd.utils.logger.GlobalLogManager.reset();
            logCfg = struct( ...
                'Level', 'ERROR', ...
                'SaveToFile', false, ...
                'DisplayInConsole', false);
            csrd.utils.logger.GlobalLogManager.initialize(logCfg);
        end

    end

    methods (TestMethodTeardown)

        function teardown(~)
            csrd.utils.logger.GlobalLogManager.reset();
        end

    end

    methods (Test)

        function bothSpellingsAreAcceptedByMessageFactory(testCase)
            % Black-box: each call uses a fresh factory so the RNG is
            % fully determined by the seed; the SegmentId/SegmentID
            % field is just used for logging and must not change the
            % output bits.
            segNew = struct();
            segNew.SegmentId = 'modern_id';
            segNew.Message = struct('Length', 256, 'Seed', 7);
            outNew = SegmentIdContractTest.runFactoryOnce(segNew);

            segLegacy = struct();
            segLegacy.SegmentID = 'legacy_id';
            segLegacy.Message = struct('Length', 256, 'Seed', 7);
            outLegacy = SegmentIdContractTest.runFactoryOnce(segLegacy);

            testCase.verifyEqual(outNew.data, outLegacy.data, ...
                'SegmentId and SegmentID labels must both reach the factory and produce identical bits when the seed is identical.');
        end

        function missingSegmentIdDoesNotCrash(testCase)
            % MessageFactory used to dereference segmentInfo.SegmentID
            % unconditionally; with the alias logic it must tolerate
            % the field being absent (e.g. unit tests / lightweight harnesses).
            seg = struct();
            seg.Message = struct('Length', 64, 'Seed', 1);
            out = SegmentIdContractTest.runFactoryOnce(seg);
            testCase.verifyNotEmpty(out.data);
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
