classdef ChannelExceptionPropagationTest < matlab.unittest.TestCase
    % ChannelExceptionPropagationTest - Make sure scenario-skip identifiers
    % rethrow out of processChannelPropagation.
    %
    %   The scenario controller relies on identifier-based exceptions
    %   (CSRD:*:NoValidPaths, CSRD:*:NoBuildingData,
    %   CSRD:*:SkipScenario) to skip a corrupt scenario and move on. If
    %   processChannelPropagation swallows the exception, the
    %   SimulationRunner never sees it and produces half-corrupt frames
    %   instead of skipping. We approximate the behaviour with a small
    %   harness that mimics processChannelPropagation's catch block, so
    %   the test runs without standing up the entire ChangShuo runtime.

    methods (Test)

        function noValidPathsIsRethrown(testCase)
            f = @() ChannelExceptionPropagationTest.runHarness('CSRD:Channel:NoValidPaths', ...
                'no valid paths between Tx and Rx');
            testCase.verifyError(f, 'CSRD:Channel:NoValidPaths');
        end

        function noBuildingDataIsRethrown(testCase)
            f = @() ChannelExceptionPropagationTest.runHarness('CSRD:Map:NoBuildingData', ...
                'OSM payload contains no buildings');
            testCase.verifyError(f, 'CSRD:Map:NoBuildingData');
        end

        function explicitSkipScenarioIsRethrown(testCase)
            f = @() ChannelExceptionPropagationTest.runHarness('CSRD:Scenario:SkipScenario', ...
                'scenario must be skipped');
            testCase.verifyError(f, 'CSRD:Scenario:SkipScenario');
        end

        function unrelatedErrorIsRethrown(testCase)
            % Phase 5 removes the generic catch-swallow branch: a channel
            % bug must not degrade into a partial annotation.
            f = @() ChannelExceptionPropagationTest.runHarness( ...
                'CSRD:Channel:Generic', 'transient channel error');
            testCase.verifyError(f, 'CSRD:Channel:Generic');
        end

    end

    methods (Static, Access = private)

        function runHarness(identifier, message)
            % Replicate the catch / rethrow logic from
            % +csrd/+core/@ChangShuo/private/processChannelPropagation.m
            % so the contract can be tested without instantiating the
            % whole ChangShuo pipeline.
            try
                error(identifier, '%s', message);
            catch ME_channel
                if csrd.pipeline.scenario.isScenarioSkipException(ME_channel)
                    rethrow(ME_channel);
                end
                rethrow(ME_channel);
            end
        end

    end

end
