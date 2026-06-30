classdef FramePlaneTimeOccupancyTest < matlab.unittest.TestCase
    % FramePlaneTimeOccupancyTest
    %
    % The combined-frame TimeOccupancy must report the real sub-frame fraction.
    % The envelope detector's default window is min(1e-4 s, frameDuration); every
    % frame is < 1e-4 s, so the default collapses to a single whole-frame window
    % and TimeOccupancy degenerates to a constant 1.0 for every frame. The
    % FramePlane measurement now passes an explicit ~1/32-frame envelope window so
    % a partially-occupied frame reports a real fraction.

    methods (Test)

        function subFrameWindowReportsPartialOccupancy(testCase)
            fs = 50e6;
            n = 4096;                       % 81.9 us frame, < 1e-4 s
            frameDur = n / fs;
            % a burst occupying only the first 20% of the frame
            sig = complex(zeros(n, 1));
            active = round(0.2 * n);
            sig(1:active) = exp(1j * 2 * pi * 1e6 * (0:active - 1)' / fs);

            % default window -> degenerate 1.0 (the bug)
            sDefault = csrd.pipeline.measurement.measureSignalSummary(sig, fs, fs);
            testCase.verifyEqual(sDefault.TimeOccupancy, 1, 'AbsTol', 1e-6, ...
                'sanity: the default whole-frame window reports the degenerate 1.0');

            % explicit sub-frame window -> ~0.2 (the fix)
            sFixed = csrd.pipeline.measurement.measureSignalSummary(sig, fs, fs, ...
                'EnvelopeOptions', struct('WindowSec', frameDur / 32));
            testCase.verifyEqual(sFixed.TimeOccupancy, 0.2, 'AbsTol', 0.06, ...
                'sub-frame window must report the ~20% real occupancy');

            % a fully-active frame still reads ~1.0 under the same window
            full = exp(1j * 2 * pi * 1e6 * (0:n - 1)' / fs);
            sFull = csrd.pipeline.measurement.measureSignalSummary(full, fs, fs, ...
                'EnvelopeOptions', struct('WindowSec', frameDur / 32));
            testCase.verifyGreaterThan(sFull.TimeOccupancy, 0.9, ...
                'a fully-active frame must still read ~1.0');
        end

    end
end
