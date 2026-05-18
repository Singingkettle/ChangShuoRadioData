classdef PhysicalEnvironmentSimulator < matlab.System
    % PhysicalEnvironmentSimulator - Physical World Environment Modeling and Simulation
    % 中文说明：提供 CSRD 生产链路中的 PhysicalEnvironmentSimulator 实现。
    %
    % This class implements comprehensive physical environment modeling for wireless
    % communication scenarios, including geographical mapping, entity positioning,
    % mobility modeling, and temporal state evolution. It serves as the foundation
    % for realistic scenario generation by simulating the physical world context
    % in which communication takes place.
    %
    % Key Features:
    %   - OSM (OpenStreetMap) integration for realistic geographical contexts
    %   - Multi-entity positioning and tracking (transmitters, receivers, obstacles)
    %   - Advanced mobility models (random walk, waypoint, vehicular, pedestrian)
    %   - Temporal state evolution based on physics-based motion
    %   - Environmental factors (terrain, buildings, weather conditions)
    %   - Collision detection and avoidance for realistic movement
    %   - Configurable time resolution for state updates
    %
    % Physical Modeling Components:
    %   1. Geographical Context: Map boundaries, terrain features, urban layouts
    %   2. Entity Management: Transmitter/receiver positioning and properties
    %   3. Mobility Models: Movement patterns and velocity profiles
    %   4. Environmental Factors: Obstacles, propagation conditions
    %   5. Temporal Evolution: Physics-based state updates over time
    %
    % Syntax:
    %   simulator = PhysicalEnvironmentSimulator('Config', config)
    %   [entities, environment] = simulator(frameId)
    %
    % Properties:
    %   Config - Physical environment configuration structure
    %
    % Methods:
    %   step - Update physical states for current frame
    %   setupImpl - Initialize environment and entities
    %   initializeEntities - Create initial entity positions and states
    %   updateEntityStates - Update positions based on mobility models
    %   applyEnvironmentalConstraints - Apply physical constraints
    %
    % Example:
    %   config = struct();
    %   config.Map.Type = 'OSM';
    %   config.Map.Boundaries = [-1000, 1000, -1000, 1000]; % [xmin, xmax, ymin, ymax]
    %   config.Entities.Transmitters.Count = [2, 6];
    %   config.Entities.Receivers.Count = [1, 3];
    %   config.Mobility.DefaultModel = 'RandomWalk';
    %   config.TimeResolution = frameDurationSec; % seconds per receiver frame
    %
    %   simulator = csrd.blocks.scenario.PhysicalEnvironmentSimulator('Config', config);
    %   [entities, environment] = simulator(1, 0.1, []);

    properties
        % Config - Physical environment configuration structure
        % Type: struct with comprehensive environment modeling parameters
        %
        % Configuration Structure:
        %   .Map - Geographical mapping configuration
        %     .Type - Map type ('OSM', 'Grid', 'Custom')
        %     .Boundaries - Physical boundaries [xmin, xmax, ymin, ymax] (meters)
        %     .Resolution - Spatial resolution for grid-based maps (meters)
        %     .Features - Environmental features (buildings, roads, terrain)
        %
        %   .Entities - Entity configuration and constraints
        %     .Transmitters.Count - Range of transmitter counts [min, max]
        %     .Receivers.Count - Range of receiver counts [min, max]
        %     .InitialDistribution - Initial positioning strategy
        %
        %   .Mobility - Mobility modeling configuration
        %     .DefaultModel - Default mobility model for entities
        %     .Models - Available mobility models and parameters
        %     .Constraints - Movement constraints and boundaries
        %
        %   .Environment - Environmental factors configuration
        %     .Obstacles - Obstacle definitions and properties
        %     .Weather - Weather conditions affecting propagation
        %     .Terrain - Terrain characteristics and elevation
        %
        %   .TimeResolution - Default time resolution (seconds per frame)
        Config struct = struct()
    end

    properties (Access = private)
        % logger - Logging system for debugging and monitoring
        logger

        % currentEnvironment - Current environmental state
        currentEnvironment struct = struct()

        % entityRegistry - Registry of all entities in the environment
        entityRegistry containers.Map

        % mobilityModels - Instantiated mobility models for entities
        mobilityModels containers.Map

        % mapData - Geographical map data and features
        mapData struct = struct()

        % frameHistory - History of previous frames for continuity
        frameHistory containers.Map

        % timeResolution - Time resolution for simulation updates (seconds per frame)
        % This value is initialized from configuration and used internally
        timeResolution double = NaN

        % stateHistory - Cell array storing historical states for scenario replay
        % Used for future scenario replay functionality and debugging
        stateHistory cell = {}

        % Map management properties
        siteViewer % Site viewer object for OSM/ray tracing mode
        mapInitialized logical = false
        BoxSizeKM double = 1 % Default box size for boundary calculation
    end

    methods

        function obj = PhysicalEnvironmentSimulator(varargin)
            % PhysicalEnvironmentSimulator - Constructor for physical environment simulator
            % 中文说明：PhysicalEnvironmentSimulator 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            % Creates a new physical environment simulator with configurable
            % geographical, mobility, and environmental parameters.
            %
            % Syntax:
            %   obj = PhysicalEnvironmentSimulator()
            %   obj = PhysicalEnvironmentSimulator('Config', configStruct)
            %   obj = PhysicalEnvironmentSimulator('PropertyName', PropertyValue, ...)

            setProperties(obj, nargin, varargin{:});
        end

        function history = getStateHistory(obj)
            % getStateHistory - Get complete state history for scenario replay
            % 中文说明：getStateHistory 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            % Returns the complete simulation state history stored during
            % simulation execution, useful for scenario replay, debugging,
            % and post-simulation analysis.
            %
            % Output Arguments:
            %   history - Cell array of frame states chronologically ordered

            history = obj.stateHistory;
        end

        function clearStateHistory(obj)
            % clearStateHistory - Clear stored state history to free memory
            % 中文说明：clearStateHistory 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            % Clears the internal state history to free memory after simulation
            % completion or when history is no longer needed.

            obj.stateHistory = {};
            obj.logger.debug('State history cleared');
        end

        function timeRes = getTimeResolution(obj)
            % getTimeResolution - Get current time resolution setting
            % 中文说明：getTimeResolution 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            % Returns the current time resolution used for simulation updates.
            %
            % Output Arguments:
            %   timeRes - Time resolution in seconds per frame

            timeRes = obj.timeResolution;
        end

        function siteViewer = getSiteViewer(obj)
            % getSiteViewer - Get site viewer for OSM/ray tracing mode
            % 中文说明：getSiteViewer 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            % Returns a physical-environment viewer if available. Production
            % OSM RayTracing keeps the heavy map handle in the channel block
            % to avoid loading the same OSM file twice.

            if isfield(obj.Config, 'Map') && isfield(obj.Config.Map, 'Type') && ...
                    strcmp(obj.Config.Map.Type, 'OSM') && ~isempty(obj.siteViewer)
                siteViewer = obj.siteViewer;
            else
                siteViewer = [];
            end

        end

    end

    methods (Access = protected)
        % Main simulation methods - defined in separate files
        setupImpl(obj)
        [entities, environment] = stepImpl(obj, frameId)
        releaseImpl(obj)
    end

    methods (Access = private)
        % Entity lifecycle methods
        entities = initializeEntities(obj, frameId)
        entities = updateEntityStates(obj, frameId, timeResolution, previousState)

        % Core entity and environment methods
        entity = createEntity(obj, entityType, entityID, frameId)
        previousState = getPreviousState(obj, frameId)
        environment = updateEnvironmentalConditions(obj, frameId, timeResolution)
        entities = applyEnvironmentalConstraints(obj, entities, environment)

        % Initialization helper methods
        initializeEnvironment(obj)
        initializeMobilityModels(obj)

        % Utility methods (Phase 3 note: assignMobilityModel was promoted
        % to a Static, Hidden method below so it can be unit-tested
        % without instantiating the full simulator. The legacy random
        % fallback has been removed.)
        maxSpeed = getMaxSpeedForEntityType(obj, entityType)
        entityProperties = initializeEntityProperties(obj, entityType)
        constrainedPosition = applyBoundaryConstraints(obj, position)
        hasCollision = checkObstacleCollision(obj, position, environment)
        entity = resolveObstacleCollision(obj, entity, environment)
        height = getTerrainHeight(obj, position2D)
        obstacles = generateStaticObstacles(obj)
        value = randomInRange(obj, minVal, maxVal)
        config = getDefaultConfiguration(obj)

        % Map-related utility methods
        features = loadOSMFeatures(obj)
        grid = createGridMap(obj)
        features = loadCustomFeatures(obj)
        weather = updateWeatherConditions(obj, currentWeather, deltaTime)
        obstacles = updateDynamicObstacles(obj, currentObstacles, deltaTime)

        % Map initialization methods
        initializeMapFromConfig(obj)
        [minLat, minLon, maxLat, maxLon] = calculateBoundingBox(obj, lat_deg, lon_deg, size_km)
        initializeOSMMap(obj)
        hasBuildings = checkOSMHasBuildings(obj, osmFile)
        initializeStatisticalMap(obj)
    end

    methods (Static, Hidden)

        function mobilityModel = assignMobilityModel(entityType, entityConfig)
            %ASSIGNMOBILITYMODEL Phase 3 strict-construction mobility resolver.
            % 中文说明：assignMobilityModel 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            % In Phase 3 (audit §3.1.ter / §17.5 P3-followup) the per-entity
            % mobility model MUST be supplied explicitly through the
            % physical-environment configuration. The legacy fallback that
            % randomly chose among `{'RandomWalk', 'Waypoint', 'Stationary'}`
            % for transmitters has been removed because it silently
            % destroyed run reproducibility and could not be tied back to
            % any blueprint provenance.
            %
            % Inputs:
            %   entityType   - 'Transmitter' or 'Receiver' (used for
            %                  diagnostic messages).
            %   entityConfig - Per-entity-type config slice. Accepts either
            %                    entityConfig.Mobility.Model
            %                       (canonical layout produced by
            %                        config/_base_/factories/scenario_factory.m
            %                        and ScenarioFactory.getPhysicalEnvironmentConfig)
            %                  or
            %                    entityConfig.MobilityModel
            %                       (flat alternate kept for unit tests).
            %
            % Output:
            %   mobilityModel - Resolved mobility model name (char vector).
            %
            % Errors:
            %   CSRD:Construction:MissingMobilityModel - Raised when neither
            %       supported field is present / non-empty / a valid string.
            %       The identifier is on the scenario-skip whitelist
            %       (+csrd/+pipeline/+scenario/isScenarioSkipException.m).

            if nargin < 2
                error('CSRD:Construction:MissingMobilityModel', ...
                    ['assignMobilityModel: entityConfig is required ', ...
                     '(Phase 3 removed the random fallback). Pass the ', ...
                     'per-entity-type slice, e.g. ', ...
                     'obj.Config.Entities.Transmitters.']);
            end

            if isstruct(entityConfig) && isfield(entityConfig, 'Mobility') ...
                    && isstruct(entityConfig.Mobility) ...
                    && isfield(entityConfig.Mobility, 'Model')
                candidate = entityConfig.Mobility.Model;
            elseif isstruct(entityConfig) && isfield(entityConfig, 'MobilityModel')
                candidate = entityConfig.MobilityModel;
            else
                error('CSRD:Construction:MissingMobilityModel', ...
                    ['assignMobilityModel: %s entity config lacks an ', ...
                     'explicit Mobility.Model (or MobilityModel) field. ', ...
                     'Phase 3 requires the mobility selection to be ', ...
                     'carried in the blueprint; see ', ...
                     'config/_base_/factories/scenario_factory.m for ', ...
                     'the canonical layout.'], entityType);
            end

            if isstring(candidate)
                candidate = char(candidate);
            end

            if ~ischar(candidate) || isempty(strtrim(candidate))
                error('CSRD:Construction:MissingMobilityModel', ...
                    ['assignMobilityModel: %s entity Mobility.Model must ', ...
                     'be a non-empty char vector / string. Got %s.'], ...
                    entityType, class(candidate));
            end

            mobilityModel = candidate;
        end

    end

end
