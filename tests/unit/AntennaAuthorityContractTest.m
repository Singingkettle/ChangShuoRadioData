classdef AntennaAuthorityContractTest < matlab.unittest.TestCase
    % AntennaAuthorityContractTest - Tx antenna count is planner-owned.
    % 中文说明：执行层不得用调制器输出回写 TxInfo 天线数量。

    methods (Test)
        function productionTransmitterPathDoesNotApplySegmentAntennaRewrite(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            code = fileread(fullfile(root, '+csrd', '+core', '@ChangShuo', ...
                'private', 'processSingleTransmitter.m'));

            testCase.verifyFalse(contains(code, 'updateTransmitterAntennaConfig'), ...
                'processSingleTransmitter must not rewrite TxInfo from segment output.');
            testCase.verifyFalse(contains(code, 'applyAntennaConfigFromSegments'), ...
                'processSingleTransmitter must not call applyAntennaConfigFromSegments.');
        end

        function modulationFactoryRejectsMissingTxAntennaCount(testCase)
            cfg = localModFactoryConfig();
            factory = csrd.factories.ModulationFactory('Config', cfg);
            cleanupObj = onCleanup(@() release(factory)); %#ok<NASGU>
            setup(factory);

            seg = struct();
            seg.Modulation = struct('TypeID', 'PSK', 'Order', 4, ...
                'SymbolRate', 100e3, 'SamplePerSymbol', 4, ...
                'SamplesPerSymbol', 4, 'BitsPerSymbol', 2);
            seg.Placement = struct('TargetBandwidth', 1e3);
            msg = struct('data', ones(16, 1));

            testCase.verifyError(@() step(factory, msg.data, 1, "Tx1", 1, ...
                seg.Modulation, seg.Placement), ...
                'CSRD:Modulation:MissingNumTransmitAntennas');
        end
    end
end

function cfg = localModFactoryConfig()
cfg = struct();
cfg.digital.PSK.handle = 'csrd.blocks.physical.modulate.digital.PSK.PSK';
end
