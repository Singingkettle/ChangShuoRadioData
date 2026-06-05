classdef ScenarioMapChannelModelPropagationTest < matlab.unittest.TestCase
    %SCENARIOMAPCHANNELMODELPROPAGATIONTEST Map channel model contract tests.

    methods (Test)
        function statisticalChannelModelReachesMapProfile(testCase)
            cfg = localScenarioConfig();
            cfg.PhysicalEnvironment.Map.Types = {'Statistical'};
            cfg.PhysicalEnvironment.Map.Ratio = 1.0;
            cfg.PhysicalEnvironment.Map.Statistical.ChannelModel = 'Rayleigh';
            cfg.CommunicationBehavior.Regulatory.Enable = false;

            [~, ~, layout] = localRunScenarioFactory(cfg);

            testCase.verifyEqual( ...
                layout.Environment.Map.MapProfile.ChannelModel, 'Rayleigh');
        end

        function emptyOsmChannelModelReachesMapProfile(testCase)
            projectRoot = localProjectRoot();
            fixtureDir = fullfile(projectRoot, 'artifacts', 'tests', ...
                'tmp', 'phase12_osm_channel_model');
            if ~exist(fixtureDir, 'dir')
                mkdir(fixtureDir);
            end
            cleanupObj = onCleanup(@() localCleanupDir(fixtureDir)); %#ok<NASGU>

            emptyOsm = fullfile(fixtureDir, ...
                'Open_Ocean_Area_Central_Indian_Ocean_-20.0000_80.0000.osm');
            localWriteTextFile(emptyOsm, sprintf([ ...
                '<?xml version="1.0" encoding="UTF-8"?>\n', ...
                '<osm version="0.6"><note>empty fixture</note></osm>\n']));

            cfg = localScenarioConfig();
            phys = cfg.PhysicalEnvironment;
            phys.Map.Type = 'OSM';
            phys.Map.OSMFile = emptyOsm;
            phys.Map.OSM.SpecificFile = emptyOsm;
            phys.Map.OSM.ChannelModel = 'AWGN';
            phys.Map.OSM.EmptyGeometryPolicy = 'FlatTerrain';
            phys.Map.OSM.FlatTerrain.Terrain = 'none';
            phys.Map.OSM.FlatTerrain.Material = 'seawater';
            phys.Map.OSM.FlatTerrain.MaxNumReflections = 1;
            phys.Environment.MapType = 'OSM';
            phys.Environment.OSMMapFile = emptyOsm;
            phys.Environment.ChannelModel = 'AWGN';
            runtimeCfg = csrd.test_support.buildRuntimePlanForTest(cfg);
            scenarioPlan = csrd.pipeline.runtime.buildScenarioPlan( ...
                runtimeCfg.RuntimePlan, runtimeCfg.Factories.Scenario, ...
                struct('ScenarioId', 1, 'RandomSeed', runtimeCfg.Runner.RandomSeed));
            phys.TimeResolution = scenarioPlan.Frame.FrameDurationSec;

            simulator = csrd.blocks.scenario.PhysicalEnvironmentSimulator( ...
                'Config', phys);
            setup(simulator);
            cleanupSim = onCleanup(@() localRelease(simulator)); %#ok<NASGU>
            [~, environment] = step(simulator, 1);

            testCase.verifyEqual( ...
                environment.Map.MapProfile.ChannelModel, 'AWGN');
        end
    end
end

function cfg = localScenarioConfig()
projectRoot = localProjectRoot();
addpath(projectRoot);
masterCfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
cfg = masterCfg.Factories.Scenario;
cfg = csrd.test_support.applyCanonicalFrameContract(cfg, 0.002, 1);
cfg.PhysicalEnvironment.Entities.Transmitters.Count.Min = 1;
cfg.PhysicalEnvironment.Entities.Transmitters.Count.Max = 1;
cfg.PhysicalEnvironment.Entities.Receivers.Count.Min = 1;
cfg.PhysicalEnvironment.Entities.Receivers.Count.Max = 1;
cfg.CommunicationBehavior.TemporalBehavior.PatternTypes = {'Continuous'};
cfg.CommunicationBehavior.TemporalBehavior.PatternDistribution = 1;
end

function [tx, rx, layout] = localRunScenarioFactory(cfg)
csrd.runtime.logger.GlobalLogManager.reset();
runtimeCfg = csrd.test_support.buildRuntimePlanForTest(cfg);
sf = csrd.factories.ScenarioFactory('Config', runtimeCfg.Factories.Scenario, ...
    'RuntimePlan', runtimeCfg.RuntimePlan);
setup(sf);
cleanupObj = onCleanup(@() localRelease(sf)); %#ok<NASGU>
[tx, rx, layout] = step(sf, 1);
end

function localRelease(obj)
if isLocked(obj)
    release(obj);
end
end

function projectRoot = localProjectRoot()
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end

function localWriteTextFile(pathName, content)
fid = fopen(pathName, 'w');
assert(fid ~= -1, 'Could not write fixture file: %s', pathName);
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', content);
end

function localCleanupDir(pathName)
if exist(pathName, 'dir')
    rmdir(pathName, 's');
end
end
