classdef CalculateTransmissionStateTest < matlab.unittest.TestCase
    % CalculateTransmissionStateTest - Decouple frameTime from a hardcoded
    % NumFrames default.
    %
    %   Earlier versions of the helper assumed NumFrames = 10 when the field
    %   was missing, which silently misaligned every Burst / Scheduled /
    %   Random temporal pattern when the engine ran a different frame count.
    %   These tests cover the modern csrd.utils.scenario.checkTransmissionInterval
    %   contract: prefer FrameDuration, fall back to ObservationDuration /
    %   NumFrames, never invent a magic number.

    methods (Test)

        function frameDurationOverridesEverything(testCase)
            pattern = struct( ...
                'Intervals', [0.5, 1.0; 1.5, 2.0], ...
                'FrameDuration', 0.1, ...
                'NumFrames', 100, ...           % stale planner value
                'ObservationDuration', 5);      % stale planner value
            % frame 6 -> t = 0.5s -> active in interval 1
            [active, idx, s, e] = csrd.utils.scenario.checkTransmissionInterval(6, pattern);
            testCase.verifyTrue(active);
            testCase.verifyEqual(idx, 1);
            testCase.verifyEqual(s, 0.5);
            testCase.verifyEqual(e, 1.0);

            % frame 11 -> t = 1.0s -> NOT in any interval (right-open)
            [active, ~, ~, ~] = csrd.utils.scenario.checkTransmissionInterval(11, pattern);
            testCase.verifyFalse(active);

            % frame 16 -> t = 1.5s -> active in interval 2
            [active, idx, s, e] = csrd.utils.scenario.checkTransmissionInterval(16, pattern);
            testCase.verifyTrue(active);
            testCase.verifyEqual(idx, 2);
            testCase.verifyEqual(s, 1.5);
            testCase.verifyEqual(e, 2.0);
        end

        function fallbackUsesObservationDurationAndNumFrames(testCase)
            pattern = struct( ...
                'Intervals', [0, 1.0; 2.0, 3.0], ...
                'NumFrames', 30, ...
                'ObservationDuration', 3);
            % FrameDuration = 0.1s, frame 5 -> t = 0.4s -> active in interval 1
            [active, idx] = csrd.utils.scenario.checkTransmissionInterval(5, pattern);
            testCase.verifyTrue(active);
            testCase.verifyEqual(idx, 1);

            % frame 25 -> t = 2.4s -> active in interval 2
            [active, idx] = csrd.utils.scenario.checkTransmissionInterval(25, pattern);
            testCase.verifyTrue(active);
            testCase.verifyEqual(idx, 2);
        end

        function noTimingFieldsReturnsInactiveAndWarns(testCase)
            pattern = struct('Intervals', [0, 1.0]); % no NumFrames or FrameDuration
            warningState = warning('off', 'CSRD:Scenario:MissingFrameTiming');
            cleanup = onCleanup(@() warning(warningState)); %#ok<NASGU>
            [active, idx, s, e] = csrd.utils.scenario.checkTransmissionInterval(1, pattern);
            testCase.verifyFalse(active, ...
                'Without timing info the helper must NOT silently say "active".');
            testCase.verifyEqual(idx, 0);
            testCase.verifyEqual(s, 0);
            testCase.verifyEqual(e, 0);
        end

        function emptyIntervalsReturnsInactive(testCase)
            pattern = struct('Intervals', [], 'FrameDuration', 0.1);
            [active, idx] = csrd.utils.scenario.checkTransmissionInterval(1, pattern);
            testCase.verifyFalse(active);
            testCase.verifyEqual(idx, 0);
        end

        function frameOutsideNumFramesIssuesWarning(testCase)
            pattern = struct( ...
                'Intervals', [0, 10], ...
                'FrameDuration', 0.1, ...
                'NumFrames', 5);
            testCase.verifyWarning(@() ...
                csrd.utils.scenario.checkTransmissionInterval(99, pattern), ...
                'CSRD:Scenario:FrameOutOfRange');
        end

    end

end
