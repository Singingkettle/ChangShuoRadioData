function test_empty_osm_raytracing()
    % test_empty_osm_raytracing - Regression test for empty OSM flat-terrain fallback.

    fprintf('=== Empty OSM RayTracing Regression Test ===\n');

    projectRoot = fileparts(mfilename('fullpath'));
    addpath(projectRoot);
    csrd.utils.logger.GlobalLogManager.reset();

    fixtureDir = fullfile(projectRoot, 'tmp_empty_osm_raytracing');
    if ~exist(fixtureDir, 'dir')
        mkdir(fixtureDir);
    end
    cleanupObj = onCleanup(@() cleanupFixtureDir(fixtureDir)); %#ok<NASGU>

    emptyOsm = fullfile(fixtureDir, 'Open_Ocean_Area_Central_Indian_Ocean_-20.0000_80.0000.osm');
    buildingOsm = fullfile(fixtureDir, 'Tiny_Building_0.0000_0.0000.osm');
    buildingPartOsm = fullfile(fixtureDir, 'Tiny_BuildingPart_0.0000_0.0000.osm');
    writeTextFile(emptyOsm, sprintf(['<?xml version="1.0" encoding="UTF-8"?>\n', ...
        '<osm version="0.6"><note>empty ocean fixture</note><meta osm_base="2026-01-01T00:00:00Z"/></osm>\n']));
    writeTextFile(buildingOsm, sprintf(['<?xml version="1.0" encoding="UTF-8"?>\n', ...
        '<osm version="0.6"><way id="1"><tag k="building" v="yes"/></way></osm>\n']));
    writeTextFile(buildingPartOsm, sprintf(['<?xml version="1.0" encoding="UTF-8"?>\n', ...
        '<osm version="0.6"><way id="2"><tag k="building:part" v="yes"/></way></osm>\n']));

    assert(~csrd.utils.osmHasBuildings(emptyOsm), 'Empty OSM should not report buildings.');
    assert(csrd.utils.osmHasBuildings(buildingOsm), 'OSM building tag should be detected.');
    assert(csrd.utils.osmHasBuildings(buildingPartOsm), 'OSM building:part tag should be detected.');
    assert(~csrd.utils.osmHasBuildings(fullfile(fixtureDir, 'missing.osm')), 'Missing OSM should return false.');
    fprintf('  [OK] OSM building detection.\n');

    masterConfig = csrd.utils.config_loader('csrd2025/csrd2025.m');
    masterConfig.Log.Level = 'ERROR';
    masterConfig.Log.SaveToFile = false;
    masterConfig.Log.DisplayInConsole = false;
    csrd.utils.logger.GlobalLogManager.initialize(masterConfig.Log);

    physConfig = masterConfig.Factories.Scenario.PhysicalEnvironment;
    physConfig.Environment.MapType = 'OSM';
    physConfig.Map.Type = 'OSM';
    physConfig.Map.OSMFile = emptyOsm;
    physConfig.Map.OSM.SpecificFile = emptyOsm;
    physConfig.Map.OSM.EmptyGeometryPolicy = 'FlatTerrain';
    physConfig.Map.OSM.FlatTerrain.Terrain = 'none';
    physConfig.Map.OSM.FlatTerrain.Material = 'seawater';
    physConfig.Map.OSM.FlatTerrain.MaxNumReflections = 1;
    physConfig.Entities.Transmitters.Count.Min = 1;
    physConfig.Entities.Transmitters.Count.Max = 1;
    physConfig.Entities.Receivers.Count.Min = 1;
    physConfig.Entities.Receivers.Count.Max = 1;

    simulator = csrd.blocks.scenario.PhysicalEnvironmentSimulator('Config', physConfig);
    setup(simulator);
    [~, environment] = step(simulator, 1);
    profile = environment.Map.MapProfile;
    assert(strcmp(profile.Mode, 'FlatTerrain'), 'Empty OSM should initialize as FlatTerrain.');
    assert(~profile.HasBuildings, 'FlatTerrain profile should report HasBuildings=false.');
    release(simulator);
    fprintf('  [OK] PhysicalEnvironmentSimulator empty OSM fallback.\n');

    mc = masterConfig;
    mc.Runner.NumScenarios = 1;
    mc.Factories.Scenario.Global.NumFramesPerScenario = 1;
    mc.Factories.Scenario.Global.ObservationDuration = 0.005;
    mc.Factories.Scenario.PhysicalEnvironment.Map.Types = {'OSM'};
    mc.Factories.Scenario.PhysicalEnvironment.Map.Ratio = [1.0];
    mc.Factories.Scenario.PhysicalEnvironment.Map.OSM.SpecificFile = emptyOsm;
    mc.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min = 1;
    mc.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = 1;
    mc.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = 1;
    mc.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = 1;
    mc.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternTypes = {'Continuous'};
    mc.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternDistribution = [1.0];

    engine = csrd.core.ChangShuo();
    engine.FactoryConfigs = mc.Factories;
    setup(engine, 1);
    [scenarioData, scenarioAnnotation] = step(engine, 1);
    assert(~isempty(scenarioData), 'Scenario data should not be empty for empty OSM FlatTerrain.');
    assert(~isempty(scenarioAnnotation), 'Scenario annotation should not be empty for empty OSM FlatTerrain.');
    release(engine);
    fprintf('  [OK] End-to-end empty OSM scenario.\n');

    fprintf('=== Empty OSM RayTracing Regression Test Passed ===\n');
end

function writeTextFile(pathName, content)
    fid = fopen(pathName, 'w');
    assert(fid ~= -1, 'Could not write fixture file: %s', pathName);
    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s', content);
end

function cleanupFixtureDir(fixtureDir)
    if exist(fixtureDir, 'dir')
        rmdir(fixtureDir, 's');
    end
end
