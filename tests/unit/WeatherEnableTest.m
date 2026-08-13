classdef WeatherEnableTest < matlab.unittest.TestCase
    % WeatherEnableTest - Weather.Enable = false must equal an absent block.
    %
    %   The flag was documented, set by four unit tests, and read by
    %   NOTHING: every weather guard tested only for the presence of the
    %   config struct, so a disabled config kept evolving weather (and
    %   consuming randn() draws, shifting the global RNG stream relative to
    %   a config without a Weather block). The contract pinned here is
    %   BIT-IDENTITY: with the same seed, Enable = false produces exactly
    %   the frames (entities, weather state, RNG stream) that a config with
    %   no Weather block at all produces.

    methods (Test)

        function disabledWeatherEqualsAbsentWeather(testCase)
            frameDuration = 1024 / 50e6;

            cfgAbsent = WeatherEnableTest.baseConfig(frameDuration);

            cfgDisabled = cfgAbsent;
            cfgDisabled.Environment.Weather.Enable = false;
            % A realistic disabled config still CARRIES the blocks -- the
            % flag, not the block presence, must decide.
            cfgDisabled.Environment.Weather.InitialConditions.Temperature = -30;
            cfgDisabled.Environment.Weather.Evolution.TemperatureVariation = 25;

            [entA, weatherA, rngA] = WeatherEnableTest.runSim(cfgAbsent);
            [entB, weatherB, rngB] = WeatherEnableTest.runSim(cfgDisabled);

            testCase.verifyEqual(weatherB, weatherA, ...
                ['Enable = false must leave the SAME static default weather ', ...
                 'as an absent Weather block (its InitialConditions must ', ...
                 'not apply).']);
            testCase.verifyEqual({entB.Position}, {entA.Position}, ...
                'Entity trajectories must be bit-identical.');
            testCase.verifyEqual(rngB, rngA, ...
                ['The global RNG stream must end in the same state: a ', ...
                 'disabled weather model must not consume randn() draws.']);
        end

        function enabledWeatherActuallyEvolves(testCase)
            % Control: with Enable = true (and nonzero variation) the
            % weather must move -- proving the guard disables rather than
            % the model being dead either way.
            frameDuration = 1024 / 50e6;
            cfg = WeatherEnableTest.baseConfig(frameDuration);
            cfg.Environment.Weather.Enable = true;
            cfg.Environment.Weather.InitialConditions.Temperature = 20;
            cfg.Environment.Weather.Evolution.TemperatureVariation = 5;

            [~, weather] = WeatherEnableTest.runSim(cfg);
            testCase.verifyNotEqual(weather.Temperature, 20, ...
                'Enabled weather with nonzero variation must evolve.');
        end

    end

    methods (Static)

        function cfg = baseConfig(timeResolution)
            % baseConfig - minimal PhysicalEnvironmentSimulator config with
            % NO Weather block.
            % Inputs: timeResolution - frame duration (s).
            % Outputs: cfg - config struct.
            cfg = struct();
            cfg.TimeResolution = timeResolution;
            cfg.Map.Type = 'Grid';
            cfg.Map.Boundaries = [-1e6, 1e6, -1e6, 1e6];
            cfg.Map.Resolution = 100;
            cfg.Entities.Transmitters.Count = struct('Min', 2, 'Max', 2);
            cfg.Entities.Transmitters.Mobility.Model = 'RandomWalk';
            cfg.Entities.Transmitters.Mobility.MaxSpeedMps = 15;
            cfg.Entities.Receivers.Count = struct('Min', 1, 'Max', 1);
            cfg.Entities.Receivers.Mobility.Model = 'Stationary';
            cfg.Entities.Receivers.Mobility.MaxSpeedMps = 0;
            cfg.Environment.Obstacles.Enable = false;
            cfg.Mobility.EnableCollisionAvoidance = false;
            cfg.Global.NumFramesPerScenario = 3;
        end

        function [entities, weather, rngState] = runSim(cfg)
            % runSim - three frames under a fixed seed.
            % Inputs: cfg - simulator config.
            % Outputs: entities - final frame's entities; weather - final
            %          weather state; rngState - global RNG state after.
            rng(20260814);
            sim = csrd.blocks.scenario.PhysicalEnvironmentSimulator( ...
                'Config', cfg);
            for frameId = 1:3
                entities = step(sim, frameId);
            end
            history = sim.getStateHistory();
            weather = history{end}.environment.Weather;
            rngState = rng;
            release(sim);
        end

    end

end
