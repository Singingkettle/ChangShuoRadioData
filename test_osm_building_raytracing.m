function test_osm_building_raytracing()
    % test_osm_building_raytracing - Smoke test for real building OSM ray tracing path.

    fprintf('=== Building OSM RayTracing Smoke Test ===\n');

    projectRoot = fileparts(mfilename('fullpath'));
    addpath(projectRoot);
    csrd.utils.logger.GlobalLogManager.reset();

    buildingFiles = dir(fullfile(projectRoot, 'data', 'map', 'osm', 'Dense_Urban_Mid_Rise', '*.osm'));
    assert(~isempty(buildingFiles), 'No Dense_Urban_Mid_Rise OSM files found for smoke test.');
    buildingOsm = fullfile(buildingFiles(1).folder, buildingFiles(1).name);

    masterConfig = csrd.utils.config_loader('csrd2025/csrd2025.m');
    masterConfig.Log.Level = 'ERROR';
    masterConfig.Log.SaveToFile = false;
    masterConfig.Log.DisplayInConsole = false;
    csrd.utils.logger.GlobalLogManager.initialize(masterConfig.Log);

    physConfig = masterConfig.Factories.Scenario.PhysicalEnvironment;
    physConfig.Environment.MapType = 'OSM';
    physConfig.Map.Type = 'OSM';
    physConfig.Map.OSMFile = buildingOsm;
    physConfig.Map.OSM.SpecificFile = buildingOsm;
    physConfig.Entities.Transmitters.Count.Min = 1;
    physConfig.Entities.Transmitters.Count.Max = 1;
    physConfig.Entities.Receivers.Count.Min = 1;
    physConfig.Entities.Receivers.Count.Max = 1;

    physSim = csrd.blocks.scenario.PhysicalEnvironmentSimulator('Config', physConfig);
    physCleanup = onCleanup(@() release(physSim)); %#ok<NASGU>
    setup(physSim);
    [~, environment] = step(physSim, 1);
    profile = environment.Map.MapProfile;
    assert(strcmp(profile.Mode, 'OSMBuildings'), 'Building OSM should initialize as OSMBuildings.');
    assert(profile.HasBuildings, 'Building OSM should report HasBuildings=true.');
    fprintf('  [OK] PhysicalEnvironmentSimulator building OSM profile.\n');

    mc = masterConfig;
    mc.Runner.NumScenarios = 1;
    mc.Factories.Scenario.Global.NumFramesPerScenario = 1;
    mc.Factories.Scenario.Global.ObservationDuration = 0.005;
    mc.Factories.Scenario.PhysicalEnvironment.Map.Types = {'OSM'};
    mc.Factories.Scenario.PhysicalEnvironment.Map.Ratio = [1.0];
    mc.Factories.Scenario.PhysicalEnvironment.Map.OSM.SpecificFile = buildingOsm;
    mc.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Min = 1;
    mc.Factories.Scenario.PhysicalEnvironment.Entities.Transmitters.Count.Max = 1;
    mc.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Min = 1;
    mc.Factories.Scenario.PhysicalEnvironment.Entities.Receivers.Count.Max = 1;
    mc.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternTypes = {'Continuous'};
    mc.Factories.Scenario.CommunicationBehavior.TemporalBehavior.PatternDistribution = [1.0];

    engine = csrd.core.ChangShuo();
    engineCleanup = onCleanup(@() release(engine)); %#ok<NASGU>
    engine.FactoryConfigs = mc.Factories;
    setup(engine, 1);
    [scenarioData, scenarioAnnotation] = step(engine, 1);
    assert(~isempty(scenarioData) && ~isempty(scenarioAnnotation), ...
        'Building OSM scenario should produce data and annotations.');

    rxAnn = scenarioAnnotation{1}{1};
    assert(isfield(rxAnn, 'SignalSources') && ~isempty(rxAnn.SignalSources), ...
        'Building OSM scenario should produce at least one signal source.');
    sourceInfo = rxAnn.SignalSources(1);
    assert(strcmp(sourceInfo.Realized.ChannelModel, 'RayTracing'), ...
        'Building OSM smoke test should use RayTracing channel model.');
    assert(sourceInfo.Channel.MapProfile.HasBuildings, ...
        'Building OSM annotation should preserve building map profile.');
    fprintf('  [OK] End-to-end building OSM scenario.\n');

    fprintf('=== Building OSM RayTracing Smoke Test Passed ===\n');
end
