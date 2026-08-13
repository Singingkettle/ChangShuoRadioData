classdef AnalogModulationRobustnessTest < matlab.unittest.TestCase
    %ANALOGMODULATIONROBUSTNESSTEST Analog modulators never emit a bad bandwidth.
    %
    % Narrowband analog services (e.g. aeronautical/maritime VHF) combined with
    % short observation windows drive the message length down to its 64-sample
    % minimum, where MATLAB obw() returns NaN. A near-silent audio segment can
    % also collapse obw() to 0. Either case previously made the analog
    % modulators emit a non-finite/zero Bandwidth and hard-fail the pipeline.
    % These tests pin the robust behaviour so that regression cannot return.

    properties (Constant)
        AnalogModulators = { ...
            'csrd.blocks.physical.modulate.analog.FM.FM', ...
            'csrd.blocks.physical.modulate.analog.PM.PM', ...
            'csrd.blocks.physical.modulate.analog.AM.DSBAM', ...
            'csrd.blocks.physical.modulate.analog.AM.DSBSCAM', ...
            'csrd.blocks.physical.modulate.analog.AM.SSBAM', ...
            'csrd.blocks.physical.modulate.analog.AM.VSBAM'};
    end

    methods (Test)

        function occupiedBandwidthFloorsDegenerateInput(testCase)
            fs = 260000;
            % A 64-sample message makes obw() return NaN; the helper must floor.
            short = sin(2 * pi * 1000 * (0:63)' / fs);
            bw = csrd.support.modulation.occupiedBandwidthHz(short, fs);
            testCase.verifyTrue(isfinite(bw) && bw > 0, ...
                'Degenerate (short) input must yield a finite positive bandwidth.');

            % A constant (DC / silent) message collapses obw() to 0.
            silent = zeros(2048, 1);
            bwSilent = csrd.support.modulation.occupiedBandwidthHz(silent, fs);
            testCase.verifyTrue(isfinite(bwSilent) && bwSilent > 0, ...
                'Silent input must yield a finite positive bandwidth.');
        end

        function occupiedBandwidthMatchesObwForNormalInput(testCase)
            fs = 260000;
            x = sin(2 * pi * 5000 * (0:4095)' / fs) + ...
                0.5 * sin(2 * pi * 12000 * (0:4095)' / fs);
            testCase.verifyEqual( ...
                csrd.support.modulation.occupiedBandwidthHz(x, fs), ...
                obw(x, fs), 'AbsTol', 1e-6, ...
                'For a well-formed signal the helper must equal obw().');
        end

        function allAnalogModulatorsSurviveShortMessage(testCase)
            % Drive every analog modulator with the 64-sample minimum message
            % and assert each returns a finite positive Bandwidth. The fixture
            % carries the full analog input contract (MessageSampleRate +
            % TargetBandwidth): the preprocessing skips its low-pass on
            % buffers this short, and the degenerate-obw floor must still
            % hold downstream of it.
            for k = 1:numel(testCase.AnalogModulators)
                handle = testCase.AnalogModulators{k};
                mod = feval(handle);
                mod.SampleRate = 260000;
                mod.SamplePerSymbol = 13;
                mod.TargetBandwidth = 25e3;   % aeronautical-band allocation
                input = struct( ...
                    'data', sin(2 * pi * 1000 * (0:63)' / mod.SampleRate), ...
                    'MessageSampleRate', mod.SampleRate);
                out = step(mod, input);
                bw = out.Bandwidth;
                testCase.verifyTrue(all(isfinite(bw(:))), ...
                    sprintf('%s emitted a non-finite Bandwidth on a short message.', handle));
                testCase.verifyGreaterThan(max(abs(bw(:))), 0, ...
                    sprintf('%s emitted a zero Bandwidth on a short message.', handle));
            end
        end

        function analogModulatorsRefuseAMessageWithoutItsRate(testCase)
            % The rate is the coupling: a message that does not declare its
            % native sample rate gets silently reinterpreted on the modulator
            % grid (the audio-44.1 kHz defect). Analog modulators must refuse.
            mod = feval(testCase.AnalogModulators{1});
            mod.SampleRate = 260000;
            mod.SamplePerSymbol = 13;
            mod.TargetBandwidth = 25e3;
            input = struct('data', sin(2 * pi * 1000 * (0:1023)' / 44100));
            testCase.verifyError(@() step(mod, input), ...
                'CSRD:Modulation:MissingMessageSampleRate');
        end

        function preprocessedMessageStaysInsideTheAllocation(testCase)
            % The outcome contract: a full-band 44.1 kHz audio-like message on
            % a 25 kHz aeronautical AM channel must come out of the modulator
            % occupying <= its allocation (the DSB message share is
            % allocation/2; the emission is 2x the message). Before the
            % preprocessing existed, this exact configuration read ~3.9x the
            % allocation on CLEAN modulator output.
            rng(4);
            allocationHz = 25e3;
            fsAudio = 44100;
            % Broadband message: white noise occupies the full audio Nyquist.
            message = randn(8192, 1);

            mod = csrd.blocks.physical.modulate.analog.AM.DSBAM();
            mod.SampleRate = 260000;   % Rs = 20 kHz x SPS = 13 (planner shape)
            mod.SamplePerSymbol = 13;
            mod.TargetBandwidth = allocationHz;
            out = step(mod, struct('data', message, ...
                'MessageSampleRate', fsAudio));

            emissionBw = out.Bandwidth;
            if numel(emissionBw) == 2
                emissionBw = emissionBw(2) - emissionBw(1);
            end
            testCase.verifyLessThanOrEqual(emissionBw, 1.1 * allocationHz, ...
                sprintf(['DSBAM emitted %.0f Hz on a %.0f Hz allocation; the ', ...
                'message low-pass must keep the emission inside its channel.'], ...
                emissionBw, allocationHz));
        end

    end
end
