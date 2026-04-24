classdef AWGNChannelTest < matlab.unittest.TestCase
    % AWGNChannelTest - Pin SNR semantics and I/O contract for AWGNChannel.
    %
    %   Verifies that:
    %     * The actual signal-to-noise ratio measured on the output matches
    %       the configured SNRdB within statistical tolerance.
    %     * Both struct and array inputs are supported.
    %     * Reproducibility holds for a fixed seed.
    %     * Empty signal input is handled gracefully.

    methods (Test)

        function actualSnrMatchesConfigured(testCase)
            snrTargets = [-3, 0, 10, 20];
            for snr = snrTargets
                ch = csrd.blocks.physical.channel.AWGNChannel( ...
                    'SNRdB', snr, 'Seed', 1234);
                cleanup = onCleanup(@() release(ch)); %#ok<NASGU>
                signal = (randn(50000, 1) + 1j * randn(50000, 1)) / sqrt(2);
                noisy = ch(signal);
                noisySig = noisy.Signal;
                noise = noisySig - signal;
                signalPower = mean(abs(signal) .^ 2);
                noisePower = mean(abs(noise) .^ 2);
                measuredSNR = 10 * log10(signalPower / noisePower);
                testCase.verifyLessThan(abs(measuredSNR - snr), 0.5, ...
                    sprintf('SNR target %.1f dB but measured %.2f dB', snr, measuredSNR));
            end
        end

        function structInputProducesStructOutput(testCase)
            ch = csrd.blocks.physical.channel.AWGNChannel( ...
                'SNRdB', 5, 'Seed', 99);
            cleanup = onCleanup(@() release(ch)); %#ok<NASGU>
            input = struct();
            input.Signal = (1 + 1j) * ones(100, 1);
            input.SampleRate = 1e6;
            input.Tag = 'preserved';
            output = ch(input);
            testCase.verifyTrue(isstruct(output));
            testCase.verifyTrue(isfield(output, 'Signal'));
            testCase.verifyTrue(isfield(output, 'SampleRate'), ...
                'Struct fields outside Signal must be preserved.');
            testCase.verifyEqual(output.SampleRate, 1e6);
            testCase.verifyEqual(output.Tag, 'preserved');
            testCase.verifyEqual(output.AppliedSNRdB, 5);
        end

        function arrayInputProducesStructOutput(testCase)
            ch = csrd.blocks.physical.channel.AWGNChannel( ...
                'SNRdB', 5, 'Seed', 99);
            cleanup = onCleanup(@() release(ch)); %#ok<NASGU>
            sig = (1 + 1j) * ones(100, 1);
            output = ch(sig);
            testCase.verifyTrue(isstruct(output));
            testCase.verifyTrue(isfield(output, 'Signal'));
            testCase.verifyEqual(size(output.Signal), [100, 1]);
        end

        function reproducibleWithSameSeed(testCase)
            sig = (randn(1000, 1) + 1j * randn(1000, 1)) / sqrt(2);
            ch1 = csrd.blocks.physical.channel.AWGNChannel( ...
                'SNRdB', 10, 'Seed', 4242);
            ch2 = csrd.blocks.physical.channel.AWGNChannel( ...
                'SNRdB', 10, 'Seed', 4242);
            o1 = ch1(sig);
            o2 = ch2(sig);
            testCase.verifyEqual(o1.Signal, o2.Signal, ...
                'Same Seed must produce identical noisy signal.');
            release(ch1); release(ch2);
        end

        function emptySignalReturnsInput(testCase)
            ch = csrd.blocks.physical.channel.AWGNChannel('Seed', 1);
            cleanup = onCleanup(@() release(ch)); %#ok<NASGU>
            output = ch(complex(zeros(0, 1)));
            testCase.verifyTrue(isnumeric(output) || isstruct(output));
        end

        function zeroSignalDoesNotCrash(testCase)
            ch = csrd.blocks.physical.channel.AWGNChannel( ...
                'SNRdB', 10, 'Seed', 1);
            cleanup = onCleanup(@() release(ch)); %#ok<NASGU>
            sig = complex(zeros(100, 1));
            output = ch(sig);
            testCase.verifyEqual(size(output.Signal), [100, 1]);
            testCase.verifyTrue(all(isfinite(output.Signal)));
        end

    end

end
