classdef UpdateAntennaConfigTest < matlab.unittest.TestCase
    % UpdateAntennaConfigTest - Verify antenna writeback contract.
    %
    %   MATLAB structs are value-typed. The original
    %   updateTransmitterAntennaConfig modified TxInfo in-place and the
    %   caller never saw the change, so a SISO->MIMO upgrade by the
    %   modulator silently disappeared before the channel/RF blocks ran.
    %   The refactored helper csrd.utils.core.applyAntennaConfigFromSegments
    %   returns the updated struct, and these tests pin that contract.

    methods (Test)

        function noSegmentsReturnsUnchangedTxInfo(testCase)
            TxInfo = struct('NumTransmitAntennas', 1);
            [out, didChange, finalNum, arrayType] = ...
                csrd.utils.core.applyAntennaConfigFromSegments(TxInfo, {});
            testCase.verifyEqual(out, TxInfo);
            testCase.verifyFalse(didChange);
            testCase.verifyEqual(finalNum, 1);
            testCase.verifyEqual(arrayType, 'Isotropic');
        end

        function sisoToMimoUpgradeIsApplied(testCase)
            TxInfo = struct('NumTransmitAntennas', 1);
            seg = struct('NumTransmitAntennas', 4);
            [out, didChange, finalNum, arrayType] = ...
                csrd.utils.core.applyAntennaConfigFromSegments(TxInfo, {seg});
            testCase.verifyTrue(didChange);
            testCase.verifyEqual(finalNum, 4);
            testCase.verifyEqual(out.NumTransmitAntennas, 4);
            testCase.verifyEqual(out.SiteConfig.Antenna.NumAntennas, 4);
            testCase.verifyEqual(out.SiteConfig.Antenna.Array, 'URA');
            testCase.verifyEqual(arrayType, 'URA');
        end

        function twoAntennaUsesUla(testCase)
            TxInfo = struct('NumTransmitAntennas', 1);
            seg = struct('NumTransmitAntennas', 2);
            [out, didChange, ~, arrayType] = ...
                csrd.utils.core.applyAntennaConfigFromSegments(TxInfo, {seg});
            testCase.verifyTrue(didChange);
            testCase.verifyEqual(out.SiteConfig.Antenna.Array, 'ULA');
            testCase.verifyEqual(arrayType, 'ULA');
        end

        function oddAntennaUsesUla(testCase)
            TxInfo = struct('NumTransmitAntennas', 1);
            seg = struct('NumTransmitAntennas', 3);
            [out, ~, ~, arrayType] = ...
                csrd.utils.core.applyAntennaConfigFromSegments(TxInfo, {seg});
            testCase.verifyEqual(out.SiteConfig.Antenna.Array, 'ULA');
            testCase.verifyEqual(arrayType, 'ULA');
        end

        function preservesSiteConfigOtherFields(testCase)
            TxInfo = struct('NumTransmitAntennas', 1);
            TxInfo.SiteConfig = struct('Position', [1 2 3]);
            TxInfo.SiteConfig.Antenna = struct('Gain', 5, 'Array', 'Isotropic');
            seg = struct('NumTransmitAntennas', 4);
            [out, ~, ~, ~] = ...
                csrd.utils.core.applyAntennaConfigFromSegments(TxInfo, {seg});
            testCase.verifyEqual(out.SiteConfig.Position, [1 2 3]);
            testCase.verifyEqual(out.SiteConfig.Antenna.Gain, 5, ...
                'Existing antenna gain must survive the upgrade.');
            testCase.verifyEqual(out.SiteConfig.Antenna.NumAntennas, 4);
            testCase.verifyEqual(out.SiteConfig.Antenna.Array, 'URA');
        end

        function unchangedAntennaCountIsNoOp(testCase)
            TxInfo = struct('NumTransmitAntennas', 2);
            TxInfo.SiteConfig.Antenna.Array = 'ULA';
            seg = struct('NumTransmitAntennas', 2);
            [out, didChange, ~, arrayType] = ...
                csrd.utils.core.applyAntennaConfigFromSegments(TxInfo, {seg});
            testCase.verifyFalse(didChange);
            testCase.verifyEqual(out, TxInfo);
            testCase.verifyEqual(arrayType, 'ULA');
        end

        function emptyLastSegmentReturnsUnchanged(testCase)
            TxInfo = struct('NumTransmitAntennas', 1);
            [out, didChange, ~, ~] = ...
                csrd.utils.core.applyAntennaConfigFromSegments(TxInfo, {[]});
            testCase.verifyFalse(didChange);
            testCase.verifyEqual(out, TxInfo);
        end

    end

end
