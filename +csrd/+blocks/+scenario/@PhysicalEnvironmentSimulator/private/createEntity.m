function entity = createEntity(obj, entityType, entityID, frameId)
    %CREATEENTITY Phase 3 strict-construction entity factory.
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 createEntity 实现。
    %
    % Creates a single entity (Tx or Rx) with the canonical Snapshot-based
    % state container. Phase 3 (audit §3.1.ter / §17.5 P3-followup) removed
    % the silent fallbacks for missing map boundaries and the hardcoded
    % 100-frame pre-allocation cap; both are now driven explicitly from the
    % validated PhysicalEnvironment config.
    %
    % DESIGN PRINCIPLE
    %   Entity is a shared object between PhysicalEnvironmentSimulator and
    %   CommunicationBehaviorSimulator. Each simulator manages its own
    %   state domain:
    %     - PhysicalEnvironmentSimulator : Physical state (position,
    %       velocity, orientation).
    %     - CommunicationBehaviorSimulator : Communication + Temporal
    %       state.
    %
    % Inputs:
    %   entityType - 'Transmitter' or 'Receiver'.
    %   entityID   - Unique identifier string (e.g. 'Tx1', 'Rx1').
    %   frameId    - Frame index at which the entity is created.
    %
    % Output:
    %   entity - Struct with the Phase 3 canonical layout.
    %
    % Errors:
    %   CSRD:Construction:MissingMapBoundaries
    %       Raised when obj.mapData.Boundaries is missing/empty. The
    %       upstream ScenarioFactory.getPhysicalEnvironmentConfig + the
    %       Statistical/OSM map initializers are required to populate this
    %       field; if it is absent we fail fast rather than fabricating a
    %       random ±1000 m placement.
    %   CSRD:Construction:MissingMobilityModel
    %       Surfaced from assignMobilityModel when the per-entity Mobility
    %       slice lacks an explicit Model name.

    entity = struct();
    entity.ID = entityID;
    entity.Type = entityType;
    entity.CreationFrameId = frameId;
    entity.CreationTime = frameId * obj.timeResolution;

    snapshotCapacity = resolveSnapshotCapacity(obj, frameId);
    entity.Snapshots = cell(1, snapshotCapacity);

    initialSnapshot = createInitialSnapshot(obj, entityType, entityID, frameId);
    entity.Snapshots{frameId} = initialSnapshot;

    entity.Position = initialSnapshot.Physical.Position;
    entity.PositionUnit = initialSnapshot.Physical.PositionUnit;
    entity.GeoPositionDeg = initialSnapshot.Physical.GeoPositionDeg;
    entity.Velocity = initialSnapshot.Physical.Velocity;
    entity.Orientation = initialSnapshot.Physical.Orientation;
    entity.AngularVelocity = initialSnapshot.Physical.AngularVelocity;

    entityConfig = resolveEntityConfig(obj, entityType);
    entity.MobilityModel = csrd.blocks.scenario.PhysicalEnvironmentSimulator ...
        .assignMobilityModel(entityType, entityConfig);

    entity.Properties = initializeEntityProperties(obj, entityType);

    entity.FrameId = frameId;
    entity.StateHistory = [];
    entity.LastUpdateTime = entity.CreationTime;

    obj.logger.debug('Created %s entity %s at position [%.1f, %.1f, %.1f] (mobility=%s, capacity=%d)', ...
        entityType, entityID, entity.Position, entity.MobilityModel, snapshotCapacity);
end

