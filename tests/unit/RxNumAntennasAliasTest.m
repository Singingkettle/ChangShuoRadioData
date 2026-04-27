classdef RxNumAntennasAliasTest < matlab.unittest.TestCase
    %RxNumAntennasAliasTest
    %
    %   v0.4 deep refactor: the Phase 1 Dependent property alias (the
    %   transitional NumAntennas → NumReceiveAntennas mapping that bridged
    %   the field-name mismatch between RxInfo and RRFSimulator) has been
    %   replaced by renaming the canonical property itself to NumAntennas.
    %   This test pins down the new contract:
    %
    %     1. RRFSimulator exposes NumAntennas (and ONLY NumAntennas) as a
    %        canonical, settable, isprop-discoverable property.
    %     2. ReceiveFactory's "copy isprop fields from rxInfo" loop
    %        propagates rxInfo.NumAntennas through to rxBlock.NumAntennas
    %        without any silent dropping.
    %     3. The legacy NumReceiveAntennas property name is gone — any
    %        code still referring to it must be updated.

    methods (Test)

        function defaultIsOne(testCase)
            block = csrd.blocks.physical.rxRadioFront.RRFSimulator();
            testCase.verifyEqual(block.NumAntennas, 1, ...
                'RRFSimulator default NumAntennas must be 1.');
        end

        function settingPropagates(testCase)
            block = csrd.blocks.physical.rxRadioFront.RRFSimulator();
            block.NumAntennas = 4;
            testCase.verifyEqual(block.NumAntennas, 4, ...
                'set NumAntennas must persist on RRFSimulator.');
        end

        function isPropFindsCanonicalName(testCase)
            block = csrd.blocks.physical.rxRadioFront.RRFSimulator();
            testCase.verifyTrue(isprop(block, 'NumAntennas'), ...
                'isprop(block,''NumAntennas'') must be true.');
            testCase.verifyFalse(isprop(block, 'NumReceiveAntennas'), ...
                ['Legacy NumReceiveAntennas alias must be gone after the ' ...
                 'v0.4 deep refactor; it indicates dead-name leakage.']);
        end

        function receiveFactoryCopyLoopHonoursRxInfo(testCase)
            % Mimic the property-copy loop ReceiveFactory.configureReceiverBlock
            % runs against rxInfoThisRx. The interesting field is NumAntennas,
            % which must land on the block.
            block = csrd.blocks.physical.rxRadioFront.RRFSimulator();
            rxInfo = struct('NumAntennas', 3, 'IrrelevantField', 'ignored');
            propNames = fieldnames(rxInfo);
            for k = 1:numel(propNames)
                propName = propNames{k};
                if isprop(block, propName)
                    block.(propName) = rxInfo.(propName);
                end
            end
            testCase.verifyEqual(block.NumAntennas, 3, ...
                'Field-copy loop must lift rxInfo.NumAntennas onto the block.');
        end

    end

end
