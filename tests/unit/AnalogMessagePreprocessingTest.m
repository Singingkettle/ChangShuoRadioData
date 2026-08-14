classdef AnalogMessagePreprocessingTest < matlab.unittest.TestCase
    % AnalogMessagePreprocessingTest - the analog message-conditioning contract.
    %
    %   BaseModulator.prepareAnalogMessage is the coupling between an analog
    %   emission and its allocated channel: it resamples the message from its
    %   NATIVE rate onto the modulator grid, low-passes it to the family's
    %   share of TargetBandwidth, removes DC, and normalizes the level to the
    %   family's index convention. Each case here pins one of those against
    %   the measured defect it removes:
    %     * rate reinterpretation (audio at 44.1 kHz read at the modulator
    %       rate scaled the message spectrum by SampleRate/44.1 kHz -- DSBAM
    %       read 3.9x its allocation on CLEAN output),
    %     * FM carrier drift (audio DC -> cumsum phase ramp -> constant
    %       frequency offset corrupting CenterFrequencyHz),
    %     * allocation overrun (19 kHz audio content on a 12.5 kHz channel),
    %     * the VSBAM vestigial ramp that previously was dead code.

    methods (Test)

        function resamplePutsTheMessageOnTheModulatorGrid(testCase)
            % A 3.4 kHz tone recorded at 44.1 kHz must still be a 3.4 kHz
            % tone after modulation at Fs = 256 kHz. Reinterpreting the
            % samples on the modulator grid would move it to
            % 3.4 kHz * 256/44.1 ~ 19.7 kHz.
            fsAudio = 44100; toneHz = 3400;
            message = sin(2 * pi * toneHz * (0:8191)' / fsAudio);

            mod = csrd.blocks.physical.modulate.analog.AM.DSBSCAM();
            mod.SampleRate = 256e3;
            mod.SamplePerSymbol = 32;
            mod.TargetBandwidth = 10e3;
            out = step(mod, struct('data', message, ...
                'MessageSampleRate', fsAudio));

            spec = abs(fft(out.Signal(:)));
            n = numel(spec);
            [~, peakBin] = max(spec(1:floor(n / 2)));
            peakHz = (peakBin - 1) * mod.SampleRate / n;
            testCase.verifyEqual(peakHz, toneHz, 'AbsTol', 200, sprintf( ...
                ['The message tone must stay at %.0f Hz on the modulator ', ...
                 'grid; it appeared at %.0f Hz (a reinterpreted grid would ', ...
                 'put it near 19.7 kHz).'], toneHz, peakHz));
        end

        function dcFreeMessageKeepsFmOnItsCenter(testCase)
            % FM integrates the message, so message DC becomes a CONSTANT
            % frequency offset: Delta_f * dc. Drive FM with a strongly biased
            % message and require the realized spectrum centroid to stay on
            % the carrier.
            fsAudio = 44100;
            message = 1 + 0.5 * sin(2 * pi * 1000 * (0:8191)' / fsAudio);

            mod = csrd.blocks.physical.modulate.analog.FM.FM();
            mod.SampleRate = 200e3;
            mod.SamplePerSymbol = 8;
            mod.TargetBandwidth = 100e3;
            out = step(mod, struct('data', message, ...
                'MessageSampleRate', fsAudio));

            spec = fftshift(abs(fft(out.Signal(:))) .^ 2);
            n = numel(spec);
            freqAxis = ((0:n - 1)' - n / 2) * mod.SampleRate / n;
            centroidHz = sum(freqAxis .* spec) / sum(spec);
            % Without DC removal the offset is Delta_f * dc ~ 33 kHz * (1/1.5).
            testCase.verifyLessThan(abs(centroidHz), 2e3, sprintf( ...
                ['FM spectrum centroid sits %.0f Hz off carrier; message DC ', ...
                 'must not become a frequency offset.'], centroidHz));
        end

        function lowpassKeepsFmInsideANarrowChannel(testCase)
            % The narrowband worst case from the audit: a 12.5 kHz channel
            % whose audio message content (up to ~19 kHz after the rate fix)
            % is WIDER than the whole channel. The family low-pass (W = BW/6)
            % plus the planner deviation rule (Delta_f = BW/3) must realize
            % Carson's 2*(Delta_f + W) = BW.
            rng(6);
            fsAudio = 44100;
            message = randn(16384, 1);   % full-band audio-like content

            mod = csrd.blocks.physical.modulate.analog.FM.FM();
            mod.SampleRate = 250e3;
            mod.SamplePerSymbol = 20;
            mod.TargetBandwidth = 12.5e3;
            out = step(mod, struct('data', message, ...
                'MessageSampleRate', fsAudio));

            emissionBw = obw(out.Signal(:), mod.SampleRate);
            testCase.verifyLessThanOrEqual(emissionBw, 1.15 * 12.5e3, sprintf( ...
                ['FM on a 12.5 kHz allocation emitted %.0f Hz; the message ', ...
                 'low-pass (BW/6) + derived deviation (BW/3) must keep ', ...
                 'Carson''s band inside the channel.'], emissionBw));
        end

        function fmDerivesItsDeviationFromTheAllocation(testCase)
            % No free-standing 5-75 kHz deviation draw: absent an explicit
            % config, the deviation must be TargetBandwidth/3 (the planner's
            % Carson beta = 2 rule).
            mod = csrd.blocks.physical.modulate.analog.FM.FM();
            mod.SampleRate = 200e3;
            mod.SamplePerSymbol = 8;
            mod.TargetBandwidth = 120e3;
            out = step(mod, struct( ...
                'data', sin(2 * pi * 1000 * (0:4095)' / 44100), ...
                'MessageSampleRate', 44100));
            testCase.verifyEqual(out.ModulatorConfig.FrequencyDeviation, ...
                40e3, 'AbsTol', 1e-9, ...
                'FM deviation must derive as TargetBandwidth/3.');
        end

        function normalizationFollowsTheFamilyIndexConvention(testCase)
            % DSBAM ('peak'): with |m| <= 1 and carramp >= 1 the baseband
            % envelope m + carramp never crosses zero -- the drawn carrier
            % amplitude keeps its envelope-detection meaning. DSBSCAM
            % ('power'): unit-RMS baseband, the TRF DC-offset convention.
            rng(8);
            fsAudio = 44100;
            message = 5 * randn(8192, 1) + 3;   % wild scale + DC on purpose

            am = csrd.blocks.physical.modulate.analog.AM.DSBAM();
            am.SampleRate = 256e3; am.SamplePerSymbol = 32;
            am.TargetBandwidth = 25e3;
            outAm = step(am, struct('data', message, ...
                'MessageSampleRate', fsAudio));
            envelope = real(outAm.Signal(:));
            testCase.verifyGreaterThan(min(envelope), 0, ...
                ['Peak-normalized message + carramp >= 1 must keep the ', ...
                 'DSBAM envelope positive (no overmodulation).']);

            sc = csrd.blocks.physical.modulate.analog.AM.DSBSCAM();
            sc.SampleRate = 256e3; sc.SamplePerSymbol = 32;
            sc.TargetBandwidth = 25e3;
            outSc = step(sc, struct('data', message, ...
                'MessageSampleRate', fsAudio));
            rmsLevel = sqrt(mean(abs(outSc.Signal(:)) .^ 2));
            testCase.verifyEqual(rmsLevel, 1, 'AbsTol', 0.05, ...
                'DSBSCAM baseband must be unit-RMS (power normalization).');
        end

        function vestigialRampActuallyShapesTheVestige(testCase)
            % The vestigial ramp was dead code (branch order made the filter
            % a brick wall at -cutoff, reachable only at f == -cutoff
            % exactly). For a tone INSIDE the vestige region the ramp
            % partially suppresses the mirror sideband:
            % pos/neg = ((1+f0/c)/(1-f0/c))^2 ~ 12 dB for f0 = 3 kHz,
            % c = 5 kHz. The dead-ramp brick wall left the tone fully
            % double-sideband (~0 dB).
            Fs = 200e3; f0 = 3e3; cutoffHz = 5e3;
            message = sin(2 * pi * f0 * (0:4095)' / Fs);

            mod = csrd.blocks.physical.modulate.analog.AM.VSBAM();
            mod.SampleRate = Fs;
            mod.ModulatorConfig.mode = 'upper';
            mod.ModulatorConfig.cutoff = cutoffHz;
            handle = mod.genModulatorHandle();
            sig = handle(message);

            spec = fftshift(fft(sig));
            n = numel(spec);
            posPower = sum(abs(spec(n / 2 + 2:end)) .^ 2);
            negPower = sum(abs(spec(1:n / 2)) .^ 2);
            ratioDb = 10 * log10(posPower / max(negPower, eps));
            testCase.verifyGreaterThan(ratioDb, 6, sprintf( ...
                ['A tone inside the vestige must be PARTIALLY suppressed ', ...
                 'on the mirror side (~12 dB expected, got %.1f dB; ~0 dB ', ...
                 'means the ramp is dead again).'], ratioDb));
            testCase.verifyLessThan(ratioDb, 20, sprintf( ...
                ['A tone inside the vestige must not be FULLY suppressed ', ...
                 '(~12 dB expected, got %.1f dB; >20 dB means the vestige ', ...
                 'became a brick wall / pure SSB).'], ratioDb));
        end

    end
end