function snapshot = createInitialSnapshot(obj, entityType, entityID, frameId)
    %CREATEINITIALSNAPSHOT Build the first Snapshot for a freshly created
    % 中文说明：createInitialSnapshot 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % entity. Position must come from the validated map boundaries; the
    % previous ±1000 m fallback was removed in Phase 3.

    snapshot = struct();
    snapshot.FrameId = frameId;
    snapshot.Timestamp = frameId * obj.timeResolution;
    snapshot.EntityID = entityID;
    snapshot.EntityType = entityType;

    snapshot.Physical = struct();

    if ~isfield(obj.mapData, 'Boundaries') || isempty(obj.mapData.Boundaries)
        error('CSRD:Construction:MissingMapBoundaries', ...
            ['createEntity: obj.mapData.Boundaries is required (Phase 3 ', ...
             'removed the ±1000 m fallback). The upstream ScenarioFactory ', ...
             'must populate Map.Boundaries / Environment.MapBoundaries via ', ...
             'getPhysicalEnvironmentConfig.']);
    end

    bounds = obj.mapData.Boundaries;

    if isstruct(bounds) && isfield(bounds, 'MinLatitude')
        latDeg = randomInRange(obj, bounds.MinLatitude, bounds.MaxLatitude);
        lonDeg = randomInRange(obj, bounds.MinLongitude, bounds.MaxLongitude);
        heightMeters = randomInRange(obj, 10, 100);
        xyMeters = geoToLocalMeters(latDeg, lonDeg, bounds);
        snapshot.Physical.Position = [xyMeters, heightMeters];
        snapshot.Physical.GeoPositionDeg = [latDeg, lonDeg, heightMeters];
        snapshot.Physical.PositionUnit = 'meters';
    elseif isnumeric(bounds) && numel(bounds) >= 4
        snapshot.Physical.Position = [
            randomInRange(obj, bounds(1), bounds(2)), ...
            randomInRange(obj, bounds(3), bounds(4)), ...
            randomInRange(obj, 10, 100) ...
        ];
        snapshot.Physical.GeoPositionDeg = [];
        snapshot.Physical.PositionUnit = 'meters';
    else
        error('CSRD:Construction:MissingMapBoundaries', ...
            ['createEntity: obj.mapData.Boundaries has unsupported ', ...
             'shape (class=%s, numel=%d). Expected struct with ', ...
             'Min/Max Lat-Lon or numeric [xmin xmax ymin ymax] vector.'], ...
            class(bounds), numel(bounds));
    end

    cohortMaxSpeed = resolveCohortMaxSpeed(obj, entityType);
    maxSpeed = getMaxSpeedForEntityType(obj, entityType, ...
        'CohortMaxSpeedMps', cohortMaxSpeed);
    snapshot.Physical.Velocity = [
        randomInRange(obj, -maxSpeed, maxSpeed), ...
        randomInRange(obj, -maxSpeed, maxSpeed), ...
        0 ...
    ];

    snapshot.Physical.Orientation = [
        randi([-180, 180]), ...
        randi([-30, 30]) ...
    ];

    snapshot.Physical.AngularVelocity = [
        randomInRange(obj, -10, 10), ...
        randomInRange(obj, -5, 5) ...
    ];

    snapshot.Communication = struct();
    snapshot.Communication.Frequency = 0;
    snapshot.Communication.Bandwidth = 0;
    snapshot.Communication.ModulationType = '';
    snapshot.Communication.ModulationOrder = 0;
    snapshot.Communication.Power = 0;
    snapshot.Communication.NumAntennas = 1;
    snapshot.Communication.Initialized = false;

    snapshot.Temporal = struct();
    snapshot.Temporal.IsTransmitting = false;
    snapshot.Temporal.PatternType = '';
    snapshot.Temporal.ActiveIntervalIndices = [];
    snapshot.Temporal.ActiveIntervals = zeros(0, 2);
    snapshot.Temporal.FrameWindow = [0, 0];
end

function capacity = resolveSnapshotCapacity(obj, frameId)
    %RESOLVESNAPSHOTCAPACITY Pre-allocation hint driven by config.
    % 中文说明：resolveSnapshotCapacity 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % Snapshots are dynamic-grow cells (writes past the end auto-expand),
    % but we honor obj.Config.Global.NumFramesPerScenario when available so
    % long scenarios do not pay repeated reallocation costs.

    capacity = max(100, frameId);

    if isfield(obj.Config, 'Global') && isstruct(obj.Config.Global) ...
            && isfield(obj.Config.Global, 'NumFramesPerScenario') ...
            && isnumeric(obj.Config.Global.NumFramesPerScenario) ...
            && isscalar(obj.Config.Global.NumFramesPerScenario) ...
            && obj.Config.Global.NumFramesPerScenario > 0
        capacity = max(capacity, double(obj.Config.Global.NumFramesPerScenario));
    end
