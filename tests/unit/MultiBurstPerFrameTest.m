classdef MultiBurstPerFrameTest < matlab.unittest.TestCase
    % MultiBurstPerFrameTest
    %
    % Phase 1 / A2: a single observation frame may overlap multiple
    % transmission intervals. The new behaviour:
    %
    %   * findOverlappingTransmissionIntervals returns ALL overlapping
    %     intervals using the "any overlap" rule:
    %         intervalEnd > frameStart AND intervalStart < frameEnd.
    %   * The legacy single-interval helper still returns the FIRST
    %     overlapping interval (preserving backward compat for callers
    %     that have not migrated yet) but the new helper is now the
    %     canonical source of truth for processing all overlaps.
    %
    % This test focuses on the utility behaviour. End-to-end propagation
    % into processSingleTransmitter is exercised by the regression smoke
    % test in tests/regression/test_phase1_dataflow_smoke.m.

    methods (Test)

        function emptyIntervalsReturnsEmpty(testCase)
            pattern = struct('FrameDuration', 0.01, 'NumFrames', 10, ...
                'Intervals', []);
            [idx, intervals, win] = ...
                csrd.pipeline.scenario.findOverlappingTransmissionIntervals(1, pattern);
            testCase.verifyEmpty(idx);
            testCase.verifyEqual(size(intervals), [0, 2]);
            testCase.verifyEqual(win, [0, 0], ...
                'frameWindow must default to zero when no intervals are present.');
        end

        function singleOverlapReportsExactlyOneInterval(testCase)
            pattern = struct( ...
                'FrameDuration', 0.01, 'NumFrames', 10, ...
                'Intervals', [0.005, 0.025; 0.05, 0.07]);
            % Frame 1 is [0, 0.01) -> overlaps interval 1 only (which
            % starts at 0.005, in the middle of the frame).
            [idx, intervals, win] = ...
                csrd.pipeline.scenario.findOverlappingTransmissionIntervals(1, pattern);
            testCase.verifyEqual(idx, 1);
            testCase.verifyEqual(intervals, [0.005, 0.010], 'AbsTol', 1e-12);
            testCase.verifyEqual(win, [0, 0.01], 'AbsTol', 1e-12);
        end

        function newHelperCatchesMidFrameStartLegacyMisses(testCase)
            % Phase 1 / A2 root cause: an interval that starts AFTER
            % frameStart but inside the frame was ignored by the legacy
            % "frameTime in [start, end)" rule (frameTime == frameStart).
            % The new helper MUST catch such intervals.
            pattern = struct( ...
                'FrameDuration', 0.01, 'NumFrames', 10, ...
                'Intervals', [0.005, 0.025]);
            [idx, ~, ~] = ...
                csrd.pipeline.scenario.findOverlappingTransmissionIntervals(1, pattern);
            testCase.verifyEqual(idx, 1, ...
                'Mid-frame-start interval must be caught by the overlap rule.');

            [legacyActive, ~] = ...
                csrd.pipeline.scenario.checkTransmissionInterval(1, pattern);
            testCase.verifyFalse(legacyActive, ...
                ['Sanity check: the legacy helper does NOT detect this ' ...
                 'mid-frame-start interval. This is the exact A2 defect ' ...
                 'the new helper repairs.']);
        end

        function multipleOverlapsCollected(testCase)
            % Frame duration = 0.01s, ten frames, total 0.1s.
            % Three short bursts inside frame 1 ([0, 0.01)):
            pattern = struct( ...
                'FrameDuration', 0.01, 'NumFrames', 10, ...
                'Intervals', [ ...
                    0.000, 0.002; ...   % interval 1 fully inside frame 1
                    0.003, 0.006; ...   % interval 2 fully inside frame 1
                    0.008, 0.012; ...   % interval 3 straddles frame 1/2 boundary
                    0.020, 0.025  ...   % interval 4 fully outside frame 1
                ]);
            [idx, intervals, win] = ...
                csrd.pipeline.scenario.findOverlappingTransmissionIntervals(1, pattern);
            testCase.verifyEqual(idx, [1, 2, 3], ...
                'All three overlapping intervals must be reported.');
            testCase.verifyEqual(intervals, ...
                [0.000, 0.002; 0.003, 0.006; 0.008, 0.010], 'AbsTol', 1e-12);
            testCase.verifyEqual(win, [0, 0.01], 'AbsTol', 1e-12);
        end

        function frame2OverlapsBoundaryStraddler(testCase)
            % The third interval straddles frame 1 -> frame 2 (0.008-0.012).
            % It MUST appear in BOTH frames' active sets.
            pattern = struct( ...
                'FrameDuration', 0.01, 'NumFrames', 10, ...
                'Intervals', [0.008, 0.012; 0.015, 0.018]);
            [idx1, ~, win1] = ...
                csrd.pipeline.scenario.findOverlappingTransmissionIntervals(1, pattern);
            [idx2, ~, win2] = ...
                csrd.pipeline.scenario.findOverlappingTransmissionIntervals(2, pattern);
            testCase.verifyTrue(any(idx1 == 1), 'Boundary interval missing from frame 1 active set.');
            testCase.verifyTrue(any(idx2 == 1), 'Boundary interval missing from frame 2 active set.');
            testCase.verifyEqual(win1, [0,    0.01], 'AbsTol', 1e-12);
            testCase.verifyEqual(win2, [0.01, 0.02], 'AbsTol', 1e-12);
        end

        function noOverlapReturnsEmpty(testCase)
            pattern = struct( ...
                'FrameDuration', 0.01, 'NumFrames', 10, ...
                'Intervals', [0.05, 0.07]);
            [idx, intervals, ~] = ...
                csrd.pipeline.scenario.findOverlappingTransmissionIntervals(1, pattern);
            testCase.verifyEmpty(idx);
            testCase.verifyEqual(size(intervals), [0, 2]);
        end

        function missingFrameTimingFailsFast(testCase)
            pattern = struct('Intervals', [0, 1]);
            testCase.verifyError(@() ...
                csrd.pipeline.scenario.findOverlappingTransmissionIntervals(1, pattern), ...
                'CSRD:Scenario:MissingFrameTiming');
        end

        function intervalEndOnFrameStartIsNotOverlap(testCase)
            % Half-open interval semantics: an interval that ENDS exactly
            % at frameStart is NOT overlapping the frame. This pins
            % down the tie-breaker so adjacent bursts are not double-
            % counted across consecutive frames.
            pattern = struct( ...
                'FrameDuration', 0.01, 'NumFrames', 5, ...
                'Intervals', [0.000, 0.010]);
            [idx2, ~, ~] = ...
                csrd.pipeline.scenario.findOverlappingTransmissionIntervals(2, pattern);
            testCase.verifyEmpty(idx2, ...
                'Interval ending exactly at frameStart must NOT count as overlap.');

            [idx1, ~, ~] = ...
                csrd.pipeline.scenario.findOverlappingTransmissionIntervals(1, pattern);
            testCase.verifyEqual(idx1, 1, ...
                'Same interval still belongs to frame 1.');
        end

    end

end
