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
    %   stepImpl(obj, frameId, scenarioConfig, factoryConfigs): Main scenario instantiation
    %
    % Example:
    %   factory = csrd.factories.ScenarioFactory('Config', scenarioConfig);
    %   [txInstances, rxInstances, layout] = factory(frameId, scenarioParams, factories);

    properties
        % Config: Struct containing scenario factory configuration
        % Expected structure: Config.Factories.Scenario.PhysicalEnvironment and
        %                    Config.Factories.Scenario.CommunicationBehavior
        Config struct
    end

    properties (Access = private)
        logger
        factoryConfig % Stores obj.Config.Factories.Scenario directly
        cachedScenarioBlocks % Cache for instantiated scenario planning blocks

        % Simulator instances (initialized once per scenario)
        physicalEnvironmentSimulator
        communicationBehaviorSimulator

        % Map type selection (determined at setup time)
        selectedMapType char = ''

        % OSM file selection (determined when OSM mode is selected)
        selectedOSMFile char = ''

        % Scenario configuration for map type selection
        currentScenarioConfig struct = struct()

        % Initialization flags
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

        function setupImpl(obj)
            % setupImpl - Initialize scenario factory components
            %
            % This method validates configuration and initializes logging

            if isempty(obj.Config) || ~isstruct(obj.Config)
                error('ScenarioFactory:ConfigError', ...
                'Config property must be a valid struct.');
            end

            % Extract scenario factory configuration
            if isfield(obj.Config, 'Factories') && isfield(obj.Config.Factories, 'Scenario')
                obj.factoryConfig = obj.Config.Factories.Scenario;
            else
                obj.factoryConfig = obj.Config;
            end

            % Validate required dual-component configuration
            if ~isfield(obj.factoryConfig, 'PhysicalEnvironment')
                error('ScenarioFactory:ConfigError', ...
                'Config must contain PhysicalEnvironment configuration.');
            end

            if ~isfield(obj.factoryConfig, 'CommunicationBehavior')
                error('ScenarioFactory:ConfigError', ...
                'Config must contain CommunicationBehavior configuration.');
            end

            obj.logger = csrd.utils.logger.GlobalLogManager.getLogger();

            obj.logger.debug('ScenarioFactory setupImpl initializing with dual-component architecture.');
            obj.logger.debug('Architecture: %s, Version: %s', ...
                obj.factoryConfig.Architecture, obj.factoryConfig.Version);

            % Validate PhysicalEnvironment configuration
            if ~isfield(obj.factoryConfig.PhysicalEnvironment, 'Entities')
                obj.logger.warning('PhysicalEnvironment.Entities not configured, using defaults');
            end

            % Validate CommunicationBehavior configuration
            if ~isfield(obj.factoryConfig.CommunicationBehavior, 'FrequencyAllocation')
                obj.logger.warning('CommunicationBehavior.FrequencyAllocation not configured, using defaults');
            end

            obj.logger.debug('ScenarioFactory setupImpl complete for dual-component scenario generation.');
        end

        function [instantiatedTxs, instantiatedRxs, globalLayout] = stepImpl(obj, frameId, scenarioConfig, factoryConfigs)
            % stepImpl - Instantiate a complete scenario using dual-component architecture
            %
            % This method implements the new dual-component scenario generation approach:
            % 1. PhysicalEnvironmentSimulator - Models physical world, entity positions, mobility
            % 2. CommunicationBehaviorSimulator - Models communication behaviors, frequencies, modulation
            %
            % Syntax:
            %   [txs, rxs, layout] = stepImpl(obj, frameId, scenarioConfig, factoryConfigs)
            %
            % Inputs:
            %   frameId - Current frame identifier
            %   scenarioConfig - Scenario definition with parameter ranges
            %   factoryConfigs - Factory configurations for components
            %
            % Outputs:
            %   instantiatedTxs - Cell array of instantiated transmitter configurations
            %   instantiatedRxs - Cell array of instantiated receiver configurations
            %   globalLayout - Global scenario layout information

            obj.logger.debug('Frame %d: ScenarioFactory stepImpl started for dual-component scenario generation.', frameId);

            try
                % Step 1: Generate frame Id
                obj.logger.debug('Frame %d: Starting dual-component scenario generation', frameId);

                % Step 2: Initialize dual-component simulators if not done
                if ~obj.isSimulatorsInitialized
                    obj.initializeSimulators(scenarioConfig, factoryConfigs);
                    obj.isSimulatorsInitialized = true;
                end

                % Step 3: Update physical environment state
                [entities, environment] = step(obj.physicalEnvironmentSimulator, frameId);
                obj.logger.debug('Frame %d: Physical environment updated with %d entities', frameId, length(entities));

                % Step 4: Update communication behavior
                [txConfigs, rxConfigs, communicationLayout] = step(obj.communicationBehaviorSimulator, frameId, entities, factoryConfigs);
                obj.logger.debug('Frame %d: Communication configurations generated - %d transmitters, %d receivers', ...
                    frameId, length(txConfigs), length(rxConfigs));

                % Step 5: Create output structures directly
                instantiatedTxs = txConfigs;
                instantiatedRxs = rxConfigs;
                globalLayout = communicationLayout;
                globalLayout.FrameId = frameId;
                globalLayout.Environment = environment;

                % Step 6: Store current state for next frame
                obj.storeFrameState(frameId, entities, environment, txConfigs, rxConfigs);

                obj.logger.debug('Frame %d: Scenario generation completed successfully', frameId);

            catch ME
                obj.logger.error('Frame %d: Error during scenario generation. Error: %s', ...
                    frameId, ME.message);
                obj.logger.error('Stack trace: %s', getReport(ME, 'extended', 'hyperlinks', 'off'));

                % Return empty results on error
                instantiatedTxs = {};
                instantiatedRxs = {};
                globalLayout = struct('Error', ME.message, 'FrequencyRange', [0, 0], 'TimeRange', [0, 0]);
            end

            obj.logger.debug('Frame %d: ScenarioFactory stepImpl finished.', frameId);
        end

        function releaseImpl(obj)
            % releaseImpl - Release cached scenario planning blocks and simulators

            obj.logger.debug('ScenarioFactory releaseImpl called.');

            % Release simulator instances
            if ~isempty(obj.physicalEnvironmentSimulator) && islocked(obj.physicalEnvironmentSimulator)
                release(obj.physicalEnvironmentSimulator);
                obj.physicalEnvironmentSimulator = [];
            end

            if ~isempty(obj.communicationBehaviorSimulator) && islocked(obj.communicationBehaviorSimulator)
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

                if isa(block, 'matlab.System') && islocked(block)
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

        % Simulator initialization methods
        function initializeSimulators(obj, scenarioConfig, factoryConfigs)
            % initializeSimulators - Initialize simulators once per scenario
            %
            % This method creates and sets up the physical environment and
            % communication behavior simulators based on the scenario configuration.
            % Simulators are initialized only once per scenario for efficiency.

            obj.logger.debug('Initializing simulators for scenario...');

            % Initialize physical environment simulator
            physicalEnvConfig = obj.getPhysicalEnvironmentConfig(scenarioConfig);
            obj.physicalEnvironmentSimulator = csrd.blocks.scenario.PhysicalEnvironmentSimulator('Config', physicalEnvConfig);
            setup(obj.physicalEnvironmentSimulator);

            % Map initialization is handled internally by PhysicalEnvironmentSimulator

            % Initialize communication behavior simulator
            commBehaviorConfig = obj.getCommunicationBehaviorConfig(scenarioConfig);
            obj.communicationBehaviorSimulator = csrd.blocks.scenario.CommunicationBehaviorSimulator('Config', commBehaviorConfig);
            setup(obj.communicationBehaviorSimulator);

            obj.logger.debug('Simulators initialization completed');
        end

        function mapType = selectMapTypeByRatio(obj, scenarioConfig)
            % selectMapTypeByRatio - Select map type based on configured ratios
            %
            % This method performs a "dice roll" to randomly select between
            % Statistical and OSM map types based on the configured ratios.
            %
            % Input Arguments:
            %   scenarioConfig - Scenario configuration containing map type ratios
            %
            % Output Arguments:
            %   mapType - Selected map type ('Statistical' or 'OSM')

            % Default ratios if not configured
            statisticalRatio = 1.0; % Default to 100 % Statistical
            osmRatio = 0.0;

            % First priority: Factory configuration ratios
            if isfield(obj.factoryConfig, 'PhysicalEnvironment') && ...
                    isfield(obj.factoryConfig.PhysicalEnvironment, 'MapTypeRatio')

                ratioConfig = obj.factoryConfig.PhysicalEnvironment.MapTypeRatio;
                obj.logger.debug('Using map type ratios from factory PhysicalEnvironment configuration');

                if isfield(ratioConfig, 'StatisticalRatio')
                    statisticalRatio = ratioConfig.StatisticalRatio;
                end

                if isfield(ratioConfig, 'OSMRatio')
                    osmRatio = ratioConfig.OSMRatio;
                end

                % Second priority: Scenario config PhysicalEnvironment structure
            elseif isfield(scenarioConfig, 'PhysicalEnvironment') && ...
                    isfield(scenarioConfig.PhysicalEnvironment, 'MapTypeRatio')

                ratioConfig = scenarioConfig.PhysicalEnvironment.MapTypeRatio;
                obj.logger.debug('Using map type ratios from scenario PhysicalEnvironment configuration');

                if isfield(ratioConfig, 'StatisticalRatio')
                    statisticalRatio = ratioConfig.StatisticalRatio;
                end

                if isfield(ratioConfig, 'OSMRatio')
                    osmRatio = ratioConfig.OSMRatio;
                end

                % Third priority: Legacy Environment configuration
            elseif isfield(scenarioConfig, 'Environment') && ...
                    isfield(scenarioConfig.Environment, 'MapTypeRatio')

                ratioConfig = scenarioConfig.Environment.MapTypeRatio;
                obj.logger.debug('Using map type ratios from legacy Environment configuration');

                if isfield(ratioConfig, 'StatisticalRatio')
                    statisticalRatio = ratioConfig.StatisticalRatio;
                end

                if isfield(ratioConfig, 'OSMRatio')
                    osmRatio = ratioConfig.OSMRatio;
                end

            end

            % Validate ratios
            totalRatio = statisticalRatio + osmRatio;

            if abs(totalRatio - 1.0) > 0.01 % Allow small floating point errors
                obj.logger.warning('Map type ratios do not sum to 1.0 (Total: %.3f). Normalizing...', totalRatio);

                if totalRatio > 0
                    statisticalRatio = statisticalRatio / totalRatio;
                    osmRatio = osmRatio / totalRatio;
                else
                    % Fallback to 100% Statistical
                    statisticalRatio = 1.0;
                    osmRatio = 0.0;
                end

            end

            % Perform random selection ("dice roll")
            randomValue = rand(); % Generate random number between 0 and 1

            if randomValue <= statisticalRatio
                mapType = 'Statistical';
                obj.logger.debug('Dice roll: %.3f <= %.3f -> Selected Statistical mode', randomValue, statisticalRatio);
            else
                mapType = 'OSM';
                obj.logger.debug('Dice roll: %.3f > %.3f -> Selected OSM mode', randomValue, statisticalRatio);
            end

            obj.logger.debug('Map type selection: Statistical=%.1f%%, OSM=%.1f%%, Selected=%s', ...
                statisticalRatio * 100, osmRatio * 100, mapType);
        end

        function osmFile = selectRandomOSMFile(obj, scenarioConfig)
            % selectRandomOSMFile - Randomly select an OSM file from downloaded data
            %
            % This method scans the OSM data directory and randomly selects
            % one OSM file to ensure scenario diversity.
            %
            % Input Arguments:
            %   scenarioConfig - Scenario configuration containing OSM directory settings
            %
            % Output Arguments:
            %   osmFile - Path to selected OSM file (empty if none found)

            osmFile = '';

            % Check if specific OSM file is configured (override)
            % First priority: Factory configuration
            if isfield(obj.factoryConfig, 'PhysicalEnvironment') && ...
                    isfield(obj.factoryConfig.PhysicalEnvironment, 'OSMMapFile') && ...
                    ~isempty(obj.factoryConfig.PhysicalEnvironment.OSMMapFile)

                osmFile = obj.factoryConfig.PhysicalEnvironment.OSMMapFile;
                obj.logger.debug('Using OSM file from factory PhysicalEnvironment configuration');

                if isfile(osmFile)
                    obj.logger.debug('Using specified OSM file: %s', osmFile);
                    return;
                else
                    obj.logger.warning('Specified OSM file not found: %s. Using random selection.', osmFile);
                end

                % Second priority: Scenario PhysicalEnvironment configuration
            elseif isfield(scenarioConfig, 'PhysicalEnvironment') && ...
                    isfield(scenarioConfig.PhysicalEnvironment, 'OSMMapFile') && ...
                    ~isempty(scenarioConfig.PhysicalEnvironment.OSMMapFile)

                osmFile = scenarioConfig.PhysicalEnvironment.OSMMapFile;
                obj.logger.debug('Using OSM file from scenario PhysicalEnvironment configuration');

                if isfile(osmFile)
                    obj.logger.debug('Using specified OSM file: %s', osmFile);
                    return;
                else
                    obj.logger.warning('Specified OSM file not found: %s. Using random selection.', osmFile);
                end

                % Third priority: Legacy Environment configuration
            elseif isfield(scenarioConfig, 'Environment') && ...
                    isfield(scenarioConfig.Environment, 'OSMMapFile') && ...
                    ~isempty(scenarioConfig.Environment.OSMMapFile)

                osmFile = scenarioConfig.Environment.OSMMapFile;
                obj.logger.debug('Using OSM file from legacy Environment configuration');

                if isfile(osmFile)
                    obj.logger.debug('Using specified OSM file: %s', osmFile);
                    return;
                else
                    obj.logger.warning('Specified OSM file not found: %s. Using random selection.', osmFile);
                end

            end

            % Get OSM data directory
            % Get project root directory based on current file location
            currentFilePath = fileparts(mfilename('fullpath'));
            projectRoot = fileparts(fileparts(currentFilePath)); % Go up two levels from +csrd/+factories
            osmDataDir = fullfile(projectRoot, 'data', 'map', 'osm'); % Default

            % Check for OSM data directory configuration
            % First priority: Factory configuration
            if isfield(obj.factoryConfig, 'PhysicalEnvironment') && ...
                    isfield(obj.factoryConfig.PhysicalEnvironment, 'OSMDataDirectory')
                configuredDir = obj.factoryConfig.PhysicalEnvironment.OSMDataDirectory;
                obj.logger.debug('Using OSM data directory from factory PhysicalEnvironment configuration');
                % If configured directory is relative, make it relative to project root
                if ~obj.isAbsolutePath(configuredDir)
                    osmDataDir = fullfile(projectRoot, configuredDir);
                else
                    osmDataDir = configuredDir;
                end

                % Second priority: Scenario PhysicalEnvironment configuration
            elseif isfield(scenarioConfig, 'PhysicalEnvironment') && ...
                    isfield(scenarioConfig.PhysicalEnvironment, 'OSMDataDirectory')
                configuredDir = scenarioConfig.PhysicalEnvironment.OSMDataDirectory;
                obj.logger.debug('Using OSM data directory from scenario PhysicalEnvironment configuration');
                % If configured directory is relative, make it relative to project root
                if ~obj.isAbsolutePath(configuredDir)
                    osmDataDir = fullfile(projectRoot, configuredDir);
                else
                    osmDataDir = configuredDir;
                end

                % Third priority: Legacy Environment configuration
            elseif isfield(scenarioConfig, 'Environment') && ...
                    isfield(scenarioConfig.Environment, 'OSMDataDirectory')
                configuredDir = scenarioConfig.Environment.OSMDataDirectory;
                obj.logger.debug('Using OSM data directory from legacy Environment configuration');
                % If configured directory is relative, make it relative to project root
                if ~obj.isAbsolutePath(configuredDir)
                    osmDataDir = fullfile(projectRoot, configuredDir);
                else
                    osmDataDir = configuredDir;
                end

            end

            % Get file pattern
            filePattern = '*.osm'; % Default

            % First priority: Factory configuration
            if isfield(obj.factoryConfig, 'PhysicalEnvironment') && ...
                    isfield(obj.factoryConfig.PhysicalEnvironment, 'OSMFilePattern')
                filePattern = obj.factoryConfig.PhysicalEnvironment.OSMFilePattern;
                obj.logger.debug('Using OSM file pattern from factory PhysicalEnvironment configuration: %s', filePattern);
                % Second priority: Scenario PhysicalEnvironment configuration
            elseif isfield(scenarioConfig, 'PhysicalEnvironment') && ...
                    isfield(scenarioConfig.PhysicalEnvironment, 'OSMFilePattern')
                filePattern = scenarioConfig.PhysicalEnvironment.OSMFilePattern;
                obj.logger.debug('Using OSM file pattern from scenario PhysicalEnvironment configuration: %s', filePattern);
                % Third priority: Legacy Environment configuration
            elseif isfield(scenarioConfig, 'Environment') && ...
                    isfield(scenarioConfig.Environment, 'OSMFilePattern')
                filePattern = scenarioConfig.Environment.OSMFilePattern;
                obj.logger.debug('Using OSM file pattern from legacy Environment configuration: %s', filePattern);
            end

            obj.logger.debug('Scanning for OSM files in: %s (pattern: %s)', osmDataDir, filePattern);

            % Find all OSM files recursively
            allmFiles = obj.findOSMFiles(osmDataDir, filePattern);

            if isempty(allmFiles)
                obj.logger.warning('No OSM files found in directory: %s', osmDataDir);
                return;
            end

            % Randomly select one file
            selectedIndex = randi(length(allmFiles));
            osmFile = allmFiles{selectedIndex};

            obj.logger.debug('Found %d OSM files, selected: %s', length(allmFiles), osmFile);
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

        % Supporting methods for dual-component architecture
        function physicalEnvConfig = getPhysicalEnvironmentConfig(obj, scenarioConfig)
            % getPhysicalEnvironmentConfig - Extract physical environment configuration
            %
            % This method extracts and processes physical environment configuration
            % from the factory configuration and scenario configuration, giving
            % priority to the factory PhysicalEnvironment section while maintaining
            % backward compatibility with legacy Environment configuration.

            physicalEnvConfig = struct();

            % Primary configuration source: factory PhysicalEnvironment configuration
            if isfield(obj.factoryConfig, 'PhysicalEnvironment')
                obj.logger.debug('Using PhysicalEnvironment configuration from factory configuration');

                % Start with factory PhysicalEnvironment configuration
                physicalEnvConfig = obj.factoryConfig.PhysicalEnvironment;

                % Merge with scenario-specific PhysicalEnvironment configuration if available
                if isfield(scenarioConfig, 'PhysicalEnvironment')
                    obj.logger.debug('Merging with scenario PhysicalEnvironment configuration');
                    physicalEnvConfig = obj.mergeConfigs(physicalEnvConfig, scenarioConfig.PhysicalEnvironment);
                end

                % Validate entity count configuration in Min/Max struct format
                if isfield(physicalEnvConfig, 'Entities')
                    % Keep transmitter count configuration in Min/Max struct format
                    if isfield(physicalEnvConfig.Entities, 'Transmitters') && isfield(physicalEnvConfig.Entities.Transmitters, 'Count')
                        txCount = physicalEnvConfig.Entities.Transmitters.Count;

                        if isstruct(txCount) && isfield(txCount, 'Min') && isfield(txCount, 'Max')
                            obj.logger.debug('Transmitter count configuration: Min=%d, Max=%d', txCount.Min, txCount.Max);
                        end

                    end

                    % Keep receiver count configuration in Min/Max struct format
                    if isfield(physicalEnvConfig.Entities, 'Receivers') && isfield(physicalEnvConfig.Entities.Receivers, 'Count')
                        rxCount = physicalEnvConfig.Entities.Receivers.Count;

                        if isstruct(rxCount) && isfield(rxCount, 'Min') && isfield(rxCount, 'Max')
                            obj.logger.debug('Receiver count configuration: Min=%d, Max=%d', rxCount.Min, rxCount.Max);
                        end

                    end

                end

                % Set up Environment structure for simulator compatibility
                if ~isfield(physicalEnvConfig, 'Environment')
                    physicalEnvConfig.Environment = struct();
                end

                % Map boundaries from Map configuration if available
                if isfield(physicalEnvConfig, 'Map') && isfield(physicalEnvConfig.Map, 'Boundaries')
                    physicalEnvConfig.Environment.MapBoundaries = physicalEnvConfig.Map.Boundaries;
                elseif ~isfield(physicalEnvConfig.Environment, 'MapBoundaries')
                    physicalEnvConfig.Environment.MapBoundaries = [-2000, 2000, -2000, 2000]; % Default
                end

                % Override map type with the one selected by ratio-based selection
                physicalEnvConfig.Environment.MapType = obj.selectedMapType;

                % If OSM mode is selected, pass the randomly selected OSM file
                if strcmp(obj.selectedMapType, 'OSM') && ~isempty(obj.selectedOSMFile)
                    physicalEnvConfig.Environment.OSMMapFile = obj.selectedOSMFile;
                    obj.logger.debug('Physical environment config: MapType=%s, OSMFile=%s (selected by ratio and random)', ...
                        obj.selectedMapType, obj.selectedOSMFile);
                else
                    obj.logger.debug('Physical environment config: MapType=%s (selected by ratio)', obj.selectedMapType);
                end

                % Secondary configuration source: scenarioConfig.PhysicalEnvironment
            elseif isfield(scenarioConfig, 'PhysicalEnvironment')
                obj.logger.debug('Using PhysicalEnvironment configuration from scenario configuration');

                % Direct copy of PhysicalEnvironment configuration
                physicalEnvConfig = scenarioConfig.PhysicalEnvironment;

                % Validate entity count configuration in Min/Max struct format
                if isfield(physicalEnvConfig, 'Entities')
                    % Keep transmitter count configuration in Min/Max struct format
                    if isfield(physicalEnvConfig.Entities, 'Transmitters') && isfield(physicalEnvConfig.Entities.Transmitters, 'Count')
                        txCount = physicalEnvConfig.Entities.Transmitters.Count;

                        if isstruct(txCount) && isfield(txCount, 'Min') && isfield(txCount, 'Max')
                            obj.logger.debug('Transmitter count configuration: Min=%d, Max=%d', txCount.Min, txCount.Max);
                        end

                    end

                    % Keep receiver count configuration in Min/Max struct format
                    if isfield(physicalEnvConfig.Entities, 'Receivers') && isfield(physicalEnvConfig.Entities.Receivers, 'Count')
                        rxCount = physicalEnvConfig.Entities.Receivers.Count;

                        if isstruct(rxCount) && isfield(rxCount, 'Min') && isfield(rxCount, 'Max')
                            obj.logger.debug('Receiver count configuration: Min=%d, Max=%d', rxCount.Min, rxCount.Max);
                        end

                    end

                end

                % Set up Environment structure for simulator compatibility
                if ~isfield(physicalEnvConfig, 'Environment')
                    physicalEnvConfig.Environment = struct();
                end

                % Map boundaries from Map configuration if available
                if isfield(physicalEnvConfig, 'Map') && isfield(physicalEnvConfig.Map, 'Boundaries')
                    physicalEnvConfig.Environment.MapBoundaries = physicalEnvConfig.Map.Boundaries;
                elseif ~isfield(physicalEnvConfig.Environment, 'MapBoundaries')
                    physicalEnvConfig.Environment.MapBoundaries = [-2000, 2000, -2000, 2000]; % Default
                end

                % Override map type with the one selected by ratio-based selection
                physicalEnvConfig.Environment.MapType = obj.selectedMapType;

                % If OSM mode is selected, pass the randomly selected OSM file
                if strcmp(obj.selectedMapType, 'OSM') && ~isempty(obj.selectedOSMFile)
                    physicalEnvConfig.Environment.OSMMapFile = obj.selectedOSMFile;
                    obj.logger.debug('Physical environment config: MapType=%s, OSMFile=%s (selected by ratio and random)', ...
                        obj.selectedMapType, obj.selectedOSMFile);
                else
                    obj.logger.debug('Physical environment config: MapType=%s (selected by ratio)', obj.selectedMapType);
                end

            else
                % Fallback: Legacy configuration support
                obj.logger.debug('PhysicalEnvironment not found, using legacy Environment configuration');

                % Map configuration from legacy Environment section
                if isfield(scenarioConfig, 'Environment')
                    physicalEnvConfig.Environment = scenarioConfig.Environment;
                else
                    % Default configuration
                    physicalEnvConfig.Environment.MapBoundaries = [-2000, 2000, -2000, 2000];
                    physicalEnvConfig.Environment.OSMMapFile = '';
                end

                % Override map type with the one selected by ratio-based selection
                physicalEnvConfig.Environment.MapType = obj.selectedMapType;

                % If OSM mode is selected, pass the randomly selected OSM file
                if strcmp(obj.selectedMapType, 'OSM') && ~isempty(obj.selectedOSMFile)
                    physicalEnvConfig.Environment.OSMMapFile = obj.selectedOSMFile;
                end

                % Entity configuration from legacy Transmitters/Receivers sections
                if isfield(scenarioConfig, 'Transmitters') && isfield(scenarioConfig.Transmitters, 'Count')
                    physicalEnvConfig.Entities.Transmitters.Count = scenarioConfig.Transmitters.Count;
                else
                    physicalEnvConfig.Entities.Transmitters.Count = struct('Min', 2, 'Max', 6); % Default
                end

                if isfield(scenarioConfig, 'Receivers') && isfield(scenarioConfig.Receivers, 'Count')
                    physicalEnvConfig.Entities.Receivers.Count = scenarioConfig.Receivers.Count;
                else
                    physicalEnvConfig.Entities.Receivers.Count = struct('Min', 1, 'Max', 3); % Default
                end

                % Default mobility configuration
                physicalEnvConfig.Mobility.DefaultModel = 'RandomWalk';
                physicalEnvConfig.Mobility.EnableCollisionAvoidance = true;

                % Default environmental factors
                physicalEnvConfig.Environment.Weather.Enable = true;
            end

            % Legacy map configuration for backward compatibility
            if strcmp(obj.selectedMapType, 'OSM')
                physicalEnvConfig.Map.Type = 'OSM';
            else
                physicalEnvConfig.Map.Type = 'Grid';
            end

            physicalEnvConfig.Map.Boundaries = physicalEnvConfig.Environment.MapBoundaries;

            % Time resolution - prioritize from different configuration sources
            if isfield(physicalEnvConfig, 'TimeResolution')
                % Already set from PhysicalEnvironment configuration
                obj.logger.debug('Using time resolution from PhysicalEnvironment: %.3f seconds', physicalEnvConfig.TimeResolution);
            elseif isfield(scenarioConfig, 'Environment') && isfield(scenarioConfig.Environment, 'TimeResolution')
                physicalEnvConfig.TimeResolution = scenarioConfig.Environment.TimeResolution;
                obj.logger.debug('Using time resolution from legacy Environment: %.3f seconds', physicalEnvConfig.TimeResolution);
            elseif isfield(scenarioConfig, 'Timing') && isfield(scenarioConfig.Timing, 'FrameResolution')
                physicalEnvConfig.TimeResolution = scenarioConfig.Timing.FrameResolution;
                obj.logger.debug('Using time resolution from Timing: %.3f seconds', physicalEnvConfig.TimeResolution);
            else
                physicalEnvConfig.TimeResolution = 0.1; % 0.1 second default
                obj.logger.debug('Using default time resolution: %.3f seconds', physicalEnvConfig.TimeResolution);
            end

        end

        function commBehaviorConfig = getCommunicationBehaviorConfig(obj, scenarioConfig)
            % getCommunicationBehaviorConfig - Extract communication behavior configuration
            %
            % This method extracts and processes communication behavior configuration
            % from the factory configuration and scenario configuration, giving
            % priority to the factory CommunicationBehavior section while providing
            % reasonable defaults for missing configuration elements.

            commBehaviorConfig = struct();

            % Primary configuration source: factory CommunicationBehavior configuration
            if isfield(obj.factoryConfig, 'CommunicationBehavior')
                obj.logger.debug('Using CommunicationBehavior configuration from factory configuration');

                % Start with factory CommunicationBehavior configuration
                commBehaviorConfig = obj.factoryConfig.CommunicationBehavior;

                % Merge with scenario-specific CommunicationBehavior configuration if available
                if isfield(scenarioConfig, 'CommunicationBehavior')
                    obj.logger.debug('Merging with scenario CommunicationBehavior configuration');
                    commBehaviorConfig = obj.mergeConfigs(commBehaviorConfig, scenarioConfig.CommunicationBehavior);
                end

                % Secondary configuration source: scenarioConfig.CommunicationBehavior
            elseif isfield(scenarioConfig, 'CommunicationBehavior')
                obj.logger.debug('Using CommunicationBehavior configuration from scenario configuration');

                % Direct copy of CommunicationBehavior configuration
                commBehaviorConfig = scenarioConfig.CommunicationBehavior;

            else
                obj.logger.debug('CommunicationBehavior not found, using default configuration');

                % Default frequency allocation configuration
                commBehaviorConfig.FrequencyAllocation.Strategy = 'ReceiverCentric';
                commBehaviorConfig.FrequencyAllocation.MinSeparation = 100e3; % 100 kHz
                commBehaviorConfig.FrequencyAllocation.MaxOverlap = 0.1; % 10 % overlap
                commBehaviorConfig.FrequencyAllocation.GuardBands = 50e3; % 50 kHz
                commBehaviorConfig.FrequencyAllocation.CollisionAvoidance = true;

                % Default modulation selection configuration
                commBehaviorConfig.ModulationSelection.Strategy = 'Random';
                commBehaviorConfig.ModulationSelection.PreferredSchemes = {'PSK', 'QAM', 'OFDM'};
                commBehaviorConfig.ModulationSelection.QualityThresholds.SNR = 15; % dB
                commBehaviorConfig.ModulationSelection.QualityThresholds.Bandwidth = 1e6; % Hz

                % Default transmission pattern configuration
                commBehaviorConfig.TransmissionPattern.DefaultType = 'Continuous';
                commBehaviorConfig.TransmissionPattern.TypeDistribution = [0.6, 0.3, 0.1]; % [Continuous, Burst, Scheduled]

                % Default burst parameters
                commBehaviorConfig.TransmissionPattern.Burst.DurationRange = [0.01, 0.1]; % seconds
                commBehaviorConfig.TransmissionPattern.Burst.PeriodRange = [0.1, 1.0]; % seconds
                commBehaviorConfig.TransmissionPattern.Burst.DutyCycleRange = [0.1, 0.8];

                % Default scheduled parameters
                commBehaviorConfig.TransmissionPattern.Scheduled.TimeSlotDuration = 0.01; % seconds
                commBehaviorConfig.TransmissionPattern.Scheduled.FrameLength = 0.1; % seconds
                commBehaviorConfig.TransmissionPattern.Scheduled.CoordinationStrategy = 'TDMA';

                % Default power control configuration
                commBehaviorConfig.PowerControl.Strategy = 'LinkBudget';
                commBehaviorConfig.PowerControl.DefaultPower = 20; % dBm
                commBehaviorConfig.PowerControl.PowerRange = [10, 30]; % dBm
                commBehaviorConfig.PowerControl.MaxPower = 30; % dBm
                commBehaviorConfig.PowerControl.TargetSNR = 15; % dB
                commBehaviorConfig.PowerControl.Margin = 10; % dB

                % Default interference management configuration
                commBehaviorConfig.InterferenceManagement.EnableCollisionAvoidance = true;
                commBehaviorConfig.InterferenceManagement.InterferenceThreshold = -80; % dBm
                commBehaviorConfig.InterferenceManagement.CoordinationStrategy = 'Distributed';
                commBehaviorConfig.InterferenceManagement.MaxIterations = 10;

                % Default QoS configuration
                commBehaviorConfig.QoS.PriorityLevels = 3;
                commBehaviorConfig.QoS.DelayConstraints = [0.001, 0.01, 0.1]; % seconds
                commBehaviorConfig.QoS.ThroughputRequirements = [1e6, 5e5, 1e5]; % bps
            end

            % Ensure all required fields are present with sensible defaults
            if ~isfield(commBehaviorConfig, 'FrequencyAllocation') || ~isfield(commBehaviorConfig.FrequencyAllocation, 'Strategy')
                commBehaviorConfig.FrequencyAllocation.Strategy = 'ReceiverCentric';
            end

            if ~isfield(commBehaviorConfig.FrequencyAllocation, 'MinSeparation')
                commBehaviorConfig.FrequencyAllocation.MinSeparation = 100e3; % 100 kHz
            end

            if ~isfield(commBehaviorConfig.FrequencyAllocation, 'MaxOverlap')
                commBehaviorConfig.FrequencyAllocation.MaxOverlap = 0.1; % 10 % overlap
            end

            if ~isfield(commBehaviorConfig, 'PowerControl') || ~isfield(commBehaviorConfig.PowerControl, 'MaxPower')

                if ~isfield(commBehaviorConfig, 'PowerControl')
                    commBehaviorConfig.PowerControl = struct();
                end

                commBehaviorConfig.PowerControl.MaxPower = 30; % dBm
            end

            obj.logger.debug('Communication behavior configuration extracted with strategy: %s', ...
                commBehaviorConfig.FrequencyAllocation.Strategy);
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
