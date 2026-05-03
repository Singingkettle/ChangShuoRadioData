function test_osm_building_raytracing()
    % test_osm_building_raytracing - Smoke test for real building OSM ray tracing path.

    fprintf('=== Building OSM RayTracing Smoke Test ===\n');

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRoot);
    csrd.runtime.logger.GlobalLogManager.reset();

    buildingFiles = dir(fullfile(projectRoot, 'data', 'map', 'osm', 'Dense_Urban_Mid_Rise', '*.osm'));
    assert(~isempty(buildingFiles), 'No Dense_Urban_Mid_Rise OSM files found for smoke test.');
    buildingOsm = fullfile(buildingFiles(1).folder, buildingFiles(1).name);

    masterConfig = csrd.runtime.config_loader('csrd2025/csrd2025.m');
    masterConfig.Log.Level = 'ERROR';
    masterConfig.Log.SaveToFile = false;
    masterConfig.Log.DisplayInConsole = false;
    csrd.runtime.logger.GlobalLogManager.initialize(masterConfig.Log);

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
    mc = csrd.test_support.applyCanonicalFrameContract(mc, 0.005, 1);
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
    sources = rxAnn.SignalSources;
    if iscell(sources)
        sourceInfo = sources{1};
    else
        sourceInfo = sources(1);
    end

    % Phase 4 (audit §17.6 / S13): the v1 top-level `Channel.Model` /
    % `Channel.Info.MapProfile.HasBuildings` keys were deleted in
    % favour of the unified Truth.Execution.ChannelModel string. The
    % ChannelModel selector inside processChannelPropagation already
    % derives 'RayTracing' from `MapProfile.HasBuildings == true`, so
    % asserting ChannelModel == 'RayTracing' transitively validates
    % that the building map flowed through the pipeline. The verbose
    % MapProfile sub-struct is no longer surfaced per-source.
    assert(isfield(sourceInfo, 'Truth') && isstruct(sourceInfo.Truth) ...
        && isfield(sourceInfo.Truth, 'Execution') ...
        && isstruct(sourceInfo.Truth.Execution), ...
        'Phase 4 v2 schema requires SignalSources(k).Truth.Execution.');
    cm = '';
    if isfield(sourceInfo.Truth.Execution, 'ChannelModel')
        cm = char(sourceInfo.Truth.Execution.ChannelModel);
    end
    assert(strcmp(cm, 'RayTracing'), ...
        ['Building OSM smoke: Truth.Execution.ChannelModel should ' ...
         'be ''RayTracing'', got ''%s''.'], cm);
    fprintf('  [OK] End-to-end building OSM scenario.\n');

    fprintf('=== Building OSM RayTracing Smoke Test Passed ===\n');
end
