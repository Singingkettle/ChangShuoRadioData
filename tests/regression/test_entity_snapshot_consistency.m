function test_entity_snapshot_consistency()
    % test_entity_snapshot_consistency - Verify communication/temporal snapshots are written back.

    fprintf('=== Entity Snapshot Consistency Test ===\n');

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRoot);
    csrd.utils.logger.GlobalLogManager.reset();

    masterConfig = csrd.utils.config_loader('csrd2025/csrd2025.m');
    masterConfig.Log.Level = 'ERROR';
    masterConfig.Log.SaveToFile = false;
    masterConfig.Log.DisplayInConsole = false;
    csrd.utils.logger.GlobalLogManager.initialize(masterConfig.Log);

    scenarioConfig = masterConfig.Factories.Scenario;
    scenarioConfig.Global.NumFramesPerScenario = 2;
    scenarioConfig.Global.ObservationDuration = 0.01;
    scenarioConfig.PhysicalEnvironment.Map.Types = {'Statistical'};
    scenarioConfig.PhysicalEnvironment.Map.Ratio = [1.0];
    scenarioConfig.PhysicalEnvironment.Entities.Transmitters.Count.Min = 1;
    scenarioConfig.PhysicalEnvironment.Entities.Transmitters.Count.Max = 1;
    scenarioConfig.PhysicalEnvironment.Entities.Receivers.Count.Min = 1;
    scenarioConfig.PhysicalEnvironment.Entities.Receivers.Count.Max = 1;
    scenarioConfig.CommunicationBehavior.TemporalBehavior.PatternTypes = {'Continuous'};
    scenarioConfig.CommunicationBehavior.TemporalBehavior.PatternDistribution = [1.0];

    factory = csrd.factories.ScenarioFactory('Config', scenarioConfig);
    cleanupObj = onCleanup(@() release(factory)); %#ok<NASGU>
    setup(factory);

    [txFrame1, rxFrame1, layout1] = step(factory, 1);
    assert(isfield(layout1, 'Entities') && ~isempty(layout1.Entities), ...
        'Frame 1 layout should expose entities with snapshots.');

    txEntityId = txFrame1{1}.EntityID;
    rxEntityId = rxFrame1{1}.EntityID;
    txEntity1 = findEntity(layout1.Entities, txEntityId);
    rxEntity1 = findEntity(layout1.Entities, rxEntityId);

    txSnap1 = txEntity1.Snapshots{1};
    rxSnap1 = rxEntity1.Snapshots{1};
    assert(isfield(txSnap1, 'Communication') && txSnap1.Communication.Initialized, ...
        'Tx communication snapshot should be initialized at frame 1.');
    assert(txSnap1.Communication.Bandwidth > 0, ...
        'Tx snapshot should contain planned bandwidth.');
    assert(strcmp(txSnap1.Temporal.PatternType, txFrame1{1}.Temporal.Type), ...
        'Tx temporal snapshot should store the planned pattern type.');
    assert(txSnap1.Temporal.IsTransmitting == txFrame1{1}.TransmissionState.IsActive, ...
        'Tx temporal snapshot should reflect frame activity.');
    assert(isfield(rxSnap1, 'Communication') && rxSnap1.Communication.Initialized, ...
        'Rx communication snapshot should be initialized at frame 1.');
    assert(abs(rxSnap1.Communication.SampleRate - rxFrame1{1}.Observation.SampleRate) < 1, ...
        'Rx snapshot should preserve receiver sample rate.');
    fprintf('  [OK] Frame 1 snapshot state written back.\n');

    [txFrame2, ~, layout2] = step(factory, 2);
    txEntity2 = findEntity(layout2.Entities, txEntityId);
    assert(~isempty(txEntity2.Snapshots{1}), 'Frame 1 snapshot should persist into frame 2.');
    assert(~isempty(txEntity2.Snapshots{2}), 'Frame 2 snapshot should exist.');

    txSnap2 = txEntity2.Snapshots{2};
    assert(txSnap2.Temporal.IsTransmitting == txFrame2{1}.TransmissionState.IsActive, ...
        'Frame 2 temporal snapshot should reflect frame activity.');
    assert(txSnap2.Temporal.CurrentIntervalIdx == txFrame2{1}.TransmissionState.CurrentIntervalIdx, ...
        'Frame 2 temporal snapshot should track interval index.');
    assert(all(abs(txSnap2.Physical.Position - txEntity2.Position) < 1e-9), ...
        'Frame 2 physical snapshot should match entity position.');
    fprintf('  [OK] Snapshot state persists across frames.\n');

    fprintf('=== Entity Snapshot Consistency Test Passed ===\n');
end

function entity = findEntity(entities, entityId)
    entity = [];
    for idx = 1:length(entities)
        if strcmp(entities(idx).ID, entityId)
            entity = entities(idx);
            return;
        end
    end
    error('test_entity_snapshot_consistency:MissingEntity', 'Entity %s not found.', entityId);
end
