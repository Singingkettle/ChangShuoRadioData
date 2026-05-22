classdef PhysicalTimeStepContractTest < matlab.unittest.TestCase
    % PhysicalTimeStepContractTest

    methods (Test)

        function movementUsesFrameDuration(testCase)
            frameDuration = 1024 / 50e6;
            cfg = localPhysicalConfig(frameDuration);
            sim = csrd.blocks.scenario.PhysicalEnvironmentSimulator('Config', cfg);

            entities1 = step(sim, 1);
            entities2 = step(sim, 2);

            tx1 = entities1(strcmp({entities1.ID}, 'Tx1'));
            tx2 = entities2(strcmp({entities2.ID}, 'Tx1'));
            expectedPosition = tx1.Position + tx1.Velocity * frameDuration;

            testCase.verifyEqual(tx2.Position, expectedPosition, ...
                'AbsTol', 1e-9);
            testCase.verifyEqual(sim.getTimeResolution(), frameDuration, ...
                'AbsTol', 1e-15);
        end

        function missingTimeResolutionFailsFast(testCase)
            cfg = localPhysicalConfig([]);
            testCase.verifyError(@() ...
                setup(csrd.blocks.scenario.PhysicalEnvironmentSimulator('Config', cfg)), ...
                'CSRD:PhysicalEnvironment:MissingTimeResolution');
        end

    end
end

function cfg = localPhysicalConfig(timeResolution)
cfg = struct();
cfg.TimeResolution = timeResolution;
cfg.Map.Type = 'Grid';
cfg.Map.Boundaries = [-1e6, 1e6, -1e6, 1e6];
cfg.Map.Resolution = 100;
cfg.Entities.Transmitters.Count = struct('Min', 1, 'Max', 1);
cfg.Entities.Transmitters.Mobility.Model = 'Stationary';
cfg.Entities.Transmitters.Mobility.MaxSpeedMps = 15;
cfg.Entities.Receivers.Count = struct('Min', 1, 'Max', 1);
cfg.Entities.Receivers.Mobility.Model = 'Stationary';
cfg.Entities.Receivers.Mobility.MaxSpeedMps = 0;
cfg.Environment.Weather.Enable = false;
cfg.Environment.Obstacles.Enable = false;
cfg.Mobility.EnableCollisionAvoidance = false;
cfg.Global.NumFramesPerScenario = 2;
end
