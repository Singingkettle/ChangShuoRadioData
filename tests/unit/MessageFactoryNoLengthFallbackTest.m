classdef MessageFactoryNoLengthFallbackTest < matlab.unittest.TestCase
    % MessageFactoryNoLengthFallbackTest - Reject implicit message timing defaults.

    methods (TestMethodSetup)
        function configureLogging(~)
            csrd.runtime.logger.GlobalLogManager.reset();
            logCfg = struct('Level', 'ERROR', 'SaveToFile', false, ...
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
        function missingLengthFailsFast(testCase)
            seg = localSegment();
            seg.Message = rmfield(seg.Message, 'Length');
            testCase.verifyError(@() localRun(seg), 'CSRD:Message:MissingLength');
        end

        function missingSymbolRateFailsFast(testCase)
            seg = localSegment();
            seg.Message = rmfield(seg.Message, 'SymbolRate');
            testCase.verifyError(@() localRun(seg), 'CSRD:Message:MissingSymbolRate');
        end

        function explicitLengthAndSymbolRatePass(testCase)
            out = localRun(localSegment());
            testCase.verifyNumElements(out.data, 128);
        end
    end
end

function seg = localSegment()
seg = struct();
seg.SegmentId = 'Tx1.Seg001';
seg.Message = struct('Length', 128, 'SymbolRate', 250e3, 'Seed', 17);
end

function out = localRun(seg)
cfg = struct();
cfg.MessageTypes.RandomBit.handle = 'csrd.blocks.physical.message.RandomBit';
cfg.MessageTypes.RandomBit.Config = struct();
factory = csrd.factories.MessageFactory('Config', cfg);
cleanupObj = onCleanup(@() release(factory)); %#ok<NASGU>
setup(factory);
out = step(factory, 1, seg, 'RandomBit');
end
