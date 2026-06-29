classdef MimoMeasuredSnrScaleTest < matlab.unittest.TestCase
    % MimoMeasuredSnrScaleTest - guards the round-12 fix: the per-emitter
    % measured-SNR signal power (ChannelSignalPowerW) must be recorded at the
    % COLLAPSED monitor-stream scale, because the receiver saves sum(antennas)
    % (localCollapseAntennaSignal). Recording the per-antenna-column mean would
    % bias the measured SNR low by ~10*log10(NumReceiveAntennas) dB against the
    % absolute receiver thermal/ADC noise referenced to that summed stream.

    methods (Test)
        function channelSignalPowerIsCollapsedScaleForMultiAntenna(testCase)
            sig = localSignal();
            nr = 8;
            ch = csrd.blocks.physical.channel.MIMO('FadingDistribution', 'Rayleigh', ...
                'SampleRate', 1e6, 'PathDelays', [0 1e-6], 'AveragePathGains', [0 -3], ...
                'MaximumDopplerShift', 10, 'NumTransmitAntennas', 1, ...
                'NumReceiveAntennas', nr, 'Seed', 101);
            out = step(ch, localInput(sig));
            release(ch);

            collapsed = mean(abs(sum(out.Signal, 2)) .^ 2);
            perColumn = mean(abs(out.Signal(:)) .^ 2);
            % Recorded power is the collapsed (summed-antenna) monitor-stream
            % power, not the per-antenna-column mean.
            testCase.verifyEqual(out.ChannelSignalPowerW, collapsed, 'RelTol', 1e-9, ...
                'ChannelSignalPowerW must be the collapsed monitor-stream power.');
            % That scale is materially above the per-column scale (the bug that
            % biased the multi-antenna SNR low is gone).
            testCase.verifyGreaterThan(out.ChannelSignalPowerW, 1.5 * perColumn, ...
                'ChannelSignalPowerW collapsed to the per-antenna scale.');
        end

        function channelSignalPowerUnchangedForSingleAntenna(testCase)
            sig = localSignal();
            ch = csrd.blocks.physical.channel.MIMO('FadingDistribution', 'Rayleigh', ...
                'SampleRate', 1e6, 'PathDelays', [0 1e-6], 'AveragePathGains', [0 -3], ...
                'MaximumDopplerShift', 10, 'NumTransmitAntennas', 1, ...
                'NumReceiveAntennas', 1, 'Seed', 101);
            out = step(ch, localInput(sig));
            release(ch);
            % SISO: sum(.,2) is a no-op, so the recorded power is unchanged.
            testCase.verifyEqual(out.ChannelSignalPowerW, mean(abs(out.Signal(:)) .^ 2), ...
                'RelTol', 1e-9, 'SISO ChannelSignalPowerW must equal the signal power.');
        end
    end
end

function sig = localSignal()
s = RandStream('mt19937ar', 'Seed', 123);
sig = (randn(s, 4000, 1) + 1j * randn(s, 4000, 1)) / sqrt(2);
end

function x = localInput(sig)
x = struct('Signal', sig, 'SampleRate', 1e6, 'StartTime', 0, 'NumTransmitAntennas', 1);
end
