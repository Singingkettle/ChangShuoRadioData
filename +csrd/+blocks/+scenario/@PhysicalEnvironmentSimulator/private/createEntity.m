function entity = createEntity(obj, entityType, entityID, frameId)
    % createEntity - Create a single entity with Snapshot-based state management
    %
    % Creates a comprehensive entity structure with Snapshot-based state
    % management. Each Snapshot contains:
    %   - Physical state (Position, Velocity, Orientation)
    %   - Communication state (Frequency, Bandwidth, Modulation - set by CommunicationBehaviorSimulator)
    %   - Temporal state (IsTransmitting, CurrentInterval - updated per frame)
    %
    % DESIGN PRINCIPLE:
    %   Entity is a shared object between PhysicalEnvironmentSimulator and
    %   CommunicationBehaviorSimulator. Each simulator manages its own state domain:
    %   - PhysicalEnvironmentSimulator: Physical state (position, velocity)
    %   - CommunicationBehaviorSimulator: Communication + Temporal state
    %
    % Input Arguments:
    %   entityType - 'Transmitter' or 'Receiver'
    %   entityID - Unique identifier string (e.g., 'Tx1', 'Rx1')
    %   frameId - Frame at which entity is created
    %
    % Output Arguments:
    %   entity - Entity structure with Snapshots array

    entity = struct();
    entity.ID = entityID;
    entity.Type = entityType;
    entity.CreationFrameId = frameId;
    entity.CreationTime = frameId * obj.timeResolution;

    % Initialize Snapshots cell array (one per frame, dynamically expandable)
    % Pre-allocate for expected frame count (will expand if needed)
    entity.Snapshots = cell(1, 100);  % Pre-allocate for up to 100 frames

    % Create initial snapshot for this frame
    initialSnapshot = createInitialSnapshot(obj, entityType, entityID, frameId);
    entity.Snapshots{frameId} = initialSnapshot;

    % Store top-level position for backward compatibility and quick access
    entity.Position = initialSnapshot.Physical.Position;
    entity.Velocity = initialSnapshot.Physical.Velocity;
    entity.Orientation = initialSnapshot.Physical.Orientation;
    entity.AngularVelocity = initialSnapshot.Physical.AngularVelocity;

    % Assign mobility model
    entity.MobilityModel = assignMobilityModel(entityType);

    % Initialize physical properties
    entity.Properties = initializeEntityProperties(obj, entityType);

    % Legacy fields for backward compatibility
    entity.FrameId = frameId;
    entity.StateHistory = [];
    entity.LastUpdateTime = entity.CreationTime;

    obj.logger.debug('Created %s entity %s at position [%.1f, %.1f, %.1f] with Snapshot structure', ...
        entityType, entityID, entity.Position);
end

function snapshot = createInitialSnapshot(obj, entityType, entityID, frameId)
    % createInitialSnapshot - Create the initial Snapshot structure for an entity
    %
    % The Snapshot structure organizes state into three domains:
    %   1. Physical: Position, Velocity, Orientation (managed by PhysicalEnvSimulator)
    %   2. Communication: Frequency, Bandwidth, Modulation (managed by CommBehaviorSimulator)
    %   3. Temporal: IsTransmitting, CurrentInterval (updated per frame)

    snapshot = struct();
    snapshot.FrameId = frameId;
    snapshot.Timestamp = frameId * obj.timeResolution;
    snapshot.EntityID = entityID;
    snapshot.EntityType = entityType;

    % =========== PHYSICAL STATE ===========
    % Managed by PhysicalEnvironmentSimulator
    snapshot.Physical = struct();

    % Initialize position within map boundaries
    if isfield(obj.mapData, 'Boundaries') && ~isempty(obj.mapData.Boundaries)
        bounds = obj.mapData.Boundaries;

        if isfield(bounds, 'MinLatitude')
            % OSM-style boundaries
            snapshot.Physical.Position = [
                randomInRange(obj, bounds.MinLongitude, bounds.MaxLongitude), % X coordinate
                randomInRange(obj, bounds.MinLatitude, bounds.MaxLatitude), % Y coordinate
                randomInRange(obj, 10, 100) % Z coordinate (height)
            ];
        else
            % Grid-style boundaries
            snapshot.Physical.Position = [
                randomInRange(obj, bounds(1), bounds(2)), % X coordinate
                randomInRange(obj, bounds(3), bounds(4)), % Y coordinate
                randomInRange(obj, 10, 100) % Z coordinate (height)
            ];
        end
    else
        % Use default boundaries if not set
        obj.logger.warning('Map boundaries not set, using default boundaries for entity creation');
        snapshot.Physical.Position = [
            randomInRange(obj, -1000, 1000), % X coordinate
            randomInRange(obj, -1000, 1000), % Y coordinate
            randomInRange(obj, 10, 100) % Z coordinate (height)
        ];
    end

    % Initialize velocity and motion parameters
    maxSpeed = getMaxSpeedForEntityType(obj, entityType);
    snapshot.Physical.Velocity = [
        randomInRange(obj, -maxSpeed, maxSpeed), % X velocity (m/s)
        randomInRange(obj, -maxSpeed, maxSpeed), % Y velocity (m/s)
        0 % Z velocity (stationary altitude)
    ];

    % Initialize orientation (azimuth, elevation in degrees)
    snapshot.Physical.Orientation = [
        randi([-180, 180]), % Azimuth
        randi([-30, 30]) % Elevation
    ];

    % Initialize angular velocity (deg/s)
    snapshot.Physical.AngularVelocity = [
        randomInRange(obj, -10, 10), % Azimuth rate
        randomInRange(obj, -5, 5) % Elevation rate
    ];

    % =========== COMMUNICATION STATE ===========
    % Managed by CommunicationBehaviorSimulator (set during scenario initialization)
    % These are "temporal" properties - set once and don't change during scenario
    snapshot.Communication = struct();
    snapshot.Communication.Frequency = 0;  % Center frequency offset (Hz)
    snapshot.Communication.Bandwidth = 0;  % Signal bandwidth (Hz)
    snapshot.Communication.ModulationType = '';  % e.g., 'PSK', 'QAM'
    snapshot.Communication.ModulationOrder = 0;  % e.g., 4, 16, 64
    snapshot.Communication.Power = 0;  % Transmit power (dBm)
    snapshot.Communication.NumAntennas = 1;  % Number of antennas
    snapshot.Communication.Initialized = false;  % Flag: true after CommBehavior sets values

    % =========== TEMPORAL STATE ===========
    % Updated every frame by CommunicationBehaviorSimulator
    snapshot.Temporal = struct();
    snapshot.Temporal.IsTransmitting = false;  % Is entity currently transmitting?
    snapshot.Temporal.CurrentIntervalIdx = 0;  % Current transmission interval index
    snapshot.Temporal.PatternType = '';  % 'Continuous', 'Burst', 'Scheduled', 'Random'
    snapshot.Temporal.StartTime = 0;  % Start time of current transmission
    snapshot.Temporal.EndTime = 0;  % End time of current transmission
end
