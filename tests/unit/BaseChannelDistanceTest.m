classdef BaseChannelDistanceTest < matlab.unittest.TestCase
    % BaseChannelDistanceTest - Unit tests for BaseChannel path-loss unit consistency.
    %
    %   Regression coverage for the audit issue where Distance was
    %   internally multiplied by 1000 even though the property is
    %   documented in meters. The fix unifies all distance arithmetic
    %   to meters; this test pins that contract.

    methods (Test)

        function fsplMatchesAnalyticalFormula(testCase)
            % FSPL(d, lambda) = 20*log10(4*pi*d / lambda)
            distance_m = 100;
            carrierFreq = 2.4e9;
            ch = csrd.blocks.physical.channel.BaseChannel( ...
                'CarrierFrequency', carrierFreq, ...
                'Distance', distance_m);
            lambda = physconst('LightSpeed') / carrierFreq;
            expectedPL = 20 * log10(4 * pi * distance_m / lambda);
            testCase.verifyEqual(ch.PathLoss, expectedPL, 'AbsTol', 1e-6, ...
                'BaseChannel must compute FSPL in meters.');
        end

        function distanceTenfoldYields20dB(testCase)
            % Doubling the distance: +6 dB. 10x: +20 dB.
            carrierFreq = 1e9;
            ch1 = csrd.blocks.physical.channel.BaseChannel( ...
                'CarrierFrequency', carrierFreq, 'Distance', 100);
            ch10 = csrd.blocks.physical.channel.BaseChannel( ...
                'CarrierFrequency', carrierFreq, 'Distance', 1000);
            testCase.verifyEqual(ch10.PathLoss - ch1.PathLoss, 20, 'AbsTol', 1e-6, ...
                'A 10x distance increase must yield exactly 20 dB extra FSPL.');
        end

        function distance100mNotInterpretedAs100km(testCase)
            % Pre-fix bug: 100 m was internally treated as 100 km, adding
            % 60 dB to FSPL. This test pins that the bug stays fixed.
            carrierFreq = 2.4e9;
            ch = csrd.blocks.physical.channel.BaseChannel( ...
                'CarrierFrequency', carrierFreq, 'Distance', 100);
            lambda = physconst('LightSpeed') / carrierFreq;
            buggyPL_km = 20 * log10(4 * pi * (100 * 1000) / lambda);
            actualPL = ch.PathLoss;
            testCase.verifyGreaterThan(buggyPL_km - actualPL, 55, ...
                'BaseChannel.Distance=100 must not be silently treated as 100 km.');
        end

        function fogAddsExtraLoss(testCase)
            % Fog atmospheric loss should be additive on top of FSPL.
            carrierFreq = 24e9;
            distance_m = 1000;
            chFree = csrd.blocks.physical.channel.BaseChannel( ...
                'CarrierFrequency', carrierFreq, 'Distance', distance_m, ...
                'atmosCond', 'FreeSpace');
            chFog = csrd.blocks.physical.channel.BaseChannel( ...
                'CarrierFrequency', carrierFreq, 'Distance', distance_m, ...
                'atmosCond', 'Fog');
            testCase.verifyGreaterThanOrEqual(chFog.PathLoss, chFree.PathLoss, ...
                'Fog conditions must add (non-negative) loss on top of FSPL.');
        end

    end

end
