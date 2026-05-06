classdef OsmCoordinateUnitContractTest < matlab.unittest.TestCase
    % OsmCoordinateUnitContractTest
    % 中文说明：OSM 场景同时发布米制 Position 和地理 GeoPositionDeg。

    methods (Test)

        function osmEntitiesPublishMeterAndGeoCoordinates(testCase)
            osmFile = localTempOsmFile(testCase);
            cfg = localOsmPhysicalConfig(osmFile);
            sim = csrd.blocks.scenario.PhysicalEnvironmentSimulator('Config', cfg);

            entities = step(sim, 1);
            tx = entities(strcmp({entities.ID}, 'Tx1'));

            testCase.verifyEqual(tx.PositionUnit, 'meters');
            testCase.verifyTrue(isnumeric(tx.Position) && numel(tx.Position) == 3);
            testCase.verifyTrue(isnumeric(tx.GeoPositionDeg) && numel(tx.GeoPositionDeg) == 3);
            testCase.verifyGreaterThanOrEqual(tx.GeoPositionDeg(1), 30.995);
            testCase.verifyLessThanOrEqual(tx.GeoPositionDeg(1), 31.005);
            testCase.verifyGreaterThanOrEqual(tx.GeoPositionDeg(2), 120.995);
            testCase.verifyLessThanOrEqual(tx.GeoPositionDeg(2), 121.005);
            testCase.verifyGreaterThan(abs(tx.Position(1)) + abs(tx.Position(2)), 0);
        end

    end
end

function osmFile = localTempOsmFile(testCase)
tempRoot = tempname;
mkdir(tempRoot);
testCase.addTeardown(@() localRemoveDir(tempRoot));
osmFile = fullfile(tempRoot, 'phase20_empty_31.0000_121.0000.osm');
fid = fopen(osmFile, 'w');
assert(fid > 0, 'Failed to create temp OSM file.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, ['<?xml version="1.0" encoding="UTF-8"?>\n', ...
    '<osm version="0.6" generator="phase20-test">\n', ...
    '  <node id="1" lat="31.0000" lon="121.0000"/>\n', ...
    '</osm>\n']);
clear cleanup;
end

function localRemoveDir(pathName)
if isfolder(pathName)
    rmdir(pathName, 's');
end
end

function cfg = localOsmPhysicalConfig(osmFile)
cfg = localPhysicalConfig(1024 / 50e6);
cfg.Map.Type = 'OSM';
cfg.Map.OSMFile = osmFile;
cfg.Map.OSM.EmptyGeometryPolicy = 'FlatTerrain';
cfg.Map.OSM.ChannelModel = 'RayTracing';
cfg.Map.OSM.FlatTerrain.Terrain = 'none';
cfg.Map.OSM.FlatTerrain.Material = 'seawater';
cfg.Map.OSM.FlatTerrain.MaxNumReflections = 1;
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
