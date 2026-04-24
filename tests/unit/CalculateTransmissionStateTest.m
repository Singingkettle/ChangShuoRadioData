classdef CalculateTransmissionStateTest < matlab.unittest.TestCase
    % CalculateTransmissionStateTest - Unit tests for transmission interval mapping.
    %
    %   Pins the audit fix that decouples frame->time mapping from a
    %   magic-number NumFrames=10 fallback.

    methods (Test)

        function frameDurationDrivesMapping(testCase)
            % FrameDuration takes priority over NumFrames/ObservationDuration.
            pattern = struct( ...
                'Intervals', [0.10, 0.20; 0.40, 0.60], ...
                'FrameDuration', 0.05, ...
                'NumFrames', 20, ...
                'ObservationDuration', 1.0);

            % frameId=3 -> t=0.10 -> inside first interval [0.10, 0.20)
            [isActive, idx, st, en] = csrd.utils.scenario.checkTransmissionInterval(3, pattern);
            testCase.verifyTrue(isActive);
            testCase.verifyEqual(idx, 1);
            testCase.verifyEqual(st, 0.10, 'AbsTol', 1e-12);
            testCase.verifyEqual(en, 0.20, 'AbsTol', 1e-12);

            % frameId=5 -> t=0.20 -> outside (right-open)
            [isActive5, ~, ~, ~] = csrd.utils.scenario.checkTransmissionInterval(5, pattern);
            testCase.verifyFalse(isActive5, 'Right-open interval must exclude endpoint.');

            % frameId=9 -> t=0.40 -> inside second interval
            [isActive9, idx9, ~, ~] = csrd.utils.scenario.checkTransmissionInterval(9, pattern);
            testCase.verifyTrue(isActive9);
            testCase.verifyEqual(idx9, 2);
        end

        function numFramesObservationFallback(testCase)
            % Without FrameDuration we should derive it from NumFrames.
            pattern = struct( ...
                'Intervals', [0.0, 0.5], ...
                'NumFrames', 10, ...
                'ObservationDuration', 1.0);
            [isActive_first, ~, ~, ~] = csrd.utils.scenario.checkTransmissionInterval(1, pattern);
            testCase.verifyTrue(isActive_first);
            [isActive_last, ~, ~, ~] = csrd.utils.scenario.checkTransmissionInterval(8, pattern);
            testCase.verifyFalse(isActive_last, 'Frame 8 -> t=0.7 should fall outside [0,0.5).');
        end

        function noMagicNumberFallback(testCase)
            % Audit pin: when neither FrameDuration nor (NumFrames+ObservationDuration)
            % are present, we must NOT silently use NumFrames=10. The function
            % must return isActive=false and emit a warning identifier.
            pattern = struct('Intervals', [0.0, 0.3]);
            warnState = warning('off', 'CSRD:Scenario:MissingFrameTiming');
            cleanupObj = onCleanup(@() warning(warnState)); %#ok<NASGU>

            lastwarn('');
            [isActive, ~, ~, ~] = csrd.utils.scenario.checkTransmissionInterval(2, pattern);
            [~, lastId] = lastwarn();
            testCase.verifyFalse(isActive);
            testCase.verifyEqual(lastId, 'CSRD:Scenario:MissingFrameTiming', ...
                'Missing timing fields must trigger CSRD:Scenario:MissingFrameTiming warning.');
        end

        function frameOutOfRangeWarns(testCase)
            pattern = struct( ...
                'Intervals', [0.0, 1.0], ...
                'NumFrames', 5, ...
                'ObservationDuration', 1.0);
            warnState = warning('off', 'CSRD:Scenario:FrameOutOfRange');
            cleanupObj = onCleanup(@() warning(warnState)); %#ok<NASGU>

            lastwarn('');
            csrd.utils.scenario.checkTransmissionInterval(99, pattern);
            [~, lastId] = lastwarn();
            testCase.verifyEqual(lastId, 'CSRD:Scenario:FrameOutOfRange', ...
                'Out-of-range frameId must surface a dedicated warning identifier.');
        end

    end

end
