classdef ScenarioFactory < matlab.System
    % ScenarioFactory - Scenario instantiation and layout planning factory
    %
    % This factory is responsible for instantiating specific scenarios based on
    % dual-component architecture: PhysicalEnvironment and CommunicationBehavior.
    % It determines transmitter and receiver types, geographical distribution,
    % and transmission behaviors including timing, frequency allocation, and
    % bandwidth assignment.
    %
    % Properties:
    %   Config (struct): Configuration structure containing scenario factory
    %                   configuration with PhysicalEnvironment and CommunicationBehavior
    %
    % Methods:
    %   ScenarioFactory(varargin): Constructor
    %   stepImpl(obj, frameId): Main scenario instantiation
    %
    % Example:
    %   factory = csrd.factories.ScenarioFactory('Config', factoryConfigs);
    %   [txInstances, rxInstances, layout] = factory(frameId);

    properties
        % Config: Struct containing scenario factory configuration
        % Expected structure: Config.Factories.Scenario.PhysicalEnvironment and
        %                    Config.Factories.Scenario.CommunicationBehavior
        Config struct
    end

    properties (Access = private)
        logger
        factoryConfig       % Scenario-specific configuration (ONLY this factory's config)
        cachedScenarioBlocks
        currentScenarioConfig  % Current frame's scenario configuration

        % Simulator instances
        physicalEnvironmentSimulator
        communicationBehaviorSimulator

        % Map selection state
        selectedMapType char = ''
        selectedOSMFile char = ''

        % Initialization flag
        isSimulatorsInitialized logical = false
    end

    methods

        function obj = ScenarioFactory(varargin)
            % ScenarioFactory - Constructor for scenario factory
            %
            % Syntax:
            %   obj = ScenarioFactory()
            %   obj = ScenarioFactory('Config', configStruct)
            %
            % Inputs:
            %   varargin - Name-value pairs for configuration

            setProperties(obj, nargin, varargin{:});
            obj.cachedScenarioBlocks = containers.Map;
            % Logger initialization in setupImpl to ensure Config is available
        end

    end

    methods (Access = protected)

        function validateInputsImpl(~, ~)
        end

        function setupImpl(obj)
            % setupImpl - Initialize scenario factory components
            %
            % DESIGN PRINCIPLE:
            %   ScenarioFactory receives ONLY its own config (scenario blueprint).
            %   It does NOT need access to other factory configs.
            %   All type lists and parameter ranges for scenario planning are
            %   defined in scenario_factory.m.

            if isempty(obj.Config) || ~isstruct(obj.Config)
                error('ScenarioFactory:ConfigError', 'Config must be a valid struct.');
            end

            % Config should be scenario config directly (no nested 'Scenario' field)
            obj.factoryConfig = obj.Config;

            % Validate dual-component configuration
            if ~isfield(obj.factoryConfig, 'PhysicalEnvironment')
                error('ScenarioFactory:ConfigError', 'PhysicalEnvironment configuration required.');
            end
            if ~isfield(obj.factoryConfig, 'CommunicationBehavior')
                error('ScenarioFactory:ConfigError', 'CommunicationBehavior configuration required.');
            end

            obj.logger = csrd.utils.logger.GlobalLogManager.getLogger();
            obj.validateMapConfiguration();
            obj.logger.debug('ScenarioFactory initialized: %s v%s', ...
                obj.factoryConfig.Architecture, obj.factoryConfig.Version);
        end

        function [instantiatedTxs, instantiatedRxs, globalLayout] = stepImpl(obj, frameId)
            % stepImpl - Generate scenario for a frame
            %
            % Uses dual-component architecture:
            % 1. PhysicalEnvironmentSimulator - Entity positions and mobility
            % 2. CommunicationBehaviorSimulator - Frequencies, modulation, behaviors

            try
                % Initialize simulators on first call
                if ~obj.isSimulatorsInitialized
                    obj.initializeSimulators();
                    obj.isSimulatorsInitialized = true;
                end

                % Update physical environment
                [entities, environment] = step(obj.physicalEnvironmentSimulator, frameId);

                % Generate communication configurations (no config parameter needed)
                % The CommunicationBehaviorSimulator uses its obj.Config set during construction
                [txConfigs, rxConfigs, communicationLayout] = ...
                    step(obj.communicationBehaviorSimulator, frameId, entities);

                % Build output
                instantiatedTxs = txConfigs;
                instantiatedRxs = rxConfigs;
                globalLayout = communicationLayout;
                globalLayout.FrameId = frameId;
                globalLayout.Environment = environment;
                if isfield(communicationLayout, 'Entities') && ~isempty(communicationLayout.Entities)
                    globalLayout.Entities = communicationLayout.Entities;
                else
                    globalLayout.Entities = entities;  % Include entities with Snapshots
                end

                obj.storeFrameState(frameId, entities, environment, txConfigs, rxConfigs);
                obj.logger.debug('Frame %d: Generated %d Tx, %d Rx', frameId, length(txConfigs), length(rxConfigs));

            catch ME
                if contains(ME.identifier, 'SkipScenario') || ...
                        contains(ME.identifier, 'NoBuildingData')
                    rethrow(ME);
                end
                obj.logger.error('Frame %d: Scenario generation failed: %s', frameId, ME.message);
                instantiatedTxs = {};
                instantiatedRxs = {};
                globalLayout = struct('Error', ME.message);
            end
        end

        function releaseImpl(obj)
            % releaseImpl - Release cached scenario planning blocks and simulators

            obj.logger.debug('ScenarioFactory releaseImpl called.');

            % Release simulator instances
            if ~isempty(obj.physicalEnvironmentSimulator) && isLocked(obj.physicalEnvironmentSimulator)
                release(obj.physicalEnvironmentSimulator);
                obj.physicalEnvironmentSimulator = [];
            end

            if ~isempty(obj.communicationBehaviorSimulator) && isLocked(obj.communicationBehaviorSimulator)
                release(obj.communicationBehaviorSimulator);
                obj.communicationBehaviorSimulator = [];
            end

            % Reset initialization flags and map type selection
            obj.isSimulatorsInitialized = false;
            obj.selectedMapType = '';
            obj.selectedOSMFile = '';
            obj.currentScenarioConfig = struct();

            % Release cached blocks
            blockKeys = keys(obj.cachedScenarioBlocks);

            for i = 1:length(blockKeys)
                block = obj.cachedScenarioBlocks(blockKeys{i});

                if isa(block, 'matlab.System') && isLocked(block)
                    release(block);
                end

            end

            remove(obj.cachedScenarioBlocks, keys(obj.cachedScenarioBlocks));
            obj.logger.debug('All cached scenario planning blocks and simulators released.');
        end

        function resetImpl(obj)
            % resetImpl - Reset cached scenario planning blocks

            obj.logger.debug('ScenarioFactory resetImpl called.');
            blockKeys = keys(obj.cachedScenarioBlocks);

            for i = 1:length(blockKeys)
                block = obj.cachedScenarioBlocks(blockKeys{i});

                if isa(block, 'matlab.System')
                    reset(block);
                end

            end

            obj.logger.debug('All cached scenario planning blocks reset.');

            % Reset map type selection for new scenario
            obj.selectedMapType = '';
            obj.selectedOSMFile = '';
            obj.currentScenarioConfig = struct();
        end

        function initializeSimulators(obj)
            % initializeSimulators - Initialize simulators once per scenario

            obj.logger.debug('Initializing scenario simulators...');

            % Select map type and OSM file (if applicable)
            obj.selectedMapType = obj.selectMapTypeByRatio();
            if strcmp(obj.selectedMapType, 'OSM')
                obj.selectedOSMFile = obj.selectRandomOSMFile();
                if isempty(obj.selectedOSMFile)
                    obj.logger.warning('No OSM files available for OSM scenario selection. Falling back to Statistical mode.');
                    obj.selectedMapType = 'Statistical';
                end
            end

            % Initialize physical environment simulator
            physicalEnvConfig = obj.getPhysicalEnvironmentConfig();
            obj.physicalEnvironmentSimulator = csrd.blocks.scenario.PhysicalEnvironmentSimulator('Config', physicalEnvConfig);

            try
                setup(obj.physicalEnvironmentSimulator);
            catch ME_phys
                if contains(ME_phys.identifier, 'NoBuildingData')
                    error('ScenarioFactory:SkipScenario', ...
                        'OSM map has no building data, cannot run RayTracing. Skipping scenario. (%s)', ME_phys.message);
                else
                    rethrow(ME_phys);
                end
            end

            % Initialize communication behavior simulator
            commBehaviorConfig = obj.getCommunicationBehaviorConfig();
            obj.communicationBehaviorSimulator = csrd.blocks.scenario.CommunicationBehaviorSimulator('Config', commBehaviorConfig);
            setup(obj.communicationBehaviorSimulator);

            obj.logger.debug('Simulators initialized');
        end

        function mapType = selectMapTypeByRatio(obj)
            % selectMapTypeByRatio - Select map/channel modeling type based on configured ratios
            %
            % Two approaches:
            %   Statistical: Virtual scene + statistical channel models
            %   OSM: Real OpenStreetMap + ray tracing channel models

            % Default: Statistical only
            types = {'Statistical'};
            ratios = [1.0];

            % Get types and ratios from Map config
            if isfield(obj.factoryConfig, 'PhysicalEnvironment') && ...
                    isfield(obj.factoryConfig.PhysicalEnvironment, 'Map')
                mapConfig = obj.factoryConfig.PhysicalEnvironment.Map;
                
                if isfield(mapConfig, 'Types') && ~isempty(mapConfig.Types)
                    types = mapConfig.Types;
                end
                if isfield(mapConfig, 'Ratio') && ~isempty(mapConfig.Ratio)
                    ratios = mapConfig.Ratio;
                end
            end

            % Normalize ratios
            ratios = ratios / sum(ratios);

            % Random selection based on cumulative distribution
            r = rand();
            cumRatios = cumsum(ratios);
            idx = find(r <= cumRatios, 1, 'first');
            if isempty(idx)
                idx = 1;
            end
            
            mapType = types{idx};
        end

        function validateMapConfiguration(obj)
            if ~isfield(obj.factoryConfig, 'PhysicalEnvironment') || ...
                    ~isfield(obj.factoryConfig.PhysicalEnvironment, 'Map')
                return;
            end

            mapConfig = obj.factoryConfig.PhysicalEnvironment.Map;
            if ~isfield(mapConfig, 'Types') || isempty(mapConfig.Types)
                error('ScenarioFactory:ConfigError', 'PhysicalEnvironment.Map.Types must not be empty.');
            end

            if ~iscell(mapConfig.Types)
                error('ScenarioFactory:ConfigError', 'PhysicalEnvironment.Map.Types must be a cell array.');
            end

            if isfield(mapConfig, 'Ratio') && ~isempty(mapConfig.Ratio)
                ratios = mapConfig.Ratio;
                if ~isnumeric(ratios) || numel(ratios) ~= numel(mapConfig.Types)
                    error('ScenarioFactory:ConfigError', ...
                        'PhysicalEnvironment.Map.Ratio must be numeric and match Map.Types length.');
                end
                if any(ratios < 0) || sum(ratios) <= 0
                    error('ScenarioFactory:ConfigError', ...
                        'PhysicalEnvironment.Map.Ratio must be non-negative and have positive sum.');
                end
            end
        end

        function osmFile = selectRandomOSMFile(obj)
            % selectRandomOSMFile - Randomly select an OSM file
            %
            % Uses Map.OSM configuration:
            %   Map.OSM.SpecificFile - If set, use this file directly
            %   Map.OSM.DataDirectory - Directory containing OSM files
            %   Map.OSM.FilePattern - Pattern for finding OSM files

            osmFile = '';
            
            % Get OSM config from Map.OSM
            osmConfig = struct();
            if isfield(obj.factoryConfig, 'PhysicalEnvironment') && ...
                    isfield(obj.factoryConfig.PhysicalEnvironment, 'Map') && ...
                    isfield(obj.factoryConfig.PhysicalEnvironment.Map, 'OSM')
                osmConfig = obj.factoryConfig.PhysicalEnvironment.Map.OSM;
            end

            % Check for specific OSM file override
            if isfield(osmConfig, 'SpecificFile') && ~isempty(osmConfig.SpecificFile)
                if isfile(osmConfig.SpecificFile)
                    osmFile = osmConfig.SpecificFile;
                    return;
                end
            end

            % Determine OSM data directory
            currentFilePath = fileparts(mfilename('fullpath'));
            projectRoot = fileparts(fileparts(currentFilePath));
            osmDataDir = fullfile(projectRoot, 'data', 'map', 'osm');

            if isfield(osmConfig, 'DataDirectory') && ~isempty(osmConfig.DataDirectory)
                configuredDir = osmConfig.DataDirectory;
                if ~obj.isAbsolutePath(configuredDir)
                    osmDataDir = fullfile(projectRoot, configuredDir);
                else
                    osmDataDir = configuredDir;
                end
            end

            % Get file pattern
            filePattern = '*.osm';
            if isfield(osmConfig, 'FilePattern') && ~isempty(osmConfig.FilePattern)
                filePattern = osmConfig.FilePattern;
            end

            % Find and select random OSM file
            allFiles = obj.findOSMFiles(osmDataDir, filePattern);
            if ~isempty(allFiles)
                osmFile = allFiles{randi(length(allFiles))};
            end
        end

        function osmFiles = findOSMFiles(obj, baseDir, pattern)
            % findOSMFiles - Recursively find OSM files in directory
            %
            % Input Arguments:
            %   baseDir - Base directory to search
            %   pattern - File pattern (e.g., '*.osm')
            %
            % Output Arguments:
            %   osmFiles - Cell array of full file paths

            osmFiles = {};

            if ~isfolder(baseDir)
                obj.logger.debug('OSM directory does not exist: %s', baseDir);
                return;
            end

            % Get all subdirectories (scene categories)
            dirInfo = dir(baseDir);
            categories = {dirInfo([dirInfo.isdir] & ~startsWith({dirInfo.name}, '.')).name};

            for i = 1:length(categories)
                categoryPath = fullfile(baseDir, categories{i});

                % Find OSM files in this category
                filePattern = fullfile(categoryPath, pattern);
                fileList = dir(filePattern);

                for j = 1:length(fileList)
                    fullPath = fullfile(categoryPath, fileList(j).name);
                    osmFiles{end + 1} = fullPath;
                end

                obj.logger.debug('Category "%s": Found %d OSM files', categories{i}, length(fileList));
            end

            % Shuffle the list for better randomness across categories
            if ~isempty(osmFiles)
                randomOrder = randperm(length(osmFiles));
                osmFiles = osmFiles(randomOrder);
            end

        end

        function physicalEnvConfig = getPhysicalEnvironmentConfig(obj)
            % getPhysicalEnvironmentConfig - Extract physical environment configuration
            %
            % Applies selected map type (Statistical or OSM) and configures
            % appropriate boundaries and channel model settings.

            % Start with configured PhysicalEnvironment
            physicalEnvConfig = obj.factoryConfig.PhysicalEnvironment;

            % Ensure Environment struct exists
            if ~isfield(physicalEnvConfig, 'Environment')
                physicalEnvConfig.Environment = struct();
            end

            % Apply selected map type
            physicalEnvConfig.Environment.MapType = obj.selectedMapType;
            physicalEnvConfig.Map.Type = obj.selectedMapType;

            % Configure based on selected map type
            if strcmp(obj.selectedMapType, 'OSM')
                % OSM mode: use ray tracing channel model
                if ~isempty(obj.selectedOSMFile)
                    physicalEnvConfig.Environment.OSMMapFile = obj.selectedOSMFile;
                    physicalEnvConfig.Map.OSMFile = obj.selectedOSMFile;
                end
                
                % Get channel model from OSM config
                if isfield(physicalEnvConfig, 'Map') && ...
                        isfield(physicalEnvConfig.Map, 'OSM') && ...
                        isfield(physicalEnvConfig.Map.OSM, 'ChannelModel')
                    physicalEnvConfig.Environment.ChannelModel = physicalEnvConfig.Map.OSM.ChannelModel;
                else
                    physicalEnvConfig.Environment.ChannelModel = 'RayTracing';
                end
                
                % OSM boundaries are determined from the OSM file itself
                physicalEnvConfig.Environment.MapBoundaries = [-2000, 2000, -2000, 2000];
                
            else
                % Statistical mode: use statistical channel model
                % Get boundaries from Statistical config
                if isfield(physicalEnvConfig, 'Map') && ...
                        isfield(physicalEnvConfig.Map, 'Statistical') && ...
                        isfield(physicalEnvConfig.Map.Statistical, 'Boundaries')
                    physicalEnvConfig.Environment.MapBoundaries = physicalEnvConfig.Map.Statistical.Boundaries;
                else
                    physicalEnvConfig.Environment.MapBoundaries = [-2000, 2000, -2000, 2000];
                end
                
                % Get channel model from Statistical config
                if isfield(physicalEnvConfig, 'Map') && ...
                        isfield(physicalEnvConfig.Map, 'Statistical') && ...
                        isfield(physicalEnvConfig.Map.Statistical, 'ChannelModel')
                    physicalEnvConfig.Environment.ChannelModel = physicalEnvConfig.Map.Statistical.ChannelModel;
                else
                    physicalEnvConfig.Environment.ChannelModel = 'Statistical';
                end
            end

            % Set map boundaries for compatibility
            physicalEnvConfig.Map.Boundaries = physicalEnvConfig.Environment.MapBoundaries;

            % Time resolution
            if ~isfield(physicalEnvConfig, 'TimeResolution')
                physicalEnvConfig.TimeResolution = 0.1;
            end
        end

        function commBehaviorConfig = getCommunicationBehaviorConfig(obj)
            % getCommunicationBehaviorConfig - Extract communication behavior configuration

            % Use configured CommunicationBehavior directly
            commBehaviorConfig = obj.factoryConfig.CommunicationBehavior;

            % Pass through global time parameters needed by CommBehaviorSim
            if isfield(obj.factoryConfig, 'Global')
                commBehaviorConfig.Global = obj.factoryConfig.Global;
            end

            % Ensure required defaults
            if ~isfield(commBehaviorConfig, 'FrequencyAllocation')
                commBehaviorConfig.FrequencyAllocation = struct();
            end
            if ~isfield(commBehaviorConfig.FrequencyAllocation, 'Strategy')
                commBehaviorConfig.FrequencyAllocation.Strategy = 'ReceiverCentric';
            end
            if ~isfield(commBehaviorConfig.FrequencyAllocation, 'MinSeparation')
                commBehaviorConfig.FrequencyAllocation.MinSeparation = 100e3;
            end

            if ~isfield(commBehaviorConfig, 'PowerControl')
                commBehaviorConfig.PowerControl = struct();
            end
            if ~isfield(commBehaviorConfig.PowerControl, 'MaxPower')
                commBehaviorConfig.PowerControl.MaxPower = 30;
            end
        end

        function storeFrameState(obj, frameId, entities, environment, txConfigs, rxConfigs)
            % storeFrameState - Store current frame state for next frame continuity

            frameState = struct();
            frameState.entities = entities;
            frameState.environment = environment;
            frameState.txConfigs = txConfigs;
            frameState.rxConfigs = rxConfigs;
            frameState.frameId = frameId;
            frameState.timestamp = datetime('now');

            % Store in cached blocks for retrieval
            if ~isKey(obj.cachedScenarioBlocks, 'frameStates')
                obj.cachedScenarioBlocks('frameStates') = containers.Map('KeyType', 'int32', 'ValueType', 'any');
            end

            frameStates = obj.cachedScenarioBlocks('frameStates');
            frameStates(frameId) = frameState;

            % Limit history to last 10 frames to manage memory
            if frameStates.Count > 10
                oldestFrameId = frameId - 10;

                if isKey(frameStates, oldestFrameId)
                    remove(frameStates, oldestFrameId);
                end

            end

        end

        function mergedConfig = mergeConfigs(obj, baseConfig, overrideConfig)
            % mergeConfigs - Merge two configuration structures
            %
            % This method recursively merges configuration structures, with
            % overrideConfig taking precedence over baseConfig.
            %
            % Input Arguments:
            %   baseConfig - Base configuration structure
            %   overrideConfig - Override configuration structure
            %
            % Output Arguments:
            %   mergedConfig - Merged configuration structure

            mergedConfig = baseConfig;

            if ~isstruct(overrideConfig)
                return;
            end

            overrideFields = fieldnames(overrideConfig);

            for i = 1:length(overrideFields)
                fieldName = overrideFields{i};

                if isfield(mergedConfig, fieldName) && isstruct(mergedConfig.(fieldName)) && isstruct(overrideConfig.(fieldName))
                    % Recursively merge nested structures
                    mergedConfig.(fieldName) = obj.mergeConfigs(mergedConfig.(fieldName), overrideConfig.(fieldName));
                else
                    % Override field value
                    mergedConfig.(fieldName) = overrideConfig.(fieldName);
                end

            end

        end

    end

    methods (Access = private, Static)

        function isAbsolute = isAbsolutePath(pathStr)
            % isAbsolutePath - Check if a path is absolute
            %
            % This is a helper function to determine if a given path string
            % represents an absolute path, handling both Windows and Unix-style paths.
            %
            % Input Arguments:
            %   pathStr - Path string to check
            %
            % Output Arguments:
            %   isAbsolute - true if path is absolute, false otherwise

            if isempty(pathStr)
                isAbsolute = false;
                return;
            end

            % Check for Windows absolute paths (e.g., C:\path or \\server\path)
            if ispc
                isAbsolute = length(pathStr) >= 3 && pathStr(2) == ':' && (pathStr(3) == '\' || pathStr(3) == '/') || ...
                    (length(pathStr) >= 2 && pathStr(1) == '\' && pathStr(2) == '\');
            else
                % Check for Unix absolute path (starts with /)
                isAbsolute = ~isempty(pathStr) && pathStr(1) == '/';
            end

        end

    end

end
