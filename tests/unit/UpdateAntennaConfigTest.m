classdef UpdateAntennaConfigTest < matlab.unittest.TestCase
    % UpdateAntennaConfigTest - Unit tests for antenna config write-back logic.
    %
    %   Pins the audit fix that the (previously private) helper now
    %   returns an updated TxInfo struct, including SiteConfig.Antenna.

    methods (Test)

        function noChangeWhenSegmentMatchesExisting(testCase)
            txInfo = makeTxInfo(2, 'ULA');
            seg = {struct('NumTransmitAntennas', 2)};
            [out, didChange, n, arr] = ...
                csrd.utils.core.applyAntennaConfigFromSegments(txInfo, seg);
            testCase.verifyFalse(didChange);
            testCase.verifyEqual(n, 2);
            testCase.verifyEqual(arr, 'ULA');
            testCase.verifyEqual(out.NumTransmitAntennas, 2);
        end

        function sisoToMimoUpgradesArrayToULA(testCase)
            txInfo = makeTxInfo(1, 'Isotropic');
            seg = {struct('NumTransmitAntennas', 3)};
            [out, didChange, n, arr] = ...
                csrd.utils.core.applyAntennaConfigFromSegments(txInfo, seg);
            testCase.verifyTrue(didChange);
            testCase.verifyEqual(n, 3);
            testCase.verifyEqual(arr, 'ULA');
            testCase.verifyEqual(out.NumTransmitAntennas, 3);
            testCase.verifyEqual(out.SiteConfig.Antenna.NumAntennas, 3);
            testCase.verifyEqual(out.SiteConfig.Antenna.Array, 'ULA');
        end

        function fourAntennasUseURA(testCase)
            txInfo = makeTxInfo(1, 'Isotropic');
            seg = {struct('NumTransmitAntennas', 4)};
            [out, didChange, ~, arr] = ...
                csrd.utils.core.applyAntennaConfigFromSegments(txInfo, seg);
            testCase.verifyTrue(didChange);
            testCase.verifyEqual(arr, 'URA');
            testCase.verifyEqual(out.SiteConfig.Antenna.Array, 'URA');
        end

        function downgradeToOneRevertsToIsotropic(testCase)
            txInfo = makeTxInfo(4, 'URA');
            seg = {struct('NumTransmitAntennas', 1)};
            [out, didChange, ~, arr] = ...
                csrd.utils.core.applyAntennaConfigFromSegments(txInfo, seg);
            testCase.verifyTrue(didChange);
            testCase.verifyEqual(arr, 'Isotropic');
            testCase.verifyEqual(out.SiteConfig.Antenna.Array, 'Isotropic');
        end

        function missingSiteConfigStillUpdatesCleanly(testCase)
            % Audit reproduction: SiteConfig may be absent on minimal
            % TxInfo objects; the helper must materialise the substruct.
            txInfo = struct('NumTransmitAntennas', 1);
            seg = {struct('NumTransmitAntennas', 2)};
            [out, didChange, ~, ~] = ...
                csrd.utils.core.applyAntennaConfigFromSegments(txInfo, seg);
            testCase.verifyTrue(didChange);
            testCase.verifyTrue(isfield(out, 'SiteConfig'));
            testCase.verifyTrue(isfield(out.SiteConfig, 'Antenna'));
            testCase.verifyEqual(out.SiteConfig.Antenna.NumAntennas, 2);
        end

        function emptySegmentsLeaveTxInfoUntouched(testCase)
            txInfo = makeTxInfo(2, 'ULA');
            [out, didChange, ~, ~] = ...
                csrd.utils.core.applyAntennaConfigFromSegments(txInfo, {});
            testCase.verifyFalse(didChange);
            testCase.verifyEqual(out, txInfo);
        end

    end

end

function tx = makeTxInfo(num, arr)
    tx = struct();
    tx.NumTransmitAntennas = num;
    tx.SiteConfig.Antenna.NumAntennas = num;
    tx.SiteConfig.Antenna.Array = arr;
end
