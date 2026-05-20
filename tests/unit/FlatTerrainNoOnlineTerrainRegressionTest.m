classdef FlatTerrainNoOnlineTerrainRegressionTest < matlab.unittest.TestCase
    %FLATTERRAINNOONLINETERRAINREGRESSIONTEST Guard old gmted2010 failure.

    methods (Test)
        function northDakotaEmptyOsmDeclaresTerrainNone(testCase)
            root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            addpath(root);
            csrd.runtime.logger.GlobalLogManager.reset();

            cfg = csrd.runtime.config_loader('csrd2025/csrd2025.m');
            phys = cfg.Factories.Scenario.PhysicalEnvironment;
            osmFile = fullfile(root, 'data', 'map', 'osm', ...
                'Open_Farmland_Flat', ...
                'Open_Farmland_Flat_Central_North_Dakota_Farmland_USA_47.0000_-100.0000.osm');
            testCase.assumeTrue(isfile(osmFile), ...
                'North Dakota OSM fixture is not available in this checkout.');

            phys.Environment.MapType = 'OSM';
            phys.Map.Type = 'OSM';
            phys.Map.Types = {'OSM'};
            phys.Map.Ratio = 1;
            phys.Map.OSMFile = osmFile;
            phys.Map.OSM.SpecificFile = osmFile;
            phys.Map.OSM.EmptyGeometryPolicy = 'FlatTerrain';
            phys.Map.OSM.FlatTerrain.Terrain = 'none';
            phys.Map.OSM.FlatTerrain.Material = 'seawater';
            phys.Map.OSM.FlatTerrain.MaxNumReflections = 1;
            phys.Entities.Transmitters.Count.Min = 1;
            phys.Entities.Transmitters.Count.Max = 1;
            phys.Entities.Receivers.Count.Min = 1;
            phys.Entities.Receivers.Count.Max = 1;
            phys.TimeResolution = cfg.RuntimePlan.Frame.FrameDurationSec;

            sim = csrd.blocks.scenario.PhysicalEnvironmentSimulator( ...
                'Config', phys);
            cleanupObj = onCleanup(@() localRelease(sim)); %#ok<NASGU>
            setup(sim);
            [~, environment] = step(sim, 92);
            profile = environment.Map.MapProfile;

            testCase.verifyEqual(char(profile.Mode), 'FlatTerrain');
            testCase.verifyFalse(logical(profile.HasBuildings));
            testCase.verifyTrue(isfield(profile, 'Terrain'));
            testCase.verifyEqual(char(profile.Terrain), 'none');
            testCase.verifyFalse(contains(jsonencode(profile), 'gmted2010'), ...
                'FlatTerrain North Dakota path must not retain online terrain dependency.');
        end
    end
end

function localRelease(obj)
try
    release(obj);
catch
end
end
