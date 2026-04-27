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

    properties (SetAccess = private)
        % Phase 2 §3.4.4: blueprint provenance from the most recent stepImpl call.
        % These mirror the data also injected into globalLayout so Phase 3 can
        % decide whether to consume them via property or dataflow.
        LastValidationReport struct = struct()
        LastBlueprintResamples (1,1) double = 0
        LastBlueprintHash char = ''
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
            % Phase 2 (audit §16.7 / phase-2-blueprint.md §3.4.6):
            %   1. Initialize physical environment + communication behaviour
            %      simulators on the first call.
            %   2. Step physical environment ONCE (entities/environment
            %      remain stable across blueprint resamples).
            %   3. Step communication behaviour, assemble a transitional
            %      ScenarioBlueprint, run BlueprintFeasibilityValidator.
            %   4. If feasible: return (with BlueprintHash + ValidationReport
            %      injected into globalLayout so SimulationRunner can stamp
            %      them downstream).
            %   5. If infeasible AND frameId == 1: release+setup the
            %      communication behaviour simulator (forces re-initialisation
            %      of scenario-level configs incl. frequency allocation) and
            %      retry, up to MaxResamples times.
            %   6. If infeasible AND frameId > 1: throw
            %      CSRD:Blueprint:Unsamplable - mid-scenario blueprints cannot
            %      be resampled because scenario-level configs are frozen at
            %      frame 1 (see CommunicationBehaviorSimulator.scenarioInitialized).
            %   7. If MaxResamples exceeded at frame 1: throw
            %      CSRD:Blueprint:Unsamplable.
            %
            % Phase 2 explicitly removes the previous try/catch silent
            % fallback that turned every non-skip exception into an empty
            % cell + struct('Error', ...) result. Errors now propagate
            % fail-fast (Q-extra C-1).

            if ~obj.isSimulatorsInitialized
                obj.initializeSimulators();
                obj.isSimulatorsInitialized = true;
            end

            [entities, environment] = step(obj.physicalEnvironmentSimulator, frameId);

            [maxResamples, validatorEnabled] = obj.getValidatorConfig();

            attempt = 0;
            lastReport = struct('IsFeasible', true, 'BlueprintHash', '', ...
                'NumChecksRun', 0, 'NumChecksPassed', 0, 'NumChecksFailed', 0, ...
                'FailedChecks', csrd.utils.blueprint.BlueprintFeasibilityValidator.emptyFailureArray(), ...
                'WarnChecks', csrd.utils.blueprint.BlueprintFeasibilityValidator.emptyFailureArray(), ...
                'Provenance', struct('ValidatorVersion', 'p2-disabled', 'Timestamp', ''));

            while true
                attempt = attempt + 1;

                [txConfigs, rxConfigs, communicationLayout] = ...
                    step(obj.communicationBehaviorSimulator, frameId, entities);

                if ~validatorEnabled
                    break;
                end

                blueprint = obj.assembleBlueprint(frameId, txConfigs, rxConfigs, ...
                    communicationLayout, environment);
                lastReport = csrd.utils.blueprint.BlueprintFeasibilityValidator.validate(blueprint);

                if lastReport.IsFeasible
                    break;
                end

                if frameId ~= 1
                    rejectCode = '<unknown>';
                    if ~isempty(lastReport.FailedChecks)
                        rejectCode = lastReport.FailedChecks(1).Code;
                    end
                    error('CSRD:Blueprint:Unsamplable', ...
                        ['Frame %d (mid-scenario) failed feasibility check ''%s''. ', ...
                         'Mid-scenario blueprints cannot be resampled because ', ...
                         'scenario-level configurations are frozen at frame 1.'], ...
                        frameId, rejectCode);
                end

                if attempt >= maxResamples
                    rejectCode = '<unknown>';
                    if ~isempty(lastReport.FailedChecks)
                        rejectCode = lastReport.FailedChecks(1).Code;
                    end
                    error('CSRD:Blueprint:Unsamplable', ...
                        ['Frame 1: %d resample attempts exhausted. Last failed check: ', ...
                         '''%s''. Tighten Profile constraints or raise ', ...
                         'Validator.MaxResamples.'], attempt, rejectCode);
                end

                obj.logger.debug(['Frame 1 attempt %d rejected by ''%s''; ', ...
                    'releasing CommunicationBehaviorSimulator for resample.'], ...
                    attempt, lastReport.FailedChecks(1).Code);
                release(obj.communicationBehaviorSimulator);
                setup(obj.communicationBehaviorSimulator);
            end

            instantiatedTxs = txConfigs;
            instantiatedRxs = rxConfigs;
            globalLayout = communicationLayout;
            globalLayout.FrameId = frameId;
            globalLayout.Environment = environment;
            if isfield(communicationLayout, 'Entities') && ~isempty(communicationLayout.Entities)
                globalLayout.Entities = communicationLayout.Entities;
            else
                globalLayout.Entities = entities;
            end

            globalLayout.BlueprintHash = lastReport.BlueprintHash;
            globalLayout.ValidationReport = lastReport;
            globalLayout.NumBlueprintAttempts = attempt;

            obj.LastValidationReport   = lastReport;
            obj.LastBlueprintResamples = max(0, attempt - 1);
            obj.LastBlueprintHash      = lastReport.BlueprintHash;

            obj.storeFrameState(frameId, entities, environment, txConfigs, rxConfigs);
            obj.logger.debug('Frame %d: Generated %d Tx, %d Rx (attempts=%d)', ...
                frameId, length(txConfigs), length(rxConfigs), attempt);
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
                % Phase 3 (audit §3.4 / §17.5 P3-6): delegate to the shared
                % skip-scenario predicate instead of a hand-maintained
                % `contains(identifier,'NoBuildingData')` magic-string check
                % plus a translation hop to `ScenarioFactory:SkipScenario`.
                % Both identifiers (`NoBuildingData`, `SkipScenario`) are
                % already in the whitelist, so the legacy translation only
                % obscured the original error provenance. We now rethrow as-is
                % and let SimulationRunner / generateSingleFrame route via
                % csrd.utils.scenario.isScenarioSkipException uniformly.
                if csrd.utils.scenario.isScenarioSkipException(ME_phys)
                    rethrow(ME_phys);
                end
                obj.logger.error('PhysicalEnvironment setup failed unexpectedly: %s (%s)', ...
                    ME_phys.message, ME_phys.identifier);
                rethrow(ME_phys);
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

            % Phase 3 (audit §17.5 P3-5): pass through Global so
            % createEntity can size its Snapshot pre-allocation by the
            % real per-scenario frame count instead of the legacy 100.
            if isfield(obj.factoryConfig, 'Global')
                physicalEnvConfig.Global = obj.factoryConfig.Global;
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

    methods (Hidden)
        % Phase 2 internal API exposed for unit-test probes only.
        % Phase 3 may demote these to (Access = protected) once integration
        % tests cover the full stepImpl path end-to-end.
        function [maxResamples, validatorEnabled] = getValidatorConfig(obj)
            maxResamples     = 50;
            validatorEnabled = true;
            if isfield(obj.factoryConfig, 'Validator')
                v = obj.factoryConfig.Validator;
                if isfield(v, 'MaxResamples') && isnumeric(v.MaxResamples) && isscalar(v.MaxResamples)
                    maxResamples = v.MaxResamples;
                end
                if isfield(v, 'Enabled') && islogical(v.Enabled) && isscalar(v.Enabled)
                    validatorEnabled = v.Enabled;
                end
            end
        end

        function applyTestConfig(obj, configStruct)
            % Test-only setter that bypasses the matlab.System
            % once-locked-property restriction. Used by unit tests to
            % drive the resample loop without spinning up the full
            % simulator stack.
            obj.factoryConfig = configStruct;
        end

        function blueprint = assembleBlueprint(obj, frameId, txConfigs, rxConfigs, ...
                communicationLayout, environment)
            % assembleBlueprint - Phase 2 transitional schema (§3.4.3).
            %
            % The struct is intentionally minimal: every field is OPTIONAL
            % from the Validator's perspective, and missing fields cause
            % checks to soft-skip rather than reject. Phase 3 will tighten
            % this into a canonical ScenarioBlueprint v1.

            blueprint = struct();
            blueprint.FrameId  = frameId;
            blueprint.Emitters  = txConfigs;
            blueprint.Receivers = rxConfigs;
            blueprint.CommunicationLayout = communicationLayout;
            if isfield(obj.factoryConfig, 'Global')
                blueprint.Global = obj.factoryConfig.Global;
            end
            if isfield(obj.factoryConfig, 'Validator')
                blueprint.Validator = obj.factoryConfig.Validator;
            end
            if isfield(obj.factoryConfig, 'AnnotationPolicy')
                blueprint.AnnotationPolicy = obj.factoryConfig.AnnotationPolicy;
            end
            if isfield(obj.factoryConfig, 'OutputPolicy')
                blueprint.OutputPolicy = obj.factoryConfig.OutputPolicy;
            end
            if isfield(obj.factoryConfig, 'MeasurementPolicy')
                blueprint.MeasurementPolicy = obj.factoryConfig.MeasurementPolicy;
            end
            if isfield(obj.factoryConfig, 'ChannelPreference')
                blueprint.ChannelPreference = obj.factoryConfig.ChannelPreference;
            end
            if isfield(obj.factoryConfig, 'ChannelModelRegistry')
                blueprint.ChannelModelRegistry = obj.factoryConfig.ChannelModelRegistry;
            end
            mapType = '';
            if isstruct(environment) && isfield(environment, 'MapType')
                mapType = environment.MapType;
            end
            numEnts = 0;
            if isstruct(communicationLayout) && isfield(communicationLayout, 'Entities')
                numEnts = numel(communicationLayout.Entities);
            end
            blueprint.EnvironmentSummary = struct( ...
                'MapType', mapType, 'NumEntities', numEnts);
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
