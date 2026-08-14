classdef BurstRampTest < matlab.unittest.TestCase
    % BurstRampTest - the opt-in raised-cosine burst-edge contract.
    %
    %   gateToDuration's RampSeconds option shapes the ACTIVE region's two
    %   edges with a half-Hann ramp. A rectangular burst edge is a step whose
    %   spectral splatter falls off only as 1/f from a 10/T corner, and for
    %   short narrowband bursts that splatter -- not the modulation -- set
    %   the measured occupied bandwidth. These cases pin: the zero default is
    %   bit-identical (every existing gating call keeps its exact output),
    %   the ramp touches only the active region (zero padding is an
    %   observation artifact, not a transmission), the 10% clamp and the
    %   8-sample skip, and the splatter actually collapsing.

    methods (Test)

        function zeroDefaultIsBitIdentical(testCase)
            s = BurstRampTest.makeBurst(1000, 2000);
            plain = csrd.pipeline.signal.gateToDuration(s, 2000 / 1e6, 'stage');
            explicit = csrd.pipeline.signal.gateToDuration(s, 2000 / 1e6, ...
                'stage', 'RampSeconds', 0);
            testCase.verifyEqual(explicit.Signal, plain.Signal, ...
                'RampSeconds = 0 must be exactly the unramped behavior.');
        end

        function rampTouchesOnlyTheActiveRegion(testCase)
            % 1000 active samples padded to 2000: the ramp must scale the
            % first/last ramp samples of the ACTIVE region, leave its middle
            % untouched, and keep the padding exactly zero.
            s = BurstRampTest.makeBurst(1000, 0);   % no pre-padding
            rampSec = 10 / 1e6;                     % 10 samples at 1 MHz
            out = csrd.pipeline.signal.gateToDuration(s, 2000 / 1e6, ...
                'stage', 'RampSeconds', rampSec);
            y = out.Signal; x = s.Signal;

            info = out.SignalGating.stage;
            testCase.verifyEqual(info.RampSamplesApplied, 10, ...
                'A 10-sample ramp fits well under the 10% clamp.');
            % Middle untouched (bit-identical).
            testCase.verifyEqual(y(11:990), x(11:990), ...
                'The ramp must not touch the interior of the burst.');
            % Edges scaled by the half-Hann weights.
            w = 0.5 * (1 - cos(pi * (0:9)' / 10));
            testCase.verifyEqual(y(1:10), x(1:10) .* w, 'AbsTol', 1e-15, ...
                'Leading edge must carry the raised-cosine ramp.');
            testCase.verifyEqual(y(991:1000), x(991:1000) .* flipud(w), ...
                'AbsTol', 1e-15, ...
                'Trailing edge must carry the mirrored ramp.');
            % Padding exactly zero (magnitude check -- indexing an all-zero
            % complex block may demote it to real).
            testCase.verifyEqual(max(abs(y(1001:2000))), 0, ...
                'Padding must remain exactly zero.');
        end

        function rampClampsAndSkipsMicroBursts(testCase)
            % A requested ramp longer than 10% of the burst clamps; a burst
            % under 8 active samples is left untouched.
            s = BurstRampTest.makeBurst(50, 0);
            out = csrd.pipeline.signal.gateToDuration(s, 50 / 1e6, ...
                'stage', 'RampSeconds', 1);   % absurdly long request
            testCase.verifyEqual(out.SignalGating.stage.RampSamplesApplied, 5, ...
                'The ramp must clamp to 10% of the active length.');

            tiny = BurstRampTest.makeBurst(7, 0);
            outTiny = csrd.pipeline.signal.gateToDuration(tiny, 7 / 1e6, ...
                'stage', 'RampSeconds', 1);
            testCase.verifyEqual(outTiny.Signal, tiny.Signal, ...
                'Bursts under 8 active samples must pass through unramped.');
            testCase.verifyEqual(outTiny.SignalGating.stage.RampSamplesApplied, 0);
        end

        function rampCollapsesTheEdgeSplatter(testCase)
            % The outcome case: a narrowband tone burst inside a longer
            % window. Rectangular edges splatter the 99% band far past the
            % tone; the ramped burst must read several times narrower.
            Fs = 1e6; n = 4000; active = 1000;
            s = struct('Signal', exp(2i * pi * 5e3 * (0:active - 1)' / Fs), ...
                'SampleRate', Fs);
            rect = csrd.pipeline.signal.gateToDuration(s, n / Fs, 'stage');
            ramped = csrd.pipeline.signal.gateToDuration(s, n / Fs, ...
                'stage', 'RampSeconds', 100 / Fs);
            bwRect = obw(rect.Signal, Fs);
            bwRamped = obw(ramped.Signal, Fs);
            % Measured on this fixture: 20.5 kHz rectangular vs 7.7 kHz with
            % the 10%-clamped ramp, a 2.7x collapse (the residual width is
            % the burst's own 1/T mainlobe, which no edge shaping removes).
            testCase.verifyLessThan(bwRamped, bwRect / 2.5, sprintf( ...
                ['Ramped burst reads %.0f Hz vs rectangular %.0f Hz; the ', ...
                 'edge splatter must collapse by well over 2.5x.'], ...
                bwRamped, bwRect));
        end

    end

    methods (Static)

        function s = makeBurst(activeSamples, padSamples)
            % makeBurst - a complex tone burst struct for gating tests.
            % Inputs: activeSamples - burst length; padSamples - trailing zeros.
            % Outputs: s - struct with Signal (column) and SampleRate 1 MHz.
            Fs = 1e6;
            x = exp(2i * pi * 20e3 * (0:activeSamples - 1)' / Fs);
            s = struct('Signal', [x; complex(zeros(padSamples, 1))], ...
                'SampleRate', Fs);
        end

    end

end
