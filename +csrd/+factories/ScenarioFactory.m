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

        % RuntimePlan: Canonical derived runtime facts for this run
        RuntimePlan struct
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
        selectedOSMSelectionPolicy char = ''
        selectedOSMFileSizeMB (1, 1) double = NaN
        selectedOSMOrdinal (1, 1) double = NaN
        selectedOSMCandidateCount (1, 1) double = NaN

        % Initialization flag
        isSimulatorsInitialized logical = false

        % Scenario construction plan. Built once before the first receiver
        % frame of each scenario, then treated as frozen.
        currentScenarioPlan struct = struct()
    end

    methods

        function obj = ScenarioFactory(varargin)
            % ScenarioFactory - Constructor for scenario factory
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
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
            % validateInputsImpl - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
        end

        function setupImpl(obj)
            % setupImpl - Initialize scenario factory components
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
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

            obj.logger = csrd.runtime.logger.GlobalLogManager.getLogger();
            obj.validateMapConfiguration();
            obj.logger.debug('ScenarioFactory initialized: %s v%s', ...
                obj.factoryConfig.Architecture, obj.factoryConfig.Version);
        end

        function [instantiatedTxs, instantiatedRxs, globalLayout] = stepImpl(obj, frameId)
            % stepImpl - Generate scenario for a frame
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
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

            obj.ensureScenarioPlanStarted();

            if ~obj.isSimulatorsInitialized
                obj.initializeSimulators();
                obj.isSimulatorsInitialized = true;
            end

            [entities, environment] = step(obj.physicalEnvironmentSimulator, frameId);

            [maxResamples, validatorEnabled] = obj.getValidatorConfig();

            attempt = 0;
            lastReport = struct('IsFeasible', true, 'BlueprintHash', '', ...
                'NumChecksRun', 0, 'NumChecksPassed', 0, 'NumChecksFailed', 0, ...
                'FailedChecks', csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailureArray(), ...
                'WarnChecks', csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailureArray(), ...
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
                lastReport = csrd.pipeline.blueprint.BlueprintFeasibilityValidator.validate(blueprint);

                if lastReport.IsFeasible
                    break;
                end

                if frameId ~= 1 || localScenarioPlanIsFrozen(obj.currentScenarioPlan)
                    rejectCode = '<unknown>';
                    if ~isempty(lastReport.FailedChecks)
                        rejectCode = lastReport.FailedChecks(1).Code;
                    end
                    error('CSRD:Blueprint:Unsamplable', ...
                        ['Frame %d failed feasibility check ''%s''. ', ...
                         'Frame execution cannot resample scenario-level ', ...
                         'facts because ScenarioPlan is already frozen.'], ...
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

            obj.enrichScenarioPlan(entities, environment, txConfigs, ...
                rxConfigs, globalLayout);
            globalLayout.ScenarioPlan = obj.currentScenarioPlan;

            obj.LastValidationReport   = lastReport;
            obj.LastBlueprintResamples = max(0, attempt - 1);
            obj.LastBlueprintHash      = lastReport.BlueprintHash;

            obj.storeFrameState(frameId, entities, environment, txConfigs, rxConfigs);
            obj.logger.debug('Frame %d: Generated %d Tx, %d Rx (attempts=%d)', ...
                frameId, length(txConfigs), length(rxConfigs), attempt);
        end

        function releaseImpl(obj)
            % releaseImpl - Release cached scenario planning blocks and simulators
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.

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
            obj.selectedOSMSelectionPolicy = '';
            obj.selectedOSMFileSizeMB = NaN;
            obj.selectedOSMOrdinal = NaN;
            obj.selectedOSMCandidateCount = NaN;
            obj.currentScenarioConfig = struct();
            obj.currentScenarioPlan = struct();

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
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.

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
            obj.selectedOSMSelectionPolicy = '';
            obj.selectedOSMFileSizeMB = NaN;
            obj.selectedOSMOrdinal = NaN;
            obj.selectedOSMCandidateCount = NaN;
            obj.currentScenarioConfig = struct();
            obj.currentScenarioPlan = struct();
        end

        function initializeSimulators(obj)
            % initializeSimulators - Initialize simulators once per scenario
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.

            obj.logger.debug('Initializing scenario simulators...');

            obj.ensureFactoryConfigReady();
            obj.ensureScenarioPlanStarted();

            % Select map type and OSM file (if applicable)
            obj.selectedMapType = obj.selectMapTypeByRatio();
            if strcmp(obj.selectedMapType, 'OSM')
                obj.selectedOSMFile = obj.selectBalancedOSMFile();
                if isempty(obj.selectedOSMFile)
                    error('CSRD:Scenario:MissingOSMFile', ...
                        ['Map type OSM was selected but no OSM file was found. ', ...
                         'Provide Map.OSM.SpecificFile/DataDirectory or remove OSM from Map.Types.']);
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
                % csrd.pipeline.scenario.isScenarioSkipException uniformly.
                if csrd.pipeline.scenario.isScenarioSkipException(ME_phys)
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
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            %
            % Two approaches:
            %   Statistical: Virtual scene + statistical channel models
            %   OSM: Real OpenStreetMap + ray tracing channel models

            obj.selectedOSMOrdinal = NaN;

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

            runtime = localGetScenarioRuntime(obj.factoryConfig);
            scenarioId = localRuntimePositiveInteger(runtime, 'ScenarioId', NaN);
            totalScenarios = localRuntimePositiveInteger(runtime, 'TotalScenarios', NaN);
            if isfinite(scenarioId) && isfinite(totalScenarios) && ...
                    totalScenarios >= 1
                seedValue = localRuntimeSeedValue(runtime);
                [idx, osmOrdinal] = localBalancedMapTypeIndex( ...
                    types, ratios, scenarioId, totalScenarios, seedValue);
                obj.selectedOSMOrdinal = osmOrdinal;
            else
                % Direct component tests may instantiate ScenarioFactory
                % without SimulationRunner runtime context. Preserve the
                % legacy stochastic behavior for those non-production calls.
                r = rand();
                cumRatios = cumsum(ratios);
                idx = find(r <= cumRatios, 1, 'first');
            end
            if isempty(idx)
                idx = 1;
            end
            
            mapType = types{idx};
        end

        function validateMapConfiguration(obj)
            % validateMapConfiguration - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            if ~isfield(obj.factoryConfig, 'PhysicalEnvironment') || ...
                    ~isfield(obj.factoryConfig.PhysicalEnvironment, 'Map')
                return;
            end

            mapConfig = obj.factoryConfig.PhysicalEnvironment.Map;
            if isfield(mapConfig, 'OSM') && isstruct(mapConfig.OSM) && ...
                    isfield(mapConfig.OSM, 'MaxFileSizeMB') && ...
                    ~isempty(mapConfig.OSM.MaxFileSizeMB)
                error('CSRD:Scenario:DeprecatedOsmSizeCap', ...
                    ['PhysicalEnvironment.Map.OSM.MaxFileSizeMB is deprecated. ', ...
                     'OSM file selection is now file-level balanced coverage; ', ...
                     'remove the size cap from the configuration.']);
            end

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
                if any(~isfinite(ratios)) || any(ratios < 0) || sum(ratios) <= 0
                    error('ScenarioFactory:ConfigError', ...
                        'PhysicalEnvironment.Map.Ratio must be non-negative and have positive sum.');
                end
            end
        end

        function osmFile = selectBalancedOSMFile(obj)
            % selectBalancedOSMFile - Select OSM file by deterministic coverage order.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            %
            % Uses Map.OSM configuration:
            %   Map.OSM.SpecificFile - If set, use this file directly
            %   Map.OSM.DataDirectory - Directory containing OSM files
            %   Map.OSM.FilePattern - Pattern for finding OSM files

            osmFile = '';
            obj.selectedOSMCandidateCount = NaN;
            
            % Get OSM config from Map.OSM
            osmConfig = struct();
            if isfield(obj.factoryConfig, 'PhysicalEnvironment') && ...
                    isfield(obj.factoryConfig.PhysicalEnvironment, 'Map') && ...
                    isfield(obj.factoryConfig.PhysicalEnvironment.Map, 'OSM')
                osmConfig = obj.factoryConfig.PhysicalEnvironment.Map.OSM;
            end

            % Check for specific OSM file override
            if isfield(osmConfig, 'SpecificFile') && ~isempty(osmConfig.SpecificFile)
                specificFile = obj.resolveOsmPath(osmConfig.SpecificFile);
                if isfile(specificFile)
                    osmFile = specificFile;
                    obj.selectedOSMOrdinal = 1;
                    obj.selectedOSMCandidateCount = 1;
                    obj.recordOsmSelection(osmFile, 'SpecificFile');
                    return;
                end
                error('CSRD:Scenario:MissingSpecificOsmFile', ...
                    'PhysicalEnvironment.Map.OSM.SpecificFile does not exist: %s', ...
                    specificFile);
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
                obj.selectedOSMCandidateCount = numel(allFiles);
                runtime = localGetScenarioRuntime(obj.factoryConfig);
                seedValue = localRuntimeSeedValue(runtime);
                relativeFiles = cellfun(@(p) localRelativePath(osmDataDir, p), ...
                    allFiles, 'UniformOutput', false);
                order = localDeterministicOrder(relativeFiles, seedValue, ...
                    'osm-file-coverage');
                ordinal = obj.selectedOSMOrdinal;
                if ~isfinite(ordinal) || ordinal < 1
                    scenarioId = localRuntimePositiveInteger(runtime, 'ScenarioId', 1);
                    ordinal = scenarioId;
                end
                selectedIndex = order(mod(round(ordinal) - 1, numel(allFiles)) + 1);
                osmFile = allFiles{selectedIndex};
                obj.recordOsmSelection(osmFile, 'BalancedUniformCoverage');
            end
        end

        function resolvedPath = resolveOsmPath(obj, pathText)
            %RESOLVEOSMPATH Resolve SpecificFile relative to project root.
            % Inputs: see function signature and validation.
            % Outputs: see return values and contract fields.
            resolvedPath = char(string(pathText));
            if obj.isAbsolutePath(resolvedPath)
                return;
            end
            currentFilePath = fileparts(mfilename('fullpath'));
            projectRoot = fileparts(fileparts(currentFilePath));
            projectPath = fullfile(projectRoot, resolvedPath);
            if isfile(projectPath)
                resolvedPath = projectPath;
            end
        end

        function recordOsmSelection(obj, osmFile, policy)
            %RECORDOSMSELECTION Persist OSM selection metadata for MapProfile.
            % Inputs: see function signature and validation.
            % Outputs: see return values and contract fields.
            obj.selectedOSMSelectionPolicy = char(string(policy));
            obj.selectedOSMFileSizeMB = localFileSizeMB(osmFile);
        end

        function osmFiles = findOSMFiles(obj, baseDir, pattern)
            % findOSMFiles - Recursively find OSM files in directory
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
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

            fileList = dir(fullfile(baseDir, '**', pattern));
            for j = 1:length(fileList)
                if fileList(j).isdir
                    continue;
                end
                osmFiles{end + 1} = fullfile(fileList(j).folder, fileList(j).name);
            end

            if ~isempty(osmFiles)
                relativePaths = cellfun(@(p) localRelativePath(baseDir, p), ...
                    osmFiles, 'UniformOutput', false);
                [~, order] = sort(string(relativePaths));
                osmFiles = osmFiles(order);
            end

            obj.logger.debug('OSM search found %d files under %s', ...
                numel(osmFiles), baseDir);

        end

        function physicalEnvConfig = getPhysicalEnvironmentConfig(obj)
            % getPhysicalEnvironmentConfig - Extract physical environment configuration
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
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
                    physicalEnvConfig.Map.OSM.SelectionPolicy = ...
                        obj.selectedOSMSelectionPolicy;
                    physicalEnvConfig.Map.OSM.SelectedFileSizeMB = ...
                        obj.selectedOSMFileSizeMB;
                    physicalEnvConfig.Map.OSM.CoverageOrdinal = ...
                        obj.selectedOSMOrdinal;
                    physicalEnvConfig.Map.OSM.CandidateFileCount = ...
                        obj.selectedOSMCandidateCount;
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

            % Phase 3 (audit §17.5 P3-5): pass through Global so
            % createEntity can size its Snapshot pre-allocation by the
            % real per-scenario frame count instead of the legacy 100.
            physicalEnvConfig.Global = localBlueprintGlobal( ...
                obj.factoryConfig, obj.currentScenarioPlan);

            % Physical state evolves once per receiver frame. ScenarioPlan
            % is the only source for the resolved per-scenario frame duration.
            framePlan = obj.requireScenarioFramePlan();
            physicalEnvConfig.TimeResolution = framePlan.FrameDurationSec;
        end

        function commBehaviorConfig = getCommunicationBehaviorConfig(obj)
            % getCommunicationBehaviorConfig - Extract communication behavior configuration
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.

            % Use configured CommunicationBehavior directly
            commBehaviorConfig = obj.factoryConfig.CommunicationBehavior;

            commBehaviorConfig.RuntimePlan = obj.RuntimePlan;
            commBehaviorConfig.ScenarioPlan = obj.currentScenarioPlan;

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

            commBehaviorConfig.Runtime = obj.resolveCommunicationRuntimeCapabilities( ...
                commBehaviorConfig);

            if ~isfield(commBehaviorConfig, 'PowerControl')
                commBehaviorConfig.PowerControl = struct();
            end
            if ~isfield(commBehaviorConfig.PowerControl, 'MaxPower')
                commBehaviorConfig.PowerControl.MaxPower = 30;
            end
        end

        function runtime = resolveCommunicationRuntimeCapabilities(obj, commBehaviorConfig)
            % resolveCommunicationRuntimeCapabilities - Publish map/channel limits to planning.
            % Inputs: selected map type and communication config.
            % Outputs: runtime capability struct for CommunicationBehavior.
            runtime = struct();
            runtime.ChannelModel = '';
            runtime.RequiredCarrierFrequencyRangeHz = [];

            mapConfig = struct();
            if isfield(obj.factoryConfig, 'PhysicalEnvironment') && ...
                    isfield(obj.factoryConfig.PhysicalEnvironment, 'Map')
                mapConfig = obj.factoryConfig.PhysicalEnvironment.Map;
            end

            if strcmp(obj.selectedMapType, 'OSM')
                runtime.ChannelModel = localMapChannelModel(mapConfig, ...
                    'OSM', 'RayTracing');
            else
                runtime.ChannelModel = localMapChannelModel(mapConfig, ...
                    'Statistical', 'Statistical');
            end

            if strcmpi(runtime.ChannelModel, 'RayTracing')
                runtime.RequiredCarrierFrequencyRangeHz = [100e6, 100e9];
            end

            if isfield(commBehaviorConfig, 'Runtime') && ...
                    isstruct(commBehaviorConfig.Runtime)
                runtime = obj.mergeConfigs(runtime, commBehaviorConfig.Runtime);
            end
        end

        function ensureScenarioPlanStarted(obj, scenarioId)
            % ensureScenarioPlanStarted - CSRD MATLAB declaration.
            % Inputs: see function signature and validation.
            % Outputs: see return values and contract fields.
            obj.ensureFactoryConfigReady();
            if nargin < 2 || isempty(scenarioId)
                runtime = localGetScenarioRuntime(obj.factoryConfig);
                scenarioId = localRuntimePositiveInteger(runtime, 'ScenarioId', 1);
            else
                runtime = localGetScenarioRuntime(obj.factoryConfig);
                runtime.ScenarioId = double(scenarioId);
            end
            if ~isempty(obj.currentScenarioPlan) && ...
                    isstruct(obj.currentScenarioPlan) && ...
                    isfield(obj.currentScenarioPlan, 'ScenarioId')
                return;
            end
            obj.currentScenarioPlan = csrd.pipeline.runtime.buildScenarioPlan( ...
                obj.RuntimePlan, obj.factoryConfig, runtime);
        end

        function ensureFactoryConfigReady(obj)
            % ensureFactoryConfigReady - CSRD MATLAB declaration.
            % Inputs: see function signature and validation.
            % Outputs: see return values and contract fields.
            if ~isempty(obj.factoryConfig) && isstruct(obj.factoryConfig)
                return;
            end
            if isempty(obj.Config) || ~isstruct(obj.Config)
                error('ScenarioFactory:ConfigError', ...
                    'Config must be a valid struct before scenario planning.');
            end
            obj.factoryConfig = obj.Config;
            if ~isfield(obj.factoryConfig, 'PhysicalEnvironment')
                error('ScenarioFactory:ConfigError', ...
                    'PhysicalEnvironment configuration required.');
            end
            if ~isfield(obj.factoryConfig, 'CommunicationBehavior')
                error('ScenarioFactory:ConfigError', ...
                    'CommunicationBehavior configuration required.');
            end
            obj.logger = csrd.runtime.logger.GlobalLogManager.getLogger();
            obj.validateMapConfiguration();
        end

        function enrichScenarioPlan(obj, entities, environment, txConfigs, ...
                rxConfigs, globalLayout)
                    % enrichScenarioPlan - CSRD MATLAB declaration.
                    % Inputs: see function signature and validation.
                    % Outputs: see return values and contract fields.
            if isempty(obj.currentScenarioPlan) || ~isstruct(obj.currentScenarioPlan)
                obj.ensureScenarioPlanStarted();
            end
            plan = obj.currentScenarioPlan;
            plan.Map = localScenarioPlanMap(environment, ...
                obj.selectedOSMSelectionPolicy, obj.selectedOSMFileSizeMB);
            plan.GeometryPolicy = struct( ...
                'Evaluation', 'SegmentMidpoint', ...
                'Source', 'ScenarioPlan');
            % Entities.Initial must capture the scenario's first-frame (t=0)
            % state ONCE and then stay fixed. enrichScenarioPlan runs every
            % frame on the mobility-advanced `entities` (stepImpl advances them
            % via step(physicalEnvironmentSimulator, frameId) before this call),
            % so rebuilding Initial each frame stamps a later frame's advanced
            % positions with CreationTime=0 / Snapshots{1}.FrameId=1 -- a false
            % "initial" snapshot. The live geometry path reads the frozen
            % obj.ScenarioPlan (assigned once per scenario in @ChangShuo), not
            % this currentScenarioPlan, so this is a latent inconsistency today;
            % guarding it keeps the recorded Initial honest if a future consumer
            % ever reads it. Carry the first-captured value forward.
            if ~(isfield(plan, 'Entities') && isstruct(plan.Entities) && ...
                    isfield(plan.Entities, 'Initial') && ~isempty(plan.Entities.Initial))
                plan.Entities = struct( ...
                    'Initial', localNormalizeInitialEntitiesAtZero(entities));
            end
            plan.Receivers = rxConfigs;
            plan.Transmitters = txConfigs;
            plan.Communication = localScenarioPlanCommunication( ...
                txConfigs, globalLayout);
            numRx = numel(rxConfigs);
            plan.DatasetAccounting = struct( ...
                'NumReceivers', numRx, ...
                'NumFramesPerScenario', plan.Frame.NumFramesPerScenario, ...
                'NumReceiverFrames', plan.Frame.NumFramesPerScenario * numRx);
            obj.currentScenarioPlan = plan;
        end

        function framePlan = requireScenarioFramePlan(obj)
            % requireScenarioFramePlan - CSRD MATLAB declaration.
            % Inputs: see function signature and validation.
            % Outputs: see return values and contract fields.
            if isempty(obj.currentScenarioPlan) || ...
                    ~isstruct(obj.currentScenarioPlan) || ...
                    ~isfield(obj.currentScenarioPlan, 'Frame') || ...
                    ~isstruct(obj.currentScenarioPlan.Frame)
                error('CSRD:ScenarioPlan:MissingFrameContract', ...
                    'ScenarioFactory current ScenarioPlan.Frame is required.');
            end
            framePlan = obj.currentScenarioPlan.Frame;
        end

        function storeFrameState(obj, frameId, entities, environment, txConfigs, rxConfigs)
            % storeFrameState - Store current frame state for next frame continuity
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.

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
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
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
        function scenarioPlan = planScenario(obj, scenarioId)
            %PLANSCENARIO Build and freeze a scenario construction plan.
            obj.ensureFactoryConfigReady();
            if nargin < 2 || isempty(scenarioId)
                runtime = localGetScenarioRuntime(obj.factoryConfig);
                scenarioId = localRuntimePositiveInteger(runtime, 'ScenarioId', 1);
            end
            obj.ensureScenarioPlanStarted(scenarioId);

            if ~obj.isSimulatorsInitialized
                obj.initializeSimulators();
                obj.isSimulatorsInitialized = true;
            end

            [entities, environment] = obj.physicalEnvironmentSimulator.planInitialState();
            [maxResamples, validatorEnabled] = obj.getValidatorConfig();

            attempt = 0;
            lastReport = localDisabledValidationReport();
            while true
                attempt = attempt + 1;
                [txConfigs, rxConfigs, layout, entities] = ...
                    obj.communicationBehaviorSimulator.planScenario(entities);
                layout.FrameId = 1;
                layout.Environment = environment;
                layout.Entities = entities;

                if validatorEnabled
                    blueprint = obj.assembleBlueprint(1, txConfigs, ...
                        rxConfigs, layout, environment);
                    lastReport = csrd.pipeline.blueprint ...
                        .BlueprintFeasibilityValidator.validate(blueprint);
                end

                if ~validatorEnabled || lastReport.IsFeasible
                    break;
                end

                if attempt >= maxResamples
                    rejectCode = localFirstFailedCheckCode(lastReport);
                    error('CSRD:Blueprint:Unsamplable', ...
                        ['Scenario plan: %d communication resample attempts ', ...
                         'exhausted. Last failed check: ''%s''.'], ...
                        attempt, rejectCode);
                end

                rejectCode = localFirstFailedCheckCode(lastReport);
                obj.logger.debug(['Scenario plan attempt %d rejected by ', ...
                    '''%s''; resampling communication plan.'], ...
                    attempt, rejectCode);
                release(obj.communicationBehaviorSimulator);
                setup(obj.communicationBehaviorSimulator);
            end

            layout.BlueprintHash = lastReport.BlueprintHash;
            layout.ValidationReport = lastReport;
            layout.NumBlueprintAttempts = attempt;
            obj.enrichScenarioPlan(entities, environment, txConfigs, ...
                rxConfigs, layout);
            obj.currentScenarioPlan.ValidationReport = lastReport;
            obj.currentScenarioPlan.NumBlueprintAttempts = attempt;

            obj.LastValidationReport = lastReport;
            obj.LastBlueprintResamples = max(0, attempt - 1);
            obj.LastBlueprintHash = lastReport.BlueprintHash;
            scenarioPlan = obj.currentScenarioPlan;
        end

        function [maxResamples, validatorEnabled] = getValidatorConfig(obj)
            % getValidatorConfig - Production declaration in CSRD.
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
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
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            % once-locked-property restriction. Used by unit tests to
            % drive the resample loop without spinning up the full
            % simulator stack.
            obj.factoryConfig = configStruct;
        end

        function blueprint = assembleBlueprint(obj, frameId, txConfigs, rxConfigs, ...
                communicationLayout, environment)
            % assembleBlueprint - Phase 2 transitional schema (§3.4.3).
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
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
            blueprintGlobal = localBlueprintGlobal(obj.factoryConfig, obj.currentScenarioPlan);
            if ~isempty(fieldnames(blueprintGlobal))
                blueprint.Global = blueprintGlobal;
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
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
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


function model = localMapChannelModel(mapConfig, mapType, defaultModel)
%LOCALMAPCHANNELMODEL Resolve explicit map-specific channel model.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
model = char(string(defaultModel));
if ~isstruct(mapConfig) || ~isfield(mapConfig, mapType)
    return;
end

typedConfig = mapConfig.(mapType);
if isstruct(typedConfig) && isfield(typedConfig, 'ChannelModel') && ...
        ~isempty(typedConfig.ChannelModel)
    model = char(string(typedConfig.ChannelModel));
end
end

function report = localDisabledValidationReport()
%LOCALDISABLEDVALIDATIONREPORT Blueprint validator report for disabled mode.
report = struct('IsFeasible', true, 'BlueprintHash', '', ...
    'NumChecksRun', 0, 'NumChecksPassed', 0, 'NumChecksFailed', 0, ...
    'FailedChecks', csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailureArray(), ...
    'WarnChecks', csrd.pipeline.blueprint.BlueprintFeasibilityValidator.emptyFailureArray(), ...
    'Provenance', struct('ValidatorVersion', 'disabled', 'Timestamp', ''));
end

function code = localFirstFailedCheckCode(report)
%LOCALFIRSTFAILEDCHECKCODE Return a readable validator failure code.
code = '<unknown>';
if isstruct(report) && isfield(report, 'FailedChecks') && ...
        ~isempty(report.FailedChecks) && ...
        isfield(report.FailedChecks(1), 'Code') && ...
        ~isempty(report.FailedChecks(1).Code)
    code = char(string(report.FailedChecks(1).Code));
end
end

function tf = localScenarioPlanIsFrozen(plan)
%LOCALSCENARIOPLANISFROZEN True after scenario-level facts are sealed.
tf = isstruct(plan) && isfield(plan, 'DatasetAccounting') && ...
    isfield(plan, 'Communication') && isfield(plan, 'Entities');
end

function globalConfig = localBlueprintGlobal(factoryConfig, scenarioPlan)
%LOCALBLUEPRINTGLOBAL Build blueprint global facts from ScenarioPlan.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
globalConfig = struct();
if isstruct(factoryConfig) && isfield(factoryConfig, 'Global') && ...
        isstruct(factoryConfig.Global)
    globalConfig = factoryConfig.Global;
end
if ~isstruct(scenarioPlan) || ~isfield(scenarioPlan, 'Frame') || ...
        ~isstruct(scenarioPlan.Frame)
    return;
end

framePlan = scenarioPlan.Frame;
if isfield(framePlan, 'FrameNumSamples')
    globalConfig.FrameNumSamples = framePlan.FrameNumSamples;
end
if isfield(framePlan, 'NumFramesPerScenario')
    globalConfig.NumFramesPerScenario = framePlan.NumFramesPerScenario;
    globalConfig.NumFrames = framePlan.NumFramesPerScenario;
end
if isfield(framePlan, 'FrameDurationSec')
    globalConfig.FrameDurationSec = framePlan.FrameDurationSec;
    globalConfig.FrameDuration = framePlan.FrameDurationSec;
end
if isfield(framePlan, 'ObservationDurationSec')
    globalConfig.ObservationDurationSec = framePlan.ObservationDurationSec;
end
end

function mapPlan = localScenarioPlanMap(environment, selectionPolicy, osmFileSizeMB)
    % localScenarioPlanMap - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
mapPlan = struct( ...
    'SelectedType', '', ...
    'OSMFile', '', ...
    'ChannelModel', '', ...
    'SelectionPolicy', '', ...
    'OSMFileSizeMB', NaN, ...
    'MapProfile', struct(), ...
    'Boundaries', []);
if isstruct(environment)
    if isfield(environment, 'MapType')
        mapPlan.SelectedType = environment.MapType;
    end
    if isfield(environment, 'OSMMapFile')
        mapPlan.OSMFile = environment.OSMMapFile;
    end
    if isfield(environment, 'ChannelModel')
        mapPlan.ChannelModel = environment.ChannelModel;
    end
    if isfield(environment, 'MapProfile') && isstruct(environment.MapProfile)
        mapPlan.MapProfile = environment.MapProfile;
        if isfield(environment.MapProfile, 'Boundaries')
            mapPlan.Boundaries = environment.MapProfile.Boundaries;
        end
    end
    if isempty(mapPlan.Boundaries) && isfield(environment, 'Map') && ...
            isstruct(environment.Map) && ...
            isfield(environment.Map, 'MapProfile') && ...
            isstruct(environment.Map.MapProfile)
        mapPlan.MapProfile = environment.Map.MapProfile;
        if isfield(environment.Map.MapProfile, 'Boundaries')
            mapPlan.Boundaries = environment.Map.MapProfile.Boundaries;
        end
    end
    if isempty(mapPlan.Boundaries) && isfield(environment, 'MapBoundaries')
        mapPlan.Boundaries = environment.MapBoundaries;
    end
end
mapPlan.SelectionPolicy = selectionPolicy;
mapPlan.OSMFileSizeMB = osmFileSizeMB;
end

function entities = localNormalizeInitialEntitiesAtZero(entities)
%LOCALNORMALIZEINITIALENTITIESATZERO Stamp ScenarioPlan entity base time.
for idx = 1:numel(entities)
    entities(idx).CreationTime = 0;
    entities(idx).LastUpdateTime = 0;
    if isfield(entities(idx), 'StateHistory')
        entities(idx).StateHistory = [];
    end
    if isfield(entities(idx), 'Snapshots') && iscell(entities(idx).Snapshots) && ...
            ~isempty(entities(idx).Snapshots)
        if isempty(entities(idx).Snapshots{1})
            continue;
        end
        entities(idx).Snapshots{1}.Timestamp = 0;
        entities(idx).Snapshots{1}.FrameId = 1;
    end
end
end

function commPlan = localScenarioPlanCommunication(txConfigs, globalLayout)
    % localScenarioPlanCommunication - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
commPlan = struct();
commPlan.TransmissionSchedule = localTransmissionSchedule(txConfigs);
if isstruct(globalLayout)
    if isfield(globalLayout, 'FrequencyAllocation')
        commPlan.FrequencyAllocation = globalLayout.FrequencyAllocation;
    end
    if isfield(globalLayout, 'RegulatoryPlan')
        commPlan.RegulatoryPlan = globalLayout.RegulatoryPlan;
    end
end
end

function schedule = localTransmissionSchedule(txConfigs)
    % localTransmissionSchedule - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
schedule = repmat(struct('TxID', '', 'Temporal', struct()), 0, 1);
for k = 1:numel(txConfigs)
    if iscell(txConfigs)
        tx = txConfigs{k};
    else
        tx = txConfigs(k);
    end
    entry = struct('TxID', sprintf('Tx%d', k), 'Temporal', struct());
    if isstruct(tx)
        if isfield(tx, 'ID') && ~isempty(tx.ID)
            entry.TxID = char(string(tx.ID));
        elseif isfield(tx, 'EntityID') && ~isempty(tx.EntityID)
            entry.TxID = char(string(tx.EntityID));
        end
        if isfield(tx, 'Temporal') && isstruct(tx.Temporal)
            entry.Temporal = tx.Temporal;
        end
    end
    schedule(end + 1) = entry; %#ok<AGROW>
end
end

function sizeMB = localFileSizeMB(pathText)
%LOCALFILESIZEMB Return file size in MB without touching file contents.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
sizeMB = NaN;
if isempty(pathText)
    return;
end
info = dir(char(string(pathText)));
if ~isempty(info)
    sizeMB = double(info.bytes) / 1024 / 1024;
end
end

function runtime = localGetScenarioRuntime(factoryConfig)
%LOCALGETSCENARIORUNTIME Return SimulationRunner-injected planning context.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
runtime = struct();
if isstruct(factoryConfig) && isfield(factoryConfig, 'Runtime') && ...
        isstruct(factoryConfig.Runtime)
    runtime = factoryConfig.Runtime;
end
end

function value = localRuntimePositiveInteger(runtime, fieldName, defaultValue)
%LOCALRUNTIMEPOSITIVEINTEGER Read a positive integer runtime field.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
value = defaultValue;
if ~isstruct(runtime) || ~isfield(runtime, fieldName) || ...
        isempty(runtime.(fieldName))
    return;
end
candidate = runtime.(fieldName);
if isnumeric(candidate) && isscalar(candidate) && isfinite(candidate) && ...
        candidate >= 1
    value = floor(double(candidate));
end
end

function seedValue = localRuntimeSeedValue(runtime)
%LOCALRUNTIMESEEDVALUE Stable numeric seed for balanced schedules.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
seedValue = 0;
if ~isstruct(runtime) || ~isfield(runtime, 'RandomSeed') || ...
        isempty(runtime.RandomSeed)
    return;
end
seed = runtime.RandomSeed;
if isnumeric(seed) && isscalar(seed) && isfinite(seed)
    seedValue = double(seed);
elseif ischar(seed) || isstring(seed)
    seedValue = localStableHash(char(string(seed)));
end
seedValue = mod(abs(floor(seedValue)), 2^31 - 1);
end

function [idx, osmOrdinal] = localBalancedMapTypeIndex(types, ratios, ...
        scenarioId, totalScenarios, seedValue)
%LOCALBALANCEDMAPTYPEINDEX Deterministic map schedule preserving ratios.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
types = cellstr(string(types));
ratios = double(ratios(:));
ratios = ratios ./ sum(ratios);
totalScenarios = max(1, floor(double(totalScenarios)));
scenarioId = max(1, floor(double(scenarioId)));

positive = ratios > 0;
desired = ratios .* totalScenarios;
if totalScenarios >= sum(positive)
    % Do not starve any explicitly configured positive-ratio map type in
    % small default runs. The remaining slots still follow the requested
    % ratio as closely as the integer scenario count allows.
    counts = zeros(size(ratios));
    counts(positive) = 1;
    remaining = totalScenarios - sum(counts);
    residual = max(desired - counts, 0);
    if sum(residual) <= 0
        residual = ratios;
    end
    residual = residual ./ sum(residual);
    extraDesired = residual .* remaining;
    extra = floor(extraDesired);
    counts = counts + extra;
    remaining = totalScenarios - sum(counts);
    remainders = extraDesired - extra;
else
    counts = floor(desired);
    remaining = totalScenarios - sum(counts);
    remainders = desired - counts;
end
if remaining > 0
    [~, addOrder] = sortrows([-remainders(:), (1:numel(ratios))']);
    for n = 1:remaining
        counts(addOrder(n)) = counts(addOrder(n)) + 1;
    end
end

schedule = zeros(1, totalScenarios);
cursor = 1;
for typeIdx = 1:numel(types)
    n = counts(typeIdx);
    if n <= 0
        continue;
    end
    schedule(cursor:(cursor + n - 1)) = typeIdx;
    cursor = cursor + n;
end
if cursor <= totalScenarios
    schedule(cursor:end) = 1;
end

scheduleOrder = localDeterministicOrder(num2cell(schedule), seedValue, ...
    'map-type-coverage');
schedule = schedule(scheduleOrder);
positionInCycle = mod(scenarioId - 1, totalScenarios) + 1;
cycleIndex = floor((scenarioId - 1) / totalScenarios);
idx = schedule(positionInCycle);

isOsm = strcmpi(types(schedule), 'OSM');
osmPerCycle = sum(isOsm);
if strcmpi(types{idx}, 'OSM')
    osmOrdinal = cycleIndex * osmPerCycle + sum(isOsm(1:positionInCycle));
else
    osmOrdinal = NaN;
end
end

function order = localDeterministicOrder(items, seedValue, label)
%LOCALDETERMINISTICORDER Stable pseudo-random order without touching global RNG.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
n = numel(items);
keys = zeros(n, 1);
for idx = 1:n
    keys(idx) = localStableHash(sprintf('%s|%.0f|%d|%s', ...
        label, seedValue, idx, char(string(items{idx}))));
end
[~, order] = sortrows([keys, (1:n)']);
order = order(:)';
end

function value = localStableHash(text)
%LOCALSTABLEHASH Java-free deterministic 31-bit djb2-style hash.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
bytes = uint8(unicode2native(char(string(text)), 'UTF-8'));
hash = 5381;
modulus = 2^31 - 1;
for idx = 1:numel(bytes)
    hash = mod(hash * 33 + double(bytes(idx)), modulus);
end
value = double(hash);
end

function relPath = localRelativePath(baseDir, fullPath)
%LOCALRELATIVEPATH Return a normalized path relative to baseDir when possible.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
baseDir = localNormalizePath(baseDir);
fullPath = localNormalizePath(fullPath);
baseForMatch = baseDir;
if ~endsWith(baseForMatch, '/')
    baseForMatch = [baseForMatch '/'];
end
if startsWith(lower(fullPath), lower(baseForMatch))
    relPath = extractAfter(fullPath, strlength(baseForMatch));
    relPath = char(relPath);
else
    relPath = fullPath;
end
end

function pathText = localNormalizePath(pathText)
    % localNormalizePath - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
pathText = strrep(char(string(pathText)), '\', '/');
pathText = regexprep(pathText, '/+', '/');
if strlength(pathText) > 1
    pathText = regexprep(pathText, '/$', '');
end
end
