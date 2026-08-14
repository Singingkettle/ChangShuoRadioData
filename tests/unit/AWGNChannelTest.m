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

        function declaresSnrWithoutAddingNoise(testCase)
            % AWGNChannel is propagation-neutral by construction: physically it has
            % always meant "no multipath, plus a target SNR", and the noise is now
            % SIZED here but REALIZED once, after both measured planes have been
            % taken from clean buffers (csrd.pipeline.signal.realizeChannelNoise).
            % Measuring an occupied bandwidth on a noisy buffer is not merely
            % imprecise, it is undefined -- noise contributes power across the whole
            % band -- so this block adding noise is exactly the defect the ordering
            % change removed.
            %
            % This replaces a test that asserted the realized SNR of this block's
            % output matched its configured target. That requirement did not
            % disappear; it moved to the injection point, and is asserted there by
            % RealizeChannelNoiseTest. What must hold HERE is stronger and more
            % specific than the old assertion: the waveform is returned bit-exact,
            % and the block reports zero noise power so no downstream accounting can
            % double-count it.
            snrTargets = [-3, 0, 10, 20];
            for snr = snrTargets
                ch = csrd.blocks.physical.channel.AWGNChannel( ...
                    'SNRdB', snr, 'Seed', 1234);
                cleanup = onCleanup(@() release(ch)); %#ok<NASGU>
                signal = (randn(50000, 1) + 1j * randn(50000, 1)) / sqrt(2);
                out = ch(signal);

                testCase.verifyEqual(out.Signal, signal, sprintf( ...
                    ['AWGNChannel must pass the waveform through BIT-EXACT at ', ...
                     'SNR %.1f dB. Any modification here happens before the ', ...
                     'measured planes are taken and would corrupt the labels.'], snr));
                testCase.verifyTrue(isfield(out, 'ChannelDeclaredSnrDb'), ...
                    'AWGNChannel must declare the target SNR it stands for.');
                testCase.verifyEqual(double(out.ChannelDeclaredSnrDb), double(snr), ...
                    'AbsTol', 1e-12, ...
                    'ChannelDeclaredSnrDb must carry the configured target verbatim.');
                testCase.verifyTrue(isfield(out, 'RequestedChannelNoisePowerW'), ...
                    'AWGNChannel must report its noise power so it can be audited.');
                testCase.verifyEqual(double(out.RequestedChannelNoisePowerW), 0, sprintf( ...
                    ['AWGNChannel must report ZERO realized noise power at SNR ', ...
                     '%.1f dB; a nonzero value here would be counted twice once ', ...
                     'the deferred injector runs.'], snr));
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
