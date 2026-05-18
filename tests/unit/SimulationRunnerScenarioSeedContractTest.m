classdef SimulationRunnerScenarioSeedContractTest < matlab.unittest.TestCase
    %SIMULATIONRUNNERSCENARIOSEEDCONTRACTTEST Scenario RNG is global-ID based.

    methods (Test)
        function globalScenarioIdsDoNotShareWorkerRandomStream(testCase)
            baseSeed = 1820147851;
            scenarioIds = [1106, 2106, 3106];

            seeds = arrayfun(@(sid) ...
                csrd.SimulationRunner.deriveScenarioSeed(baseSeed, sid), ...
                scenarioIds);

            testCase.verifyEqual(numel(unique(seeds)), numel(seeds), ...
                'Different global ScenarioId values must not share RNG seeds.');

            draws = zeros(numel(scenarioIds), 4);
            for idx = 1:numel(scenarioIds)
                rng(seeds(idx), 'twister');
                draws(idx, :) = rand(1, 4);
            end

            testCase.verifyNotEqual(draws(1, :), draws(2, :), ...
                'Worker-offset scenario IDs must not generate duplicate random draws.');
            testCase.verifyNotEqual(draws(2, :), draws(3, :), ...
                'Worker-offset scenario IDs must not generate duplicate random draws.');
        end

        function scenarioSeedIsReplayStable(testCase)
            baseSeed = 769092052;
            scenarioId = 3626;

            seedA = csrd.SimulationRunner.deriveScenarioSeed(baseSeed, scenarioId);
            seedB = csrd.SimulationRunner.deriveScenarioSeed(baseSeed, scenarioId);

            testCase.verifyEqual(seedA, seedB);

            rng(seedA, 'twister');
            first = rand(1, 8);
            rng(seedB, 'twister');
            second = rand(1, 8);

            testCase.verifyEqual(first, second, 'AbsTol', 0);
        end

        function workerScenarioIdsUseRoundRobinGlobalSchedule(testCase)
            ids1 = csrd.SimulationRunner.deriveScenarioIdsForWorker(10, 1, 4);
            ids2 = csrd.SimulationRunner.deriveScenarioIdsForWorker(10, 2, 4);
            ids3 = csrd.SimulationRunner.deriveScenarioIdsForWorker(10, 3, 4);
            ids4 = csrd.SimulationRunner.deriveScenarioIdsForWorker(10, 4, 4);

            testCase.verifyEqual(ids1, [1 5 9]);
            testCase.verifyEqual(ids2, [2 6 10]);
            testCase.verifyEqual(ids3, [3 7]);
            testCase.verifyEqual(ids4, [4 8]);

            allIds = sort([ids1 ids2 ids3 ids4]);
            testCase.verifyEqual(allIds, 1:10, ...
                'Round-robin scheduling must cover each global ScenarioId exactly once.');
        end
    end
end