end

function cohortMax = resolveCohortMaxSpeed(obj, entityType)
    %RESOLVECOHORTMAXSPEED Phase 4 §3.8.A / §3.8.C cohort speed lookup.
    % 中文说明：resolveCohortMaxSpeed 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    %
    %   Pulls `Mobility.MaxSpeedMps` (canonical) or the legacy flat
    %   `MobilityModel.MaxSpeedMps` off the per-entity-type slice that
    %   ScenarioFactory wrote into obj.Config based on the cohort
    %   recipe. Returns [] when the cohort did not specify an override
    %   (in which case getMaxSpeedForEntityType uses the historical
    %   per-type defaults).
    %
    %   Accepting both `Mobility.MaxSpeedMps` and the flat alternate
    %   mirrors the resolution order already used by
    %   PhysicalEnvironmentSimulator.assignMobilityModel for the
    %   `Model` field, so blueprints / unit tests do not have to
    %   special-case Phase 4.
    cohortMax = [];
    try
        entityConfig = resolveEntityConfig(obj, entityType);
    catch
        return;
    end
    if isstruct(entityConfig) && isfield(entityConfig, 'Mobility') ...
            && isstruct(entityConfig.Mobility) ...
            && isfield(entityConfig.Mobility, 'MaxSpeedMps') ...
            && isnumeric(entityConfig.Mobility.MaxSpeedMps) ...
            && isscalar(entityConfig.Mobility.MaxSpeedMps)
        cohortMax = double(entityConfig.Mobility.MaxSpeedMps);
        return;
    end
    if isstruct(entityConfig) && isfield(entityConfig, 'MobilityModel') ...
            && isstruct(entityConfig.MobilityModel) ...
            && isfield(entityConfig.MobilityModel, 'MaxSpeedMps') ...
            && isnumeric(entityConfig.MobilityModel.MaxSpeedMps) ...
            && isscalar(entityConfig.MobilityModel.MaxSpeedMps)
        cohortMax = double(entityConfig.MobilityModel.MaxSpeedMps);
    end
end

function entityConfig = resolveEntityConfig(obj, entityType)
    %RESOLVEENTITYCONFIG Pull the per-entity-type subtree from obj.Config.
    % 中文说明：resolveEntityConfig 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % Phase 3 mandates that mobility selection lives next to the entity
    % count / height / initial-distribution settings. We accept either
    %   obj.Config.Entities.Transmitters / Receivers  (canonical, used by
    %       config/_base_/factories/scenario_factory.m)
    % or
    %   obj.Config.Transmitter / Receiver             (flat alternate, kept
    %       so unit tests can wire a small struct without rebuilding the
    %       whole factory tree).

    switch entityType
        case 'Transmitter'
            pluralKey = 'Transmitters';
            singularKey = 'Transmitter';
        case 'Receiver'
            pluralKey = 'Receivers';
            singularKey = 'Receiver';
        otherwise
            error('CSRD:Construction:UnknownEntityType', ...
                'createEntity: unsupported entityType "%s" (expected Transmitter or Receiver).', ...
                entityType);
    end

    if isfield(obj.Config, 'Entities') && isstruct(obj.Config.Entities) ...
            && isfield(obj.Config.Entities, pluralKey)
        entityConfig = obj.Config.Entities.(pluralKey);
    elseif isfield(obj.Config, singularKey)
        entityConfig = obj.Config.(singularKey);
    else
        error('CSRD:Construction:MissingEntityConfig', ...
            ['createEntity: obj.Config does not carry an Entities.%s ', ...
             '(or top-level %s) struct. Phase 3 requires this slice so ', ...
             'mobility / count / height settings are explicit.'], ...
            pluralKey, singularKey);
    end
end
