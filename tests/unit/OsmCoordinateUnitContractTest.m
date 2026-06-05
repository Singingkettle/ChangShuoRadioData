classdef OsmCoordinateUnitContractTest < matlab.unittest.TestCase
    % OsmCoordinateUnitContractTest

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
            bounds = localExpectedBounds(31.0000, 121.0000, 1);
            testCase.verifyGreaterThanOrEqual(tx.GeoPositionDeg(1), bounds.MinLatitude);
            testCase.verifyLessThanOrEqual(tx.GeoPositionDeg(1), bounds.MaxLatitude);
            testCase.verifyGreaterThanOrEqual(tx.GeoPositionDeg(2), bounds.MinLongitude);
            testCase.verifyLessThanOrEqual(tx.GeoPositionDeg(2), bounds.MaxLongitude);
            testCase.verifyGreaterThan(abs(tx.Position(1)) + abs(tx.Position(2)), 0);
        end

        function rayTracingRequiresGeoPositionForMeterCoordinates(testCase)
            rt = csrd.blocks.physical.channel.RayTracing( ...
                'SampleRate', 1e6, 'CarrierFrequency', 2.4e9);
            x = struct('Signal', complex(ones(8, 1)), 'SampleRate', 1e6);
            txInfo = struct('ID', 'Tx1', 'Position', [10, 20, 30], ...
                'PositionUnit', 'meters', 'Velocity', [0, 0, 0], ...
                'NumTransmitAntennas', 1);
            rxInfo = struct('ID', 'Rx1', 'Position', [100, 20, 10], ...
                'PositionUnit', 'meters', 'Velocity', [0, 0, 0], ...
                'NumAntennas', 1);
            linkInfo = struct('MapProfile', struct( ...
                'Mode', 'FlatTerrain', ...
                'Terrain', 'none', ...
                'TerrainMaterial', 'seawater', ...
                'MaxNumReflections', 1, ...
                'ChannelModel', 'RayTracing'));

            f = @() rt(x, txInfo, rxInfo, linkInfo);
            testCase.verifyError(f, 'CSRD:RayTracing:MissingGeoPosition');
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

function bounds = localExpectedBounds(latDeg, lonDeg, sizeKm)
earthRadiusKm = 6371.0;
deltaLatDeg = rad2deg((sizeKm / 2) / earthRadiusKm);
deltaLonDeg = rad2deg((sizeKm / 2) / (earthRadiusKm * cos(deg2rad(latDeg))));
bounds = struct( ...
    'MinLatitude', latDeg - deltaLatDeg, ...
    'MaxLatitude', latDeg + deltaLatDeg, ...
    'MinLongitude', lonDeg - deltaLonDeg, ...
    'MaxLongitude', lonDeg + deltaLonDeg);
end
