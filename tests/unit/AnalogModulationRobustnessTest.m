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
            % and assert each returns a finite positive Bandwidth.
            for k = 1:numel(testCase.AnalogModulators)
                handle = testCase.AnalogModulators{k};
                mod = feval(handle);
                mod.SampleRate = 260000;
                mod.SamplePerSymbol = 13;
                input = struct('data', sin(2 * pi * 1000 * (0:63)' / mod.SampleRate));
                out = step(mod, input);
                bw = out.Bandwidth;
                testCase.verifyTrue(all(isfinite(bw(:))), ...
                    sprintf('%s emitted a non-finite Bandwidth on a short message.', handle));
                testCase.verifyGreaterThan(max(abs(bw(:))), 0, ...
                    sprintf('%s emitted a zero Bandwidth on a short message.', handle));
            end
        end

    end
end
