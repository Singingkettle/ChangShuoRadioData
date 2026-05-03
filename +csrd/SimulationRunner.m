classdef SimulationRunner < matlab.System
    % SimulationRunner - Scenario-driven radio data collection simulation manager
    % 中文说明：提供 CSRD 生产链路中的 SimulationRunner 实现。
    %
    % This class manages multiple communication scenarios in a radio data collection
    % simulation. For each scenario, it instantiates a ChangShuo engine that generates
    % the specified number of frames for that scenario. The runner handles scenario
    % distribution across workers, data storage, and comprehensive logging.
    %
    % Architecture Flow:
    %   SimulationRunner (scenario manager) -> ChangShuo instances (scenario processors)
    %   - Get total scenario count directly from NumScenarios configuration
    %   - Frame generation is delegated to ChangShuo per scenario
    %   - Distribute scenarios across workers
    %   - For each scenario: instantiate ChangShuo -> generate all frames in scenario -> save data
    %   - ChangShuo handles frame-level loops internally for each scenario
    %
    % Key Features:
    %   - Scenario-based simulation execution with configurable frame counts per scenario
    %   - Support for parallel processing across multiple workers (scenario distribution)
    %   - Integrated logging system with configurable levels and outputs
    %   - Automatic directory structure creation for organized data storage
    %   - Comprehensive error handling and progress tracking
    %   - ChangShuo engine lifecycle management per scenario
    %
    % Properties:
    %   RunnerConfig (struct): Complete simulation execution configuration
    %   FactoryConfigs (struct): Factory configurations for ChangShuo engines
    %
    % Methods:
    %   SimulationRunner(varargin): Constructor with name-value pair configuration
    %   setupImpl(obj): Initialize simulation environment and load configurations
    %   stepImpl(obj, workerId, numWorkers): Execute scenarios for a specific worker
    %
    % Example Usage:
    %   % Load unified configuration
    %   masterConfig = initialize_csrd_configuration();
    %
    %   % Create simulation runner
    %   runner = csrd.SimulationRunner('RunnerConfig', masterConfig.Runner);
    %   runner.FactoryConfigs = masterConfig.Factories;
    %
    %   % Execute simulation (single worker)
    %   runner(1, 1);
    %
    %   % Execute with multiple workers
    %   for workerId = 1:4
    %       runner(workerId, 4);  % Worker workerId processes subset of scenarios
    %   end
    %
    % See also: initialize_csrd_configuration, csrd.core.ChangShuo

    properties
        % RunnerConfig: Complete runner configuration structure
        % Contains execution parameters, data storage settings, logging configuration,
        % and parallel processing parameters. Structure includes:
        %   .NumScenarios (integer): Number of scenarios to execute
        %   .NumFrames (integer): Total frames (calculated by summing all scenario frame counts)
        %   .FixedFrameLength: removed; use
        %     Factories.Scenario.Global.FrameNumSamples instead
        %   .RandomSeed (integer|'shuffle'): Random seed for reproducibility
        %   .Data (struct): Data storage configuration with output directories
        %   .Log (struct): Logging configuration with levels and output options
        %   .Engine (struct): ChangShuo engine configuration
        RunnerConfig struct

        % FactoryConfigs: Factory configurations for ChangShuo engines
        % Contains configuration structs for all simulation component factories
        % that will be used by each ChangShuo engine instance
        % Scenario configuration is accessed via FactoryConfigs.Scenario
        FactoryConfigs struct
    end

    properties (Access = private)
        % logger: Logger instance for tracking simulation progress and debugging
        logger

        % totalScenarios: Total number of scenarios to process
        totalScenarios

        % actualOutputDirectory: Created output directory with timestamp
        actualOutputDirectory

        % Time tracking properties for progress monitoring
        workerStartTimes % Map to store start time for each worker
        workerScenarioCounts % Map to store total scenario count for each worker

        % --- Phase 0 (audit §17.2 / phase-0-baseline.md §6) ---
        % toolboxLevel: which toolbox tier was validated at startup
        % ('minimal'|'standard'|'full'); defaults to 'standard' when
        % RunnerConfig.Toolbox.Level is absent.
        toolboxLevel

        % logPolicyDescription: cached struct returned by
        % csrd.runtime.logger.policy.LogPolicy.describe(); appended to every
        % annotation under Header.Runtime.LogPolicy so post-hoc analyses
        % can tell which logging tier produced a given annotation file.
        logPolicyDescription
    end

    methods

        function obj = SimulationRunner(varargin)
            % SimulationRunner - Constructor for scenario-driven simulation runner
            % 中文说明：SimulationRunner 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            % Creates a new SimulationRunner instance with specified configuration.
            % The constructor accepts name-value pairs for setting object properties.
            %
            % Syntax:
            %   obj = SimulationRunner()
            %   obj = SimulationRunner('RunnerConfig', runnerConfig)
            %   obj = SimulationRunner('PropertyName', PropertyValue, ...)
            %
            % Input Arguments:
            %   varargin - Name-value pairs for setting object properties
            %     'RunnerConfig' - Complete runner configuration structure (required)
            %     'FactoryConfigs' - Factory configurations structure (optional)
            %
            % Output Arguments:
            %   obj - SimulationRunner instance ready for execution

            setProperties(obj, nargin, varargin{:});
        end

    end

    methods (Access = protected)

        function setupImpl(obj)
            % setupImpl - Initialize simulation environment for scenario-driven execution
            % 中文说明：setupImpl 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            % This method performs complete simulation environment initialization including:
            % - Configuration validation and scenario count retrieval from NumScenarios
            % - Scenario-level management (frame generation delegated to ChangShuo)
            % - Global logging system access
            % - Directory structure creation for organized data storage
            % - Random seed configuration for reproducibility
            %
            % The method retrieves the configured number of scenarios from NumScenarios,
            % calculates total frames automatically, accesses the global logging system,
            % creates necessary directories, and prepares for scenario-based execution.

            % Initialize logger from GlobalLogManager
            obj.logger = csrd.runtime.logger.GlobalLogManager.getLogger();

            % --- Phase 0 change #2: apply LogPolicy ---
            % Order matters: apply BEFORE the first debug() so the very
            % next line is already filtered correctly when running under
            % LargeMC. See phase-0-baseline.md §6.2.
            obj.applyLogPolicyFromConfig();

            obj.logger.debug('SimulationRunner setupImpl started. Initializing scenario-driven execution...');

            obj.validateConfiguration();
            obj.normalizeAndValidateFactoryRuntimeContracts();

            % --- Phase 0 change #1: validate required toolboxes ---
            % Fail-fast on missing toolboxes so a long sweep does not
            % crash 4 hours in with a cryptic factory error. See
            % phase-0-baseline.md §6.1.
            obj.validateToolboxesFromConfig();

            % Get total number of scenarios from RunnerConfig
            if isfield(obj.RunnerConfig, 'NumScenarios') && isnumeric(obj.RunnerConfig.NumScenarios) && obj.RunnerConfig.NumScenarios > 0
                obj.totalScenarios = obj.RunnerConfig.NumScenarios;
            else
                error('SimulationRunner:InvalidConfig', 'RunnerConfig.NumScenarios must be a positive integer.');
            end

            obj.logger.info('Configured %d scenarios for execution', obj.totalScenarios);
            obj.logger.info('Frame generation will be handled by ChangShuo per scenario');

            % Handle random seed configuration
            if isfield(obj.RunnerConfig, 'RandomSeed')

                if strcmpi(obj.RunnerConfig.RandomSeed, 'shuffle')
                    rng('shuffle');
                    obj.logger.debug('Random seed set to shuffle mode.');
                else
                    rng(obj.RunnerConfig.RandomSeed);
                    obj.logger.debug('Random seed set to %d.', obj.RunnerConfig.RandomSeed);
                end

            end

            obj.setupDirectories();

            obj.logger.info('SimulationRunner setup completed successfully.');
            obj.logger.debug('Ready for scenario-based execution: %d total scenarios', obj.totalScenarios);
        end

        function stepImpl(obj, workerId, numWorkers)
            % stepImpl - Execute scenarios with distributed worker processing
            % 中文说明：stepImpl 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            % Executes scenario-based simulation for a specific worker. Each worker
            % processes a subset of scenarios based on worker ID and total number
            % of workers. For each assigned scenario, the method:
            % 1. Instantiates a new ChangShuo engine
            % 2. Configures the engine with factory configurations
            % 3. Delegates frame generation to ChangShuo (which handles frame loops internally)
            % 4. Saves the scenario data
            % 5. Cleans up and moves to next scenario
            %
            % Syntax:
            %   stepImpl(obj, workerId, numWorkers)
            %
            % Input Arguments:
            %   workerId (integer) - ID of current worker (1 to numWorkers)
            %   numWorkers (integer) - Total number of workers for distributed processing
            %
            % Scenario Distribution:
            %   Scenarios are distributed evenly across workers with remainder scenarios
            %   assigned to the first workers. Each worker processes its assigned
            %   range of scenario IDs.

            % Validate worker configuration parameters
            if nargin < 2, workerId = 1; end
            if nargin < 3, numWorkers = 1; end

            if workerId > numWorkers
                error('SimulationRunner:WorkerConfigError', ...
                    'Worker ID (%d) cannot be greater than total workers (%d)', workerId, numWorkers);
            end

            % Calculate scenario distribution for this specific worker
            [startScenario, endScenario, workerScenarioCount] = obj.calculateScenarioDistribution(workerId, numWorkers);

            if workerScenarioCount == 0
                obj.logger.info('Worker %d: No scenarios assigned to process.', workerId);
                return;
            end

            obj.logger.info('Worker %d: Processing scenarios %d to %d (%d scenarios total)', ...
                workerId, startScenario, endScenario, workerScenarioCount);

            % Initialize timing and progress tracking
            simulationStartTime = tic;
            successfulScenarios = 0;
            failedScenarios = 0;

            % Initialize time tracking for this worker
            if isempty(obj.workerStartTimes)
                obj.workerStartTimes = containers.Map('KeyType', 'int32', 'ValueType', 'any');
                obj.workerScenarioCounts = containers.Map('KeyType', 'int32', 'ValueType', 'int32');
            end

            obj.workerStartTimes(workerId) = simulationStartTime;
            obj.workerScenarioCounts(workerId) = workerScenarioCount;

            % Process scenarios sequentially for this worker
            for scenarioId = startScenario:endScenario
                scenarioStartTime = tic;
                currentScenarioIndex = scenarioId - startScenario + 1;

                try
                    % Execute single scenario with ChangShuo engine
                    obj.executeScenario(scenarioId, workerId);

                    successfulScenarios = successfulScenarios + 1;
                    scenarioTime = toc(scenarioStartTime);

                    % Display detailed progress with time information
                    obj.displayProgress(workerId, currentScenarioIndex, workerScenarioCount, scenarioId, scenarioTime, false);

                    obj.logger.debug('Worker %d, Scenario %d: Completed successfully in %.2f seconds', ...
                        workerId, scenarioId, scenarioTime);

                catch scenarioError
                    failedScenarios = failedScenarios + 1;
                    scenarioTime = toc(scenarioStartTime);

                    % Display progress even for failed scenarios
                    obj.displayProgress(workerId, currentScenarioIndex, workerScenarioCount, scenarioId, scenarioTime, true);

                    obj.logger.error('Worker %d, Scenario %d: Processing failed. Error: %s', ...
                        workerId, scenarioId, scenarioError.message);
                    obj.logger.error('Stack trace: %s', getReport(scenarioError, 'extended', 'hyperlinks', 'off'));
                end

            end

            % Log completion statistics
            obj.logCompletionStatistics(workerId, successfulScenarios, failedScenarios, simulationStartTime);
        end

        function executeScenario(obj, scenarioId, workerId)
            % executeScenario - Execute a single scenario using ChangShuo engine
            % 中文说明：executeScenario 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            % This method handles the complete lifecycle of a single scenario:
            % 1. Instantiate ChangShuo engine
            % 2. Configure engine with factory configurations
            % 3. Generate all frames for this scenario (delegated to ChangShuo)
            % 4. Save scenario data
            % 5. Clean up engine resources
            %
            % Input Arguments:
            %   scenarioId (integer) - Unique identifier for this scenario
            %   workerId (integer) - Worker ID processing this scenario

            obj.logger.debug('Worker %d: Starting scenario %d execution', workerId, scenarioId);

            % Instantiate ChangShuo engine for this scenario
            engineHandle = obj.RunnerConfig.Engine.Handle;
            changShuoEngine = feval(engineHandle);

            try
                % Configure ChangShuo engine with factory configurations
                obj.configureChangShuoEngine(changShuoEngine, scenarioId);

                obj.logger.debug('Worker %d, Scenario %d: Delegating frame generation to ChangShuo engine', ...
                    workerId, scenarioId);

                % Generate all frames for this scenario using ChangShuo engine
                % ChangShuo determines frame count from scenario configuration internally
                [scenarioData, scenarioAnnotation] = step(changShuoEngine, scenarioId);

                % Phase 3 (audit §3.5 / §17.5 P3-7): capture blueprint
                % provenance via the public read-only `LastGlobalLayout`
                % property + `csrd.core.ChangShuo.extractProvenanceFromGlobalLayout`
                % static helper. The legacy
                % `getScenarioBlueprintProvenance` Hidden accessor + try/catch
                % + ismethod ladder was removed in Phase 3 / S7. The helper
                % returns a fully-populated three-key struct even on a fresh
                % engine (LastGlobalLayout = struct()), so no defensive
                % wrapping is needed here.
                blueprintProvenance = ...
                    csrd.core.ChangShuo.extractProvenanceFromGlobalLayout( ...
                        changShuoEngine.LastGlobalLayout);

                % Save scenario data and annotation
                obj.saveScenarioData(scenarioData, scenarioAnnotation, ...
                    scenarioId, workerId, blueprintProvenance);

                obj.logger.debug('Worker %d, Scenario %d: Data saved successfully', workerId, scenarioId);

            catch engineError
                if csrd.pipeline.scenario.isScenarioSkipException(engineError)
                    obj.logger.warning('Worker %d, Scenario %d: Scenario skipped - %s', ...
                        workerId, scenarioId, engineError.message);
                    return;
                end

                obj.logger.error('Worker %d, Scenario %d: ChangShuo engine error: %s', ...
                    workerId, scenarioId, engineError.message);
                rethrow(engineError);
            end

            % Clean up engine resources (always execute)
            if exist('changShuoEngine', 'var') && ~isempty(changShuoEngine)

                if ismethod(changShuoEngine, 'cleanup')
                    changShuoEngine.cleanup();
                end

                clear changShuoEngine;
            end

        end

        function configureChangShuoEngine(obj, engine, scenarioId)
            % configureChangShuoEngine - Configure ChangShuo engine for specific scenario
            % 中文说明：configureChangShuoEngine 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            % DESIGN PRINCIPLE:
            %   - Each factory receives ONLY its own configuration
            %   - ScenarioFactory: scenario blueprint (spatial, temporal, frequency)
            %   - Other factories: their specific implementation details
            %   - NO cross-factory dependencies in configuration
            
            % Single assignment - FactoryConfigs is the unified config source
            engine.FactoryConfigs = obj.FactoryConfigs;

            obj.logger.debug('ChangShuo engine configured for scenario %d', scenarioId);
        end

        function normalizeAndValidateFactoryRuntimeContracts(obj)
            %NORMALIZEANDVALIDATEFACTORYRUNTIMECONTRACTS Enforce Phase 18 contracts.
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            % 中文说明：直传 FactoryConfigs 的路径也必须走配置加载后的同一合同。
            if isempty(obj.FactoryConfigs)
                error('SimulationRunner:ConfigError', ...
                    'FactoryConfigs are required before SimulationRunner setup.');
            end
            wrappedConfig = struct();
            wrappedConfig.Runner = obj.RunnerConfig;
            wrappedConfig.Factories = obj.FactoryConfigs;
            wrappedConfig.Metadata = struct();
            wrappedConfig = csrd.pipeline.runtime.normalizeRuntimeContracts(wrappedConfig);
            obj.FactoryConfigs = wrappedConfig.Factories;
        end

        function saveScenarioData(obj, scenarioData, scenarioAnnotation, ...
                scenarioId, workerId, blueprintProvenance)
            % saveScenarioData - Save scenario data and annotation to files
            % 中文说明：saveScenarioData 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            % Phase 2 (audit C4) added the optional `blueprintProvenance`
            % argument carrying BlueprintHash / BlueprintResamples /
            % ValidatorVersion captured from the ScenarioFactory before
            % the engine is torn down. Callers are responsible for
            % materialising it; if absent we default to an empty struct
            % so legacy paths continue to work during incremental
            % rollouts (the annotation will then carry empty strings,
            % not missing fields, satisfying the C4 schema invariant).
            if nargin < 6 || ~isstruct(blueprintProvenance)
                blueprintProvenance = struct( ...
                    'BlueprintHash', '', ...
                    'BlueprintResamples', 0, ...
                    'ValidatorVersion', '');
            end

            % Save scenario data
            scenarioDataPath = fullfile(obj.actualOutputDirectory, 'scenarios', ...
                sprintf('scenario_%06d_data.mat', scenarioId));

            try

                if obj.RunnerConfig.Data.CompressData
                    save(scenarioDataPath, 'scenarioData', '-v7.3', '-nocompression');
                else
                    save(scenarioDataPath, 'scenarioData', '-v7.3');
                end

                obj.logger.debug('Saved scenario data: %s', scenarioDataPath);
            catch saveError
                obj.logger.error('Failed to save scenario data for scenario %d: %s', ...
                    scenarioId, saveError.message);
            end

            % Save scenario annotation
            annotationPath = fullfile(obj.actualOutputDirectory, 'annotations', ...
                sprintf('scenario_%06d_annotation.json', scenarioId));

            % v0.4 deep refactor: scenario / processing / save metadata
            % is the single responsibility of stampRuntimeHeader and
            % lives exclusively under Header.Runtime. The transitional
            % top-level ScenarioId / ProcessedBy / SavedAt mirror that
            % Phase 0 carried for "v2 migration" has been dropped to
            % keep the annotation schema unambiguous.
            [cleanAnnotation, sanitizeManifest] = ...
                csrd.pipeline.annotation.sanitizeForJson(scenarioAnnotation);

            cleanAnnotation = obj.stampRuntimeHeader( ...
                cleanAnnotation, sanitizeManifest, scenarioId, workerId, ...
                blueprintProvenance);

            % Phase 4 (audit §17.6 / §S7 / C4): annotation write-back
            % hook. The static helper raises CSRD:Annotation:* if any
            % SignalSources(k) is missing a v2 top-level key or any
            % Truth.Measured.{SourcePlane,FramePlane} required scalar.
            % We deliberately let it propagate OUT of saveScenarioData
            % so the upstream `engineError` catch in `processScenario`
            % can run it through `isScenarioSkipException` (Phase 4
            % whitelisted the `CSRD:Annotation:` token) and demote the
            % failure to a per-scenario skip instead of fatal-aborting
            % the entire sweep. Wrapping it in a local try/catch here
            % would silently swallow the contract violation, which is
            % exactly the silent-fallback class of bug Phase 4 is
            % designed to flush out -- so do NOT add try/catch around
            % this call.
            csrd.core.ChangShuo.validateMeasurementCompleteness(cleanAnnotation);

            try
                jsonString = jsonencode(cleanAnnotation, 'PrettyPrint', true);
                fid = fopen(annotationPath, 'w');

                if fid == -1
                    obj.logger.error('Cannot open annotation file for writing: %s', annotationPath);
                else
                    fprintf(fid, '%s', jsonString);
                    fclose(fid);
                    obj.logger.debug('Saved annotation: %s', annotationPath);
                end

            catch saveError
                obj.logger.error('Failed to save annotation for scenario %d: %s', ...
                    scenarioId, saveError.message);
            end

        end

        function validateToolboxesFromConfig(obj)
            % Phase 0: resolve tier from RunnerConfig.Toolbox.Level (or
            % 中文说明：validateToolboxesFromConfig 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            % default to 'standard'), then call the shared validator.

            obj.toolboxLevel = 'standard';
            if isfield(obj.RunnerConfig, 'Toolbox') ...
                    && isstruct(obj.RunnerConfig.Toolbox) ...
                    && isfield(obj.RunnerConfig.Toolbox, 'Level') ...
                    && ~isempty(obj.RunnerConfig.Toolbox.Level)
                obj.toolboxLevel = lower(char(obj.RunnerConfig.Toolbox.Level));
            end

            try
                report = csrd.runtime.toolbox.validateRequiredToolboxes( ...
                    obj.toolboxLevel);
                obj.logger.info(['Toolbox validation passed at level ', ...
                    '"%s" (%d toolboxes checked).'], ...
                    obj.toolboxLevel, numel(report.Required));
            catch toolboxErr
                % Re-emit through logger before rethrow so the failure
                % is visible in the rolling log file as well, not only
                % on the console.
                obj.logger.critical(['Toolbox validation FAILED at level ', ...
                    '"%s": %s'], obj.toolboxLevel, toolboxErr.message);
                rethrow(toolboxErr);
            end
        end

        function applyLogPolicyFromConfig(obj)
            % Phase 0: read RunnerConfig.Log.Policy (default 'Standard'),
            % 中文说明：applyLogPolicyFromConfig 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            % apply via LogPolicy, and cache the description for later
            % stamping into annotations.

            policyLevel = 'Standard';
            if isfield(obj.RunnerConfig, 'Log') ...
                    && isstruct(obj.RunnerConfig.Log) ...
                    && isfield(obj.RunnerConfig.Log, 'Policy') ...
                    && ~isempty(obj.RunnerConfig.Log.Policy)
                policyLevel = char(obj.RunnerConfig.Log.Policy);
            end

            policy = csrd.runtime.logger.policy.LogPolicy(policyLevel);
            policy.apply();
            obj.logPolicyDescription = policy.describe();
        end

        function annotation = stampRuntimeHeader( ...
                obj, annotation, sanitizeManifest, scenarioId, workerId, ...
                blueprintProvenance)
            %STAMPRUNTIMEHEADER Wrap and stamp scenario annotation metadata.
            % 中文说明：stampRuntimeHeader 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            %   The saved annotation JSON is always shaped as
            %       {
            %         "Header": { "Runtime": { ... mandatory keys ... } },
            %         "Frames": <ChangShuo.stepImpl raw output>
            %       }
            %   with the following mandatory Header.Runtime keys (Phase 2):
            %       LogPolicy / ToolboxLevel / ScenarioId / WorkerId /
            %       SavedAt / SanitizeManifest /
            %       BlueprintHash / BlueprintResamples / ValidatorVersion
            %
            %   The last three keys are the Phase 2 (audit C4) blueprint
            %   provenance: they let downstream tooling (baseline sweep,
            %   AI/ML data pipelines) reason about which canonical
            %   blueprint produced this annotation and how many resample
            %   attempts were needed before the BlueprintFeasibilityValidator
            %   accepted it. They are always written; missing values
            %   collapse to empty string / 0 so the schema is invariant.
            %
            %   ChangShuo.stepImpl always returns a cell array (per-frame,
            %   per-receiver). To keep the on-disk schema uniform we wrap
            %   any non-struct payload under `Frames`. When the upstream
            %   payload is already a struct that contains a `Frames` field
            %   we leave it as-is (it already follows the contract).

            if nargin < 6 || ~isstruct(blueprintProvenance)
                blueprintProvenance = struct( ...
                    'BlueprintHash', '', ...
                    'BlueprintResamples', 0, ...
                    'ValidatorVersion', '');
            end

            if ~isstruct(annotation)
                wrapped = struct();
                wrapped.Frames = annotation;
                annotation = wrapped;
            elseif ~isfield(annotation, 'Frames')
                payload = annotation;
                annotation = struct();
                annotation.Frames = payload;
            end

            annotation.Header = struct();
            annotation.Header.Runtime = struct();
            annotation.Header.Runtime.LogPolicy        = obj.logPolicyDescription;
            annotation.Header.Runtime.ToolboxLevel     = obj.toolboxLevel;
            annotation.Header.Runtime.ScenarioId       = scenarioId;
            annotation.Header.Runtime.WorkerId         = workerId;
            annotation.Header.Runtime.SavedAt          = char(datetime('now', ...
                'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''', 'TimeZone', 'UTC'));
            annotation.Header.Runtime.SanitizeManifest = sanitizeManifest;

            % Phase 2 (audit §3.4 / C4) blueprint provenance.
            annotation.Header.Runtime = ...
                csrd.SimulationRunner.injectBlueprintProvenance( ...
                    annotation.Header.Runtime, blueprintProvenance);
        end

        function [startScenario, endScenario, scenarioCount] = calculateScenarioDistribution(obj, workerId, numWorkers)
            % calculateScenarioDistribution - Calculate scenario range for specific worker
            % 中文说明：calculateScenarioDistribution 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.

            if numWorkers > obj.totalScenarios
                % More workers than scenarios
                if workerId <= obj.totalScenarios
                    startScenario = workerId;
                    endScenario = workerId;
                    scenarioCount = 1;
                else
                    startScenario = 1;
                    endScenario = 0;
                    scenarioCount = 0;
                end

            else
                % Normal distribution
                scenariosPerWorker = floor(obj.totalScenarios / numWorkers);
                remainderScenarios = mod(obj.totalScenarios, numWorkers);

                if workerId <= remainderScenarios
                    % Workers with one extra scenario
                    startScenario = (workerId - 1) * (scenariosPerWorker + 1) + 1;
                    endScenario = startScenario + scenariosPerWorker;
                    scenarioCount = scenariosPerWorker + 1;
                else
                    % Workers with standard scenario count
                    startScenario = remainderScenarios * (scenariosPerWorker + 1) + ...
                        (workerId - remainderScenarios - 1) * scenariosPerWorker + 1;
                    endScenario = startScenario + scenariosPerWorker - 1;
                    scenarioCount = scenariosPerWorker;
                end

            end

        end

        function setupDirectories(obj)
            % setupDirectories - Create necessary directory structure for data storage
            % 中文说明：setupDirectories 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            % Creates subdirectories using the global log directory as the base output directory.
            % This ensures data and logs are stored in the same session-based directory structure.

            % Get the log directory from global log manager as base output directory
            logDirectory = csrd.runtime.logger.GlobalLogManager.getLogDirectory();

            if isempty(logDirectory)
                % Fallback to default directory structure
                currentTime = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
                baseOutputDir = sprintf('%s_%s', obj.RunnerConfig.Data.OutputDirectory, currentTime);

                if ~exist(baseOutputDir, 'dir')
                    [status, msg] = mkdir(baseOutputDir);

                    if ~status
                        error('SimulationRunner:DirectoryError', ...
                            'Failed to create output directory ''%s'': %s', baseOutputDir, msg);
                    end

                    obj.logger.info('Created fallback output directory: %s', baseOutputDir);
                end

            else
                % Use the session directory (parent of logs directory)
                baseOutputDir = fileparts(logDirectory);
            end

            % Store actual output directory
            obj.actualOutputDirectory = baseOutputDir;

            % Create subdirectories for scenario-based storage
            subDirs = {'scenarios', 'annotations', 'metadata'};

            for i = 1:length(subDirs)
                subDir = fullfile(baseOutputDir, subDirs{i});

                if ~exist(subDir, 'dir')
                    [status, msg] = mkdir(subDir);

                    if ~status
                        error('SimulationRunner:DirectoryError', ...
                            'Failed to create subdirectory ''%s'': %s', subDir, msg);
                    end

                    obj.logger.debug('Created subdirectory: %s', subDir);
                end

            end

            obj.logger.info('Data storage directories configured under: %s', baseOutputDir);
        end

        function displayProgress(obj, workerId, currentScenario, totalScenarios, scenarioId, scenarioTime, isFailed)
            % displayProgress - Display detailed scenario processing progress with time information
            % 中文说明：displayProgress 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            %
            % This method displays comprehensive progress information including:
            % - Current scenario completion time
            % - Estimated remaining time based on average
            % - Processing rate (scenarios per minute)
            % - Success/failure status

            if nargin < 7
                isFailed = false;
            end

            % Calculate elapsed time since worker started
            if obj.workerStartTimes.isKey(workerId)
                workerStartTime = obj.workerStartTimes(workerId);
                totalElapsedTime = toc(workerStartTime);
            else
                totalElapsedTime = 0;
            end

            % Calculate average time per scenario and estimate remaining time
            if currentScenario > 0
                avgTimePerScenario = totalElapsedTime / currentScenario;
                remainingScenarios = totalScenarios - currentScenario;
                estimatedRemainingTime = remainingScenarios * avgTimePerScenario;

                % Calculate processing rate (scenarios per minute)
                scenariosPerMinute = (currentScenario / totalElapsedTime) * 60;
            else
                avgTimePerScenario = 0;
                estimatedRemainingTime = 0;
                scenariosPerMinute = 0;
            end

            % Format time strings
            elapsedTimeStr = obj.formatDuration(totalElapsedTime);
            remainingTimeStr = obj.formatDuration(estimatedRemainingTime);

            % Create status indicator
            if isFailed
                statusStr = '[FAILED]';
            else
                statusStr = '[SUCCESS]';
            end

            % Calculate completion percentage
            progressPercent = (currentScenario / totalScenarios) * 100;

            % Log detailed progress information
            obj.logger.info('Worker %d %s: Scenario %d/%d (ID: %d) | Time: %.2fs | Progress: %.1f%% | Elapsed: %s | ETA: %s | Rate: %.1f scenarios/min', ...
                workerId, statusStr, currentScenario, totalScenarios, scenarioId, ...
                scenarioTime, progressPercent, elapsedTimeStr, remainingTimeStr, scenariosPerMinute);
        end

        function timeStr = formatDuration(obj, seconds)
            % formatDuration - Format duration in seconds to human-readable string
            % 中文说明：formatDuration 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.

            if seconds < 60
                timeStr = sprintf('%.0fs', seconds);
            elseif seconds < 3600
                minutes = floor(seconds / 60);
                remainingSeconds = mod(seconds, 60);
                timeStr = sprintf('%dm %.0fs', minutes, remainingSeconds);
            else
                hours = floor(seconds / 3600);
                minutes = floor(mod(seconds, 3600) / 60);
                timeStr = sprintf('%dh %dm', hours, minutes);
            end

        end

        function logCompletionStatistics(obj, workerId, successfulScenarios, failedScenarios, startTime)
            % logCompletionStatistics - Log simulation completion statistics
            % 中文说明：logCompletionStatistics 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.

            totalTime = toc(startTime);
            totalProcessed = successfulScenarios + failedScenarios;

            obj.logger.info('Worker %d simulation completed:', workerId);
            obj.logger.info('  Total scenarios processed: %d', totalProcessed);
            obj.logger.info('  Successful scenarios: %d', successfulScenarios);
            obj.logger.info('  Failed scenarios: %d', failedScenarios);
            obj.logger.info('  Success rate: %.1f%%', (successfulScenarios / totalProcessed) * 100);
            obj.logger.info('  Total simulation time: %.2f seconds', totalTime);

            if totalProcessed > 0
                obj.logger.info('  Average time per scenario: %.2f seconds', totalTime / totalProcessed);
                obj.logger.info('  Scenarios per second: %.2f', totalProcessed / totalTime);
            end

        end

        function validateConfiguration(obj)
            % validateConfiguration - Validate all configuration structures
            % 中文说明：validateConfiguration 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.

            % Validate RunnerConfig - frame shape is owned by
            % Factories.Scenario.Global.FrameNumSamples.
            requiredRunnerFields = {'NumScenarios', 'Data', 'Engine'};

            for i = 1:length(requiredRunnerFields)
                field = requiredRunnerFields{i};

                if ~isfield(obj.RunnerConfig, field)
                    error('SimulationRunner:ConfigError', ...
                        'Required field ''%s'' missing from RunnerConfig.', field);
                end

            end

            % Validate scenario configuration
            if obj.RunnerConfig.NumScenarios <= 0
                error('SimulationRunner:ConfigError', ...
                'NumScenarios must be a positive integer.');
            end

            if isfield(obj.RunnerConfig, 'FixedFrameLength')
                error('SimulationRunner:ConfigError', ...
                    ['Runner.FixedFrameLength is forbidden after Phase 17; ', ...
                     'set Factories.Scenario.Global.FrameNumSamples instead.']);
            end

            % Validate data configuration
            if ~isfield(obj.RunnerConfig.Data, 'OutputDirectory')
                error('SimulationRunner:ConfigError', ...
                'Data.OutputDirectory is required in RunnerConfig.');
            end

            % Validate FactoryConfigs if provided
            if ~isempty(obj.FactoryConfigs) && ~isstruct(obj.FactoryConfigs)
                error('SimulationRunner:ConfigError', 'FactoryConfigs must be a struct.');
            end

        end

    end

    methods (Static, Hidden)

        function runtimeHeader = injectBlueprintProvenance(runtimeHeader, provenance)
            % injectBlueprintProvenance - Phase 2 (audit C4) helper that
            % 中文说明：injectBlueprintProvenance 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            % stamps the BlueprintHash / BlueprintResamples /
            % ValidatorVersion fields onto a Header.Runtime struct.
            %
            % Exposed as a Hidden static method so unit tests can
            % exercise the schema invariant directly without spinning up
            % a full SimulationRunner. Production code calls this from
            % stampRuntimeHeader (the only legitimate writer).
            %
            % Schema invariant:
            %   * BlueprintHash      -> char row, defaults to ''
            %   * BlueprintResamples -> finite double, defaults to 0
            %   * ValidatorVersion   -> char row, defaults to ''
            % Non-finite, non-numeric, or otherwise malformed inputs
            % collapse to the canonical defaults so JSON round-trip is
            % deterministic and the schema is always present.
            if ~isstruct(runtimeHeader)
                runtimeHeader = struct();
            end
            if nargin < 2 || ~isstruct(provenance)
                provenance = struct();
            end

            runtimeHeader.BlueprintHash = ...
                csrd.SimulationRunner.coerceProvenanceString(provenance, 'BlueprintHash');
            runtimeHeader.BlueprintResamples = ...
                csrd.SimulationRunner.coerceProvenanceScalar(provenance, 'BlueprintResamples');
            runtimeHeader.ValidatorVersion = ...
                csrd.SimulationRunner.coerceProvenanceString(provenance, 'ValidatorVersion');
        end

        function s = coerceProvenanceString(provenance, key)
            % Phase 2 helper: defensive string coercion so a malformed
            % 中文说明：coerceProvenanceString 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            % provenance struct cannot crash the annotation-save path.
            % Char rows and string scalars survive; everything else
            % collapses to ''.
            s = '';
            if isstruct(provenance) && isfield(provenance, key) ...
                    && ~isempty(provenance.(key))
                v = provenance.(key);
                if ischar(v) && (isempty(v) || isrow(v))
                    s = v;
                elseif isstring(v) && isscalar(v)
                    s = char(v);
                end
            end
        end

        function v = coerceProvenanceScalar(provenance, key)
            % Phase 2 helper: defensive scalar coercion that always
            % 中文说明：coerceProvenanceScalar 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.
            % produces a finite double; non-finite or non-numeric values
            % collapse to 0 so JSON round-trip is safe.
            v = 0;
            if isstruct(provenance) && isfield(provenance, key) ...
                    && ~isempty(provenance.(key)) ...
                    && isnumeric(provenance.(key)) ...
                    && isscalar(provenance.(key)) ...
                    && isfinite(provenance.(key))
                v = double(provenance.(key));
            end
        end

    end

end
