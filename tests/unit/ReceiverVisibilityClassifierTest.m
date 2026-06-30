classdef ReceiverVisibilityClassifierTest < matlab.unittest.TestCase
    % ReceiverVisibilityClassifierTest
    %
    % Pins CommunicationBehaviorSimulator.classifyEmitterVisibility, which
    % decides InBand/EdgeClipped/OutOfBand by the overlap of the emitter band
    % with the receiver observable window. The classifier must be correct for an
    % asymmetric (non-0-centred) window -- the previous abs(offset) +/- halfBw
    % vs half-width test silently assumed a 0-centred window.

    methods (Test)

        function symmetricWindowClassifies(testCase)
            cls = @csrd.blocks.scenario.CommunicationBehaviorSimulator.classifyEmitterVisibility;
            win = [-25e6, 25e6];
            [v, r] = cls(-5e6, 5e6, win);
            testCase.verifyTrue(v); testCase.verifyEqual(r, 'InBand');
            [v, r] = cls(20e6, 30e6, win);
            testCase.verifyFalse(v); testCase.verifyEqual(r, 'EdgeClipped');
            [v, r] = cls(30e6, 40e6, win);
            testCase.verifyFalse(v); testCase.verifyEqual(r, 'OutOfBand');
        end

        function asymmetricWindowClassifies(testCase)
            % Window centred on +25 MHz, not 0. The fix must classify by overlap
            % with [0, 50e6] directly.
            cls = @csrd.blocks.scenario.CommunicationBehaviorSimulator.classifyEmitterVisibility;
            win = [0, 50e6];
            % fully inside the window
            [v, r] = cls(10e6, 20e6, win);
            testCase.verifyTrue(v); testCase.verifyEqual(r, 'InBand');
            % straddles the lower edge (0) -- half of the band is outside
            [v, r] = cls(-5e6, 5e6, win);
            testCase.verifyFalse(v); testCase.verifyEqual(r, 'EdgeClipped');
            % entirely below the window
            [v, r] = cls(-20e6, -10e6, win);
            testCase.verifyFalse(v); testCase.verifyEqual(r, 'OutOfBand');
            % straddles the upper edge (50 MHz)
            [v, r] = cls(45e6, 55e6, win);
            testCase.verifyFalse(v); testCase.verifyEqual(r, 'EdgeClipped');
            % The pre-fix abs()-based test would have called the [-5,5] MHz
            % emitter InBand for this window (abs(0)+5e6 <= halfWidth 25e6),
            % which is wrong -- half the band lies below the window's 0 edge.
        end

    end
end
