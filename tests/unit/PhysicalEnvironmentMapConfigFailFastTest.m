classdef PhysicalEnvironmentMapConfigFailFastTest < matlab.unittest.TestCase
    % PhysicalEnvironmentMapConfigFailFastTest

    methods (Test)

        function missingMapTypeFailsFast(testCase)
            cfg = localBaseConfig();
            cfg = rmfield(cfg, 'Map');

            testCase.verifyError(@() ...
                setup(csrd.blocks.scenario.PhysicalEnvironmentSimulator('Config', cfg)), ...
                'CSRD:Scenario:MissingMapType');
        end

        function unsupportedMapTypeFailsFast(testCase)
            cfg = localBaseConfig();
            cfg.Map.Type = 'UnknownMap';

            testCase.verifyError(@() ...
                setup(csrd.blocks.scenario.PhysicalEnvironmentSimulator('Config', cfg)), ...
                'CSRD:Scenario:UnsupportedMapType');
        end

    end
end

function cfg = localBaseConfig()
cfg = struct();
cfg.TimeResolution = 1e-3;
cfg.Map.Type = 'Grid';
cfg.Map.Boundaries = [-1000, 1000, -1000, 1000];
cfg.Map.Resolution = 100;
cfg.Entities.Transmitters.Count = struct('Min', 1, 'Max', 1);
cfg.Entities.Transmitters.Mobility.Model = 'Stationary';
cfg.Entities.Transmitters.Mobility.MaxSpeedMps = 0;
cfg.Entities.Receivers.Count = struct('Min', 1, 'Max', 1);
cfg.Entities.Receivers.Mobility.Model = 'Stationary';
cfg.Entities.Receivers.Mobility.MaxSpeedMps = 0;
cfg.Environment.Weather.Enable = false;
cfg.Environment.Obstacles.Enable = false;
cfg.Mobility.EnableCollisionAvoidance = false;
cfg.Global.NumFramesPerScenario = 1;
end
