classdef BaseChannelDistanceTest < matlab.unittest.TestCase
    % BaseChannelDistanceTest - Lock the BaseChannel distance unit (METERS).
    %
    %   Regression for the original 60 dB FSPL bug: an earlier version of
    %   BaseChannel.genPathLoss called fspl(obj.Distance * 1000, ...),
    %   silently treating the documented "meters" property as kilometers.
    %   Verifies free-space and atmospheric modes against analytical
    %   references with strict tolerances.

    methods (Test)

        function freeSpacePathLossMatchesAnalytical(testCase)
            carrier = 2.4e9;
            distance_m = 100;
            ch = csrd.blocks.physical.channel.BaseChannel( ...
                'CarrierFrequency', carrier, ...
                'Distance', distance_m, ...
                'atmosCond', 'FreeSpace');
            expected = fspl(distance_m, physconst('light') / carrier);
            testCase.verifyLessThan(abs(ch.PathLoss - expected), 0.5, ...
                sprintf('FreeSpace path loss %.2f dB differs from analytical %.2f dB by more than 0.5 dB', ...
                    ch.PathLoss, expected));
        end

        function freeSpaceDifference60dBPerDecade(testCase)
            carrier = 2.4e9;
            ch100m = csrd.blocks.physical.channel.BaseChannel( ...
                'CarrierFrequency', carrier, 'Distance', 100);
            ch100km = csrd.blocks.physical.channel.BaseChannel( ...
                'CarrierFrequency', carrier, 'Distance', 1e5);
            delta = ch100km.PathLoss - ch100m.PathLoss;
            testCase.verifyLessThan(abs(delta - 60), 0.5, ...
                sprintf('Three-decade FSPL difference %.2f dB should be ~60 dB', delta));
        end

        function distanceClampedAtOneMeter(testCase)
            % Distance must be a positive real, but tiny values should
            % be clamped to 1 m before fspl() so the toolbox does not
            % raise.
            ch = csrd.blocks.physical.channel.BaseChannel( ...
                'CarrierFrequency', 1e9, ...
                'Distance', 1e-6); %#ok<NASGU>
            testCase.verifyTrue(isfinite(ch.PathLoss));
        end

        function atmosphericModesAddPositiveLoss(testCase)
            % fogpl requires f >= 10 GHz; gaspl/rainpl support f >= 1 GHz.
            % 30 GHz is a safe operating point for all three helpers.
            carrier = 30e9;
            distance_m = 5000;
            modes = {'FreeSpace', 'Fog', 'Gas', 'Rain'};
            results = containers.Map('KeyType', 'char', 'ValueType', 'double');
            for k = 1:numel(modes)
                ch = csrd.blocks.physical.channel.BaseChannel( ...
                    'CarrierFrequency', carrier, ...
                    'Distance', distance_m, ...
                    'atmosCond', modes{k});
                results(modes{k}) = ch.PathLoss;
                testCase.verifyTrue(isfinite(ch.PathLoss), ...
                    sprintf('%s mode produced non-finite path loss', modes{k}));
            end
            % Atmospheric models can only ADD loss on top of FreeSpace.
            for k = 2:numel(modes)
                testCase.verifyGreaterThanOrEqual( ...
                    results(modes{k}) - results('FreeSpace'), -0.05, ...
                    sprintf('%s mode loss must be >= FreeSpace', modes{k}));
            end
        end

        function mimoStepTracksUpdatedDistance(testCase)
            % Regression for the frozen-path-loss bug: ChannelFactory updates
            % Distance per frame, but PathLoss was derived only once at
            % construction (from the default Distance = 1 m), so every fading
            % link was attenuated by the 1 m path loss regardless of the real
            % Tx-Rx separation. The MIMO step must recompute PathLoss from the
            % current Distance so the realised attenuation tracks distance and
            % matches the distance-based PathLoss recorded in the annotation.
            carrier = 2.4e9;
            ch = csrd.blocks.physical.channel.MIMO( ...
                'CarrierFrequency', carrier, 'FadingDistribution', 'Rayleigh', ...
                'PathDelays', 0, 'AveragePathGains', 0, 'MaximumDopplerShift', 1, ...
                'SampleRate', 1e6);
            in = struct('Signal', complex(ones(4096, 1)), 'SampleRate', 1e6, 'StartTime', 0);
            ch.step(in);
            nearPathLoss = ch.PathLoss;          % Distance = 1 m -> ~40 dB
            release(ch); ch.Distance = 10000;
            ch.step(in);
            farPathLoss = ch.PathLoss;           % Distance = 10 km -> ~120 dB
            testCase.verifyLessThan( ...
                abs(farPathLoss - fspl(10000, physconst('light') / carrier)), 1, ...
                'MIMO step must recompute PathLoss to the fspl value at the current Distance.');
            testCase.verifyGreaterThan(farPathLoss - nearPathLoss, 50, ...
                'Path loss at 10 km must greatly exceed the 1 m value (attenuation tracks distance).');
        end

        function antennaModeIsSetCorrectly(testCase)
            ch = csrd.blocks.physical.channel.BaseChannel( ...
                'NumTransmitAntennas', 2, 'NumReceiveAntennas', 4);
            testCase.verifyEqual(ch.mode, 'MIMO');

            ch = csrd.blocks.physical.channel.BaseChannel( ...
                'NumTransmitAntennas', 1, 'NumReceiveAntennas', 1);
            testCase.verifyEqual(ch.mode, 'SISO');
        end

    end

end
