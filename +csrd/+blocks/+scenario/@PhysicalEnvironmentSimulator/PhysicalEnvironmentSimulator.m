classdef PhysicalEnvironmentSimulator < matlab.System
    % PhysicalEnvironmentSimulator - Physical World Environment Modeling and Simulation
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
    %   config.TimeResolution = 0.1; % seconds per frame
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
        timeResolution double = 0.1

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
            %
            % Clears the internal state history to free memory after simulation
            % completion or when history is no longer needed.

            obj.stateHistory = {};
            obj.logger.debug('State history cleared');
        end

        function timeRes = getTimeResolution(obj)
            % getTimeResolution - Get current time resolution setting
            %
            % Returns the current time resolution used for simulation updates.
            %
            % Output Arguments:
            %   timeRes - Time resolution in seconds per frame

            timeRes = obj.timeResolution;
        end

        function siteViewer = getSiteViewer(obj)
            % getSiteViewer - Get site viewer for OSM/ray tracing mode
            %
            % Returns the site viewer object if available (OSM mode)

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

        % Utility methods
        mobilityModel = assignMobilityModel(obj, entityType, entityID)
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

end
