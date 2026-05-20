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
    %   runner = csrd.SimulationRunner( ...
    %       'RunnerConfig', masterConfig.Runner, ...
    %       'FactoryConfigs', masterConfig.Factories, ...
    %       'RuntimePlan', masterConfig.RuntimePlan);
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

        % RuntimePlan: canonical derived runtime facts built by config_loader
        RuntimePlan struct
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

        % Phase 21 performance trace. Disabled by default; when enabled by
        % Runner.Performance.EnableStageTiming it records low-overhead stage
        % wallclock into ignored artifacts/performance/phase21/.
        performanceEnabled logical = false
        performanceTrace struct = struct()
        performanceArtifactDirectory char = ''
        performanceRawEventLimit (1, 1) double = 5000
        performancePartialWriteInterval (1, 1) double = 1
        performanceHeartbeatEnabled logical = false

        % Resolved seed used for deterministic scenario scheduling. For
        % Runner.RandomSeed='shuffle' this is derived from the post-shuffle
        % RNG state so file coverage order changes with the shuffled run.
        resolvedRuntimeSeed (1, 1) double = 0
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

            setupStartTime = tic;

            % Initialize logger from GlobalLogManager
            obj.logger = csrd.runtime.logger.GlobalLogManager.getLogger();
            obj.configurePerformanceTracing();
            csrd.runtime.map.osmSiteViewerCache('clear');
            csrd.runtime.map.osmSiteViewerCache('retain', true);

            % --- Phase 0 change #2: apply LogPolicy ---
            % Order matters: apply BEFORE the first debug() so the very
            % next line is already filtered correctly when running under
            % LargeMC. See phase-0-baseline.md §6.2.
            stageStart = tic;
            obj.applyLogPolicyFromConfig();
            obj.recordPerformanceStage('Runner.ApplyLogPolicy', toc(stageStart), struct());

            obj.logger.debug('SimulationRunner setupImpl started. Initializing scenario-driven execution...');

            stageStart = tic;
            obj.validateConfiguration();
            obj.validateRuntimePlan();
            obj.recordPerformanceStage('Runner.ValidateConfiguration', toc(stageStart), struct());

            % --- Phase 0 change #1: validate required toolboxes ---
            % Fail-fast on missing toolboxes so a long sweep does not
            % crash 4 hours in with a cryptic factory error. See
            % phase-0-baseline.md §6.1.
            stageStart = tic;
            obj.validateToolboxesFromConfig();
            obj.recordPerformanceStage('Runner.ValidateToolboxes', toc(stageStart), struct());

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
                    obj.resolvedRuntimeSeed = localSeedFromRngState(rng);
                    obj.logger.debug('Random seed set to shuffle mode.');
                else
                    rng(obj.RunnerConfig.RandomSeed);
                    obj.resolvedRuntimeSeed = double(obj.RunnerConfig.RandomSeed);
                    obj.logger.debug('Random seed set to %d.', obj.RunnerConfig.RandomSeed);
                end

            end
            if isfield(obj.RuntimePlan, 'Seed') && isstruct(obj.RuntimePlan.Seed)
                obj.RuntimePlan.Seed.ResolvedRunSeed = obj.resolvedRuntimeSeed;
            end

            stageStart = tic;
            obj.setupDirectories();
            obj.recordPerformanceStage('Runner.SetupDirectories', toc(stageStart), struct());

            obj.logger.info('SimulationRunner setup completed successfully.');
            obj.logger.debug('Ready for scenario-based execution: %d total scenarios', obj.totalScenarios);
            obj.recordPerformanceStage('Runner.SetupTotal', toc(setupStartTime), struct());
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

            % Calculate scenario distribution for this specific worker.
            % Scenario IDs are assigned round-robin instead of as one
            % contiguous range. That preserves every global ScenarioId and
            % its deterministic seed while spreading slow OSM/RayTracing
            % long tails across workers.
            scenarioIds = obj.calculateScenarioIdsForWorker(workerId, numWorkers);
            workerScenarioCount = numel(scenarioIds);

            if workerScenarioCount == 0
                obj.logger.info('Worker %d: No scenarios assigned to process.', workerId);
                return;
            end
            startScenario = scenarioIds(1);
            endScenario = scenarioIds(end);

            obj.logger.info(['Worker %d: Processing %d round-robin scenarios ', ...
                '(first=%d, last=%d, stride=%d)'], ...
                workerId, workerScenarioCount, startScenario, endScenario, numWorkers);

            % Initialize timing and progress tracking
            simulationStartTime = tic;
            successfulScenarios = 0;
            failedScenarios = 0;
            skippedScenarios = 0;

            % Initialize time tracking for this worker
            if isempty(obj.workerStartTimes)
                obj.workerStartTimes = containers.Map('KeyType', 'int32', 'ValueType', 'any');
                obj.workerScenarioCounts = containers.Map('KeyType', 'int32', 'ValueType', 'int32');
            end

            obj.workerStartTimes(workerId) = simulationStartTime;
            obj.workerScenarioCounts(workerId) = workerScenarioCount;

            % Process scenarios sequentially for this worker
            for scenarioListIndex = 1:workerScenarioCount
                scenarioId = scenarioIds(scenarioListIndex);
                scenarioStartTime = tic;
                currentScenarioIndex = scenarioListIndex;

                try
                    % Execute single scenario with ChangShuo engine
                    scenarioStatus = obj.executeScenario(scenarioId, ...
                        workerId, currentScenarioIndex, workerScenarioCount);
                    scenarioTime = toc(scenarioStartTime);

                    if strcmp(scenarioStatus, 'Skipped')
                        skippedScenarios = skippedScenarios + 1;
                        obj.displayProgress(workerId, currentScenarioIndex, workerScenarioCount, ...
                            scenarioId, scenarioTime, false, 'SKIPPED');

                        obj.logger.info('Worker %d, Scenario %d: Skipped in %.2f seconds', ...
                            workerId, scenarioId, scenarioTime);
                    else
                        successfulScenarios = successfulScenarios + 1;
                        obj.displayProgress(workerId, currentScenarioIndex, workerScenarioCount, ...
                            scenarioId, scenarioTime, false, 'SUCCESS');

                        obj.logger.debug('Worker %d, Scenario %d: Completed successfully in %.2f seconds', ...
                            workerId, scenarioId, scenarioTime);
                    end

                catch scenarioError
                    failedScenarios = failedScenarios + 1;
                    scenarioTime = toc(scenarioStartTime);

                    % Display progress even for failed scenarios
                    obj.displayProgress(workerId, currentScenarioIndex, workerScenarioCount, scenarioId, scenarioTime, true);

                    obj.logger.error('Worker %d, Scenario %d: Processing failed. Error: %s', ...
                        workerId, scenarioId, scenarioError.message);
                    obj.logger.error('Stack trace: %s', getReport(scenarioError, 'extended', 'hyperlinks', 'off'));
                end

                obj.writePerformanceTrace(workerId, successfulScenarios, ...
                    failedScenarios, skippedScenarios, simulationStartTime, false);
            end

            % Log completion statistics
            obj.recordPerformanceStage('Runner.WorkerTotal', toc(simulationStartTime), ...
                struct('WorkerId', workerId, ...
                       'SuccessfulScenarios', successfulScenarios, ...
                       'FailedScenarios', failedScenarios, ...
                       'SkippedScenarios', skippedScenarios));
            obj.writePerformanceTrace(workerId, successfulScenarios, ...
                failedScenarios, skippedScenarios, simulationStartTime, true);
            csrd.runtime.map.osmSiteViewerCache('retain', false);
            csrd.runtime.map.osmSiteViewerCache('clear');

            obj.logCompletionStatistics(workerId, successfulScenarios, failedScenarios, ...
                skippedScenarios, simulationStartTime);
        end

        function status = executeScenario(obj, scenarioId, workerId, ...
                currentScenarioIndex, workerScenarioCount)
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
            if nargin < 4 || isempty(currentScenarioIndex)
                currentScenarioIndex = NaN;
            end
            if nargin < 5 || isempty(workerScenarioCount)
                workerScenarioCount = NaN;
            end
            status = 'Success';
            scenarioTotalStart = tic;
            scenarioSeed = localScenarioSeed(obj.resolvedRuntimeSeed, scenarioId);
            rng(scenarioSeed, 'twister');
            scenarioStartedAtUtc = localNowUtcMs();
            obj.writePerformanceHeartbeat(workerId, scenarioId, ...
                currentScenarioIndex, workerScenarioCount, ...
                'Scenario.Total', 'begin', scenarioStartedAtUtc, ...
                struct('ScenarioSeed', scenarioSeed));

            % Instantiate ChangShuo engine for this scenario
            engineHandle = obj.RunnerConfig.Engine.Handle;
            obj.writePerformanceHeartbeat(workerId, scenarioId, ...
                currentScenarioIndex, workerScenarioCount, ...
                'Scenario.EngineInstantiate', 'begin', scenarioStartedAtUtc, ...
                struct('ScenarioSeed', scenarioSeed));
            stageStart = tic;
            changShuoEngine = feval(engineHandle);
            stageElapsed = toc(stageStart);
            obj.recordPerformanceStage('Scenario.EngineInstantiate', stageElapsed, ...
                struct('WorkerId', workerId, 'ScenarioId', scenarioId));
            obj.writePerformanceHeartbeat(workerId, scenarioId, ...
                currentScenarioIndex, workerScenarioCount, ...
                'Scenario.EngineInstantiate', 'end', scenarioStartedAtUtc, ...
                struct('ScenarioSeed', scenarioSeed, 'ElapsedSec', stageElapsed));
            cleanupGuard = onCleanup(@() localCleanupChangShuoEngine(changShuoEngine));

            try
                % Configure ChangShuo engine with factory configurations
                obj.writePerformanceHeartbeat(workerId, scenarioId, ...
                    currentScenarioIndex, workerScenarioCount, ...
                    'Scenario.ConfigureEngine', 'begin', scenarioStartedAtUtc, ...
                    struct('ScenarioSeed', scenarioSeed));
                stageStart = tic;
                obj.configureChangShuoEngine(changShuoEngine, scenarioId, workerId);
                stageElapsed = toc(stageStart);
                obj.recordPerformanceStage('Scenario.ConfigureEngine', stageElapsed, ...
                    struct('WorkerId', workerId, 'ScenarioId', scenarioId));
                obj.writePerformanceHeartbeat(workerId, scenarioId, ...
                    currentScenarioIndex, workerScenarioCount, ...
                    'Scenario.ConfigureEngine', 'end', scenarioStartedAtUtc, ...
                    struct('ScenarioSeed', scenarioSeed, 'ElapsedSec', stageElapsed));

                obj.logger.debug('Worker %d, Scenario %d: Delegating frame generation to ChangShuo engine', ...
                    workerId, scenarioId);

                % Generate all frames for this scenario using ChangShuo engine
                % ChangShuo determines frame count from scenario configuration internally
                obj.writePerformanceHeartbeat(workerId, scenarioId, ...
                    currentScenarioIndex, workerScenarioCount, ...
                    'Scenario.ChangShuoStep', 'begin', scenarioStartedAtUtc, ...
                    struct('ScenarioSeed', scenarioSeed));
                stageStart = tic;
                [scenarioData, scenarioAnnotation] = step(changShuoEngine, scenarioId);
                stageElapsed = toc(stageStart);
                obj.recordPerformanceStage('Scenario.ChangShuoStep', stageElapsed, ...
                    struct('WorkerId', workerId, 'ScenarioId', scenarioId));
                obj.writePerformanceHeartbeat(workerId, scenarioId, ...
                    currentScenarioIndex, workerScenarioCount, ...
                    'Scenario.ChangShuoStep', 'end', scenarioStartedAtUtc, ...
                    struct('ScenarioSeed', scenarioSeed, 'ElapsedSec', stageElapsed));

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
                obj.writePerformanceHeartbeat(workerId, scenarioId, ...
                    currentScenarioIndex, workerScenarioCount, ...
                    'Scenario.SaveScenarioData', 'begin', scenarioStartedAtUtc, ...
                    struct('ScenarioSeed', scenarioSeed));
                stageStart = tic;
                obj.saveScenarioData(scenarioData, scenarioAnnotation, ...
                    scenarioId, workerId, blueprintProvenance);
                stageElapsed = toc(stageStart);
                obj.recordPerformanceStage('Scenario.SaveScenarioData', stageElapsed, ...
                    struct('WorkerId', workerId, 'ScenarioId', scenarioId));
                obj.writePerformanceHeartbeat(workerId, scenarioId, ...
                    currentScenarioIndex, workerScenarioCount, ...
                    'Scenario.SaveScenarioData', 'end', scenarioStartedAtUtc, ...
                    struct('ScenarioSeed', scenarioSeed, 'ElapsedSec', stageElapsed));

                obj.logger.debug('Worker %d, Scenario %d: Data saved successfully', workerId, scenarioId);
                totalElapsed = toc(scenarioTotalStart);
                obj.recordPerformanceStage('Scenario.Total', totalElapsed, ...
                    struct('WorkerId', workerId, 'ScenarioId', scenarioId, 'Status', status));
                obj.writePerformanceHeartbeat(workerId, scenarioId, ...
                    currentScenarioIndex, workerScenarioCount, ...
                    'Scenario.Total', 'end', scenarioStartedAtUtc, ...
                    struct('ScenarioSeed', scenarioSeed, 'ElapsedSec', totalElapsed, ...
                    'Status', status));

            catch engineError
                if csrd.pipeline.scenario.isScenarioSkipException(engineError)
                    obj.logger.warning('Worker %d, Scenario %d: Scenario skipped - %s', ...
                        workerId, scenarioId, engineError.message);
                    status = 'Skipped';
                    totalElapsed = toc(scenarioTotalStart);
                    obj.recordPerformanceStage('Scenario.Total', totalElapsed, ...
                        struct('WorkerId', workerId, 'ScenarioId', scenarioId, 'Status', status));
                    obj.writePerformanceHeartbeat(workerId, scenarioId, ...
                        currentScenarioIndex, workerScenarioCount, ...
                        'Scenario.Total', 'skipped', scenarioStartedAtUtc, ...
                        struct('ScenarioSeed', scenarioSeed, 'ElapsedSec', totalElapsed, ...
                        'Status', status, 'ErrorIdentifier', engineError.identifier, ...
                        'ErrorMessage', engineError.message));
                    return;
                end

                obj.logger.error('Worker %d, Scenario %d: ChangShuo engine error: %s', ...
                    workerId, scenarioId, engineError.message);
                totalElapsed = toc(scenarioTotalStart);
                obj.recordPerformanceStage('Scenario.Total', totalElapsed, ...
                    struct('WorkerId', workerId, 'ScenarioId', scenarioId, ...
                           'Status', 'Failed', 'ErrorIdentifier', engineError.identifier));
                obj.writePerformanceHeartbeat(workerId, scenarioId, ...
                    currentScenarioIndex, workerScenarioCount, ...
                    'Scenario.Total', 'failed', scenarioStartedAtUtc, ...
                    struct('ScenarioSeed', scenarioSeed, 'ElapsedSec', totalElapsed, ...
                    'Status', 'Failed', 'ErrorIdentifier', engineError.identifier, ...
                    'ErrorMessage', engineError.message));
                rethrow(engineError);
            end
            clear cleanupGuard;
        end

        function configureChangShuoEngine(obj, engine, scenarioId, workerId)
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
            if nargin < 4 || isempty(workerId)
                workerId = 1;
            end

            % Single assignment - FactoryConfigs is the unified config source.
            % Runtime fields are scenario-local planning context, not a second
            % authority for simulation facts. They let ScenarioFactory build a
            % deterministic coverage schedule without drawing from global RNG.
            factoryConfigs = obj.FactoryConfigs;
            if isstruct(factoryConfigs) && isfield(factoryConfigs, 'Scenario') && ...
                    isstruct(factoryConfigs.Scenario)
                runtime = struct();
                if isfield(factoryConfigs.Scenario, 'Runtime') && ...
                        isstruct(factoryConfigs.Scenario.Runtime)
                    runtime = factoryConfigs.Scenario.Runtime;
                end
                runtime.ScenarioId = double(scenarioId);
                runtime.TotalScenarios = double(obj.totalScenarios);
                runtime.WorkerId = double(workerId);
                runtime.ScenarioSeed = localScenarioSeed( ...
                    obj.resolvedRuntimeSeed, scenarioId);
                if isfield(obj.RunnerConfig, 'RandomSeed')
                    if ischar(obj.RunnerConfig.RandomSeed) || ...
                            isstring(obj.RunnerConfig.RandomSeed)
                        runtime.RandomSeed = obj.resolvedRuntimeSeed;
                        runtime.RandomSeedMode = char(string(obj.RunnerConfig.RandomSeed));
                    else
                        runtime.RandomSeed = obj.RunnerConfig.RandomSeed;
                        runtime.RandomSeedMode = 'fixed';
                    end
                end
                factoryConfigs.Scenario.Runtime = runtime;
            end

            engine.FactoryConfigs = factoryConfigs;
            engine.RuntimePlan = obj.RuntimePlan;

            obj.logger.debug('ChangShuo engine configured for scenario %d', scenarioId);
        end

        function validateRuntimePlan(obj)
            %VALIDATERUNTIMEPLAN Enforce Phase 30 runtime-plan boundary.
            % 中文说明：生产 Runner 必须接收 config_loader 构建好的 RuntimePlan。
            if isempty(obj.FactoryConfigs)
                error('SimulationRunner:ConfigError', ...
                    'FactoryConfigs are required before SimulationRunner setup.');
            end
            if isempty(obj.RuntimePlan) || ~isstruct(obj.RuntimePlan)
                error('CSRD:RuntimePlan:MissingRuntimePlan', ...
                    ['SimulationRunner.RuntimePlan is required. ', ...
                     'Load configs through csrd.runtime.config_loader.']);
            end
            expected = csrd.pipeline.runtime.buildRuntimePlan(struct( ...
                'Runner', obj.RunnerConfig, ...
                'Factories', obj.FactoryConfigs, ...
                'Metadata', struct()));
            localAssertRuntimePlanFrameMatches(obj.RuntimePlan.Frame, ...
                expected.RuntimePlan.Frame);
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

                stageStart = tic;
                if obj.RunnerConfig.Data.CompressData
                    save(scenarioDataPath, 'scenarioData', '-v7.3', '-nocompression');
                else
                    save(scenarioDataPath, 'scenarioData', '-v7.3');
                end
                obj.recordPerformanceStage('Save.MatScenarioData', toc(stageStart), ...
                    struct('WorkerId', workerId, 'ScenarioId', scenarioId));

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
            stageStart = tic;
            [cleanAnnotation, sanitizeManifest] = ...
                csrd.pipeline.annotation.sanitizeForJson(scenarioAnnotation);
            obj.recordPerformanceStage('Save.SanitizeAnnotation', toc(stageStart), ...
                struct('WorkerId', workerId, 'ScenarioId', scenarioId));

            stageStart = tic;
            cleanAnnotation = obj.stampRuntimeHeader( ...
                cleanAnnotation, sanitizeManifest, scenarioId, workerId, ...
                blueprintProvenance);
            obj.recordPerformanceStage('Save.StampRuntimeHeader', toc(stageStart), ...
                struct('WorkerId', workerId, 'ScenarioId', scenarioId));

            % Phase 4 (audit §17.6 / §S7 / C4): annotation write-back
            % hook. The static helper raises CSRD:Annotation:* if any
            % SignalSources(k) is missing a v2 top-level key or any
            % Truth.Measured.{SourcePlane,FramePlane} required scalar.
            % We deliberately let it propagate OUT of saveScenarioData
            % so the upstream `engineError` catch can count annotation
            % contract violations as hard scenario failures. Wrapping it
            % in a local try/catch here would silently swallow the
            % contract violation, which is exactly the silent-fallback
            % class of bug Phase 4/20 flushed out -- so do NOT add
            % try/catch around this call.
            stageStart = tic;
            csrd.core.ChangShuo.validateMeasurementCompleteness(cleanAnnotation);
            obj.recordPerformanceStage('Save.ValidateMeasurementCompleteness', toc(stageStart), ...
                struct('WorkerId', workerId, 'ScenarioId', scenarioId));

            try
                prettyPrintAnnotations = true;
                if isfield(obj.RunnerConfig, 'Data') && ...
                        isstruct(obj.RunnerConfig.Data) && ...
                        isfield(obj.RunnerConfig.Data, 'PrettyPrintAnnotations') && ...
                        ~isempty(obj.RunnerConfig.Data.PrettyPrintAnnotations)
                    prettyPrintAnnotations = logical(obj.RunnerConfig.Data.PrettyPrintAnnotations);
                end
                if prettyPrintAnnotations
                    stageStart = tic;
                    jsonString = jsonencode(cleanAnnotation, 'PrettyPrint', true);
                else
                    stageStart = tic;
                    jsonString = jsonencode(cleanAnnotation);
                end
                obj.recordPerformanceStage('Save.EncodeAnnotationJson', toc(stageStart), ...
                    struct('WorkerId', workerId, 'ScenarioId', scenarioId, ...
                           'PrettyPrint', prettyPrintAnnotations));
                stageStart = tic;
                fid = fopen(annotationPath, 'w');

                if fid == -1
                    obj.logger.error('Cannot open annotation file for writing: %s', annotationPath);
                else
                    fprintf(fid, '%s', jsonString);
                    fclose(fid);
                    obj.logger.debug('Saved annotation: %s', annotationPath);
                end
                obj.recordPerformanceStage('Save.WriteAnnotationJson', toc(stageStart), ...
                    struct('WorkerId', workerId, 'ScenarioId', scenarioId));

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

        function configurePerformanceTracing(obj)
            %CONFIGUREPERFORMANCETRACING Resolve optional Phase 21 timing sink.
            % 中文说明：默认关闭，仅在 Runner.Performance.EnableStageTiming=true 时写 artifact。
            obj.performanceEnabled = false;
            obj.performanceArtifactDirectory = '';
            obj.performanceTrace = struct();
            obj.performanceHeartbeatEnabled = false;

            perfCfg = struct();
            if isfield(obj.RunnerConfig, 'Performance') && ...
                    isstruct(obj.RunnerConfig.Performance)
                perfCfg = obj.RunnerConfig.Performance;
            end

            if ~isfield(perfCfg, 'EnableStageTiming') || ...
                    ~localToLogical(perfCfg.EnableStageTiming)
                csrd.runtime.performance.trace('reset');
                return;
            end

            obj.performanceEnabled = true;
            obj.performanceRawEventLimit = localPositiveIntegerField( ...
                perfCfg, {'RawEventLimit', 'MaxRawEvents'}, 5000);
            obj.performancePartialWriteInterval = localPositiveIntegerField( ...
                perfCfg, {'PartialWriteInterval'}, 1);
            obj.performanceHeartbeatEnabled = localLogicalField( ...
                perfCfg, {'EnableHeartbeat', 'EnableStageHeartbeat'}, true);
            if isfield(perfCfg, 'ArtifactDirectory') && ...
                    ~isempty(perfCfg.ArtifactDirectory)
                artifactDir = char(string(perfCfg.ArtifactDirectory));
                if ~localIsAbsolutePath(artifactDir)
                    artifactDir = fullfile(localProjectRoot(), artifactDir);
                end
            else
                artifactDir = fullfile(localProjectRoot(), 'artifacts', ...
                    'performance', 'phase21');
            end
            if ~isfolder(artifactDir)
                mkdir(artifactDir);
            end
            obj.performanceArtifactDirectory = artifactDir;
            csrd.runtime.performance.trace('start', artifactDir);
            obj.performanceTrace = struct( ...
                'Schema', 'csrd.phase22.stage-timing.v2', ...
                'GeneratedAtUtc', char(datetime('now', 'TimeZone', 'UTC', ...
                    'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z''')), ...
                'ArtifactDirectory', artifactDir, ...
                'RawEventLimit', obj.performanceRawEventLimit, ...
                'DroppedEventCount', 0, ...
                'StageSummary', struct(), ...
                'Events', struct('Stage', {}, 'ElapsedSec', {}, ...
                    'RecordedAtUtc', {}, 'Metadata', {}));
        end

        function recordPerformanceStage(obj, stageName, elapsedSec, metadata)
            %RECORDPERFORMANCESTAGE Append a lightweight timing event.
            % 中文说明：只写耗时和结构化元数据，不接触信号样本。
            if ~obj.performanceEnabled
                return;
            end
            if nargin < 4 || ~isstruct(metadata)
                metadata = struct();
            end
            event = struct( ...
                'Stage', char(string(stageName)), ...
                'ElapsedSec', double(elapsedSec), ...
                'RecordedAtUtc', char(datetime('now', 'TimeZone', 'UTC', ...
                    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''')), ...
                'Metadata', metadata);
            key = localStageKey(stageName);
            if ~isfield(obj.performanceTrace.StageSummary, key)
                obj.performanceTrace.StageSummary.(key) = struct( ...
                    'Stage', event.Stage, ...
                    'Count', 0, ...
                    'TotalElapsedSec', 0, ...
                    'MaxElapsedSec', 0, ...
                    'LastElapsedSec', 0);
            end
            summary = obj.performanceTrace.StageSummary.(key);
            summary.Count = summary.Count + 1;
            summary.TotalElapsedSec = summary.TotalElapsedSec + event.ElapsedSec;
            summary.MaxElapsedSec = max(summary.MaxElapsedSec, event.ElapsedSec);
            summary.LastElapsedSec = event.ElapsedSec;
            obj.performanceTrace.StageSummary.(key) = summary;

            if numel(obj.performanceTrace.Events) < obj.performanceRawEventLimit
                obj.performanceTrace.Events(end + 1) = event;
            else
                obj.performanceTrace.DroppedEventCount = ...
                    obj.performanceTrace.DroppedEventCount + 1;
            end
        end

        function writePerformanceHeartbeat(obj, workerId, scenarioId, ...
                currentScenarioIndex, workerScenarioCount, stageName, ...
                stageState, scenarioStartedAtUtc, metadata)
            %WRITEPERFORMANCEHEARTBEAT Persist the currently active stage.
            % 中文说明：心跳只写 ignored performance artifact，便于长尾场景未结束时定位卡点。
            if ~obj.performanceEnabled || ~obj.performanceHeartbeatEnabled
                return;
            end
            if nargin < 10 || ~isstruct(metadata)
                metadata = struct();
            end
            try
                payload = struct( ...
                    'Schema', 'csrd.phase28.scenario-heartbeat.v1', ...
                    'WorkerId', double(workerId), ...
                    'ScenarioId', double(scenarioId), ...
                    'ScenarioIndex', double(currentScenarioIndex), ...
                    'WorkerScenarioCount', double(workerScenarioCount), ...
                    'StageName', char(string(stageName)), ...
                    'StageState', char(string(stageState)), ...
                    'ScenarioStartedAtUtc', char(string(scenarioStartedAtUtc)), ...
                    'UpdatedAtUtc', localNowUtcMs(), ...
                    'Metadata', metadata);
                heartbeatPath = fullfile(obj.performanceArtifactDirectory, ...
                    sprintf('phase28-heartbeat-worker%03d.json', workerId));
                fid = fopen(heartbeatPath, 'w');
                if fid ~= -1
                    cleanup = onCleanup(@() fclose(fid));
                    fprintf(fid, '%s', jsonencode(payload));
                    clear cleanup;
                end
            catch
                % Diagnostic artifacts must never change simulation outcome.
            end
        end

        function writePerformanceTrace(obj, workerId, successfulScenarios, ...
                failedScenarios, skippedScenarios, workerTimer, finalizeTrace)
            %WRITEPERFORMANCETRACE Persist ignored Phase 21 timing artifacts.
            % 中文说明：保存到 artifacts/performance/phase21，不进入数据样本目录。
            if ~obj.performanceEnabled
                return;
            end
            if nargin < 7
                finalizeTrace = true;
            end
            try
                processedScenarios = successfulScenarios + failedScenarios + ...
                    skippedScenarios;
                if ~finalizeTrace && obj.performancePartialWriteInterval > 1 && ...
                        mod(max(1, processedScenarios), ...
                        obj.performancePartialWriteInterval) ~= 0
                    return;
                end
                totalElapsedSec = toc(workerTimer);
                obj.performanceTrace.Summary = struct( ...
                    'WorkerId', workerId, ...
                    'SuccessfulScenarios', successfulScenarios, ...
                    'FailedScenarios', failedScenarios, ...
                    'SkippedScenarios', skippedScenarios, ...
                    'TotalElapsedSec', totalElapsedSec);
                obj.performanceTrace.OsmSiteViewerCache = ...
                    csrd.runtime.map.osmSiteViewerCache('snapshot');
                obj.performanceTrace.RuntimePerformance = ...
                    csrd.runtime.performance.trace('snapshot');
                if finalizeTrace
                    traceKind = 'final';
                else
                    traceKind = 'partial';
                end
                baseName = sprintf('phase21-stage-timing-worker%03d-%s', ...
                    workerId, traceKind);
                matPath = fullfile(obj.performanceArtifactDirectory, ...
                    [baseName, '.mat']);
                jsonPath = fullfile(obj.performanceArtifactDirectory, ...
                    [baseName, '.json']);
                performanceTrace = obj.performanceTrace; %#ok<NASGU>
                save(matPath, 'performanceTrace');
                fid = fopen(jsonPath, 'w');
                if fid ~= -1
                    fprintf(fid, '%s', jsonencode(obj.performanceTrace));
                    fclose(fid);
                end
                if finalizeTrace
                    csrd.runtime.performance.trace('stop');
                end
            catch ME
                obj.logger.warning('Could not write runtime performance trace: %s', ...
                    ME.message);
            end
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
            annotation.Header.Runtime.ScenarioSeed     = ...
                localScenarioSeed(obj.resolvedRuntimeSeed, scenarioId);
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

        function scenarioIds = calculateScenarioIdsForWorker(obj, workerId, numWorkers)
            %CALCULATESCENARIOIDSFORWORKER Round-robin global scenario IDs.
            scenarioIds = localScenarioIdsForWorker( ...
                obj.totalScenarios, workerId, numWorkers);
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

        function displayProgress(obj, workerId, currentScenario, totalScenarios, scenarioId, scenarioTime, isFailed, statusOverride)
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
            if nargin < 8
                statusOverride = '';
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
            if ~isempty(statusOverride)
                statusStr = sprintf('[%s]', char(string(statusOverride)));
            elseif isFailed
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

        function logCompletionStatistics(obj, workerId, successfulScenarios, failedScenarios, skippedScenarios, startTime)
            % logCompletionStatistics - Log simulation completion statistics
            % 中文说明：logCompletionStatistics 在 CSRD 生产链路中执行对应处理。
            % Inputs / 输入: see signature arguments and local validation.
            % 输出 / Outputs: see signature return values and contract fields.

            totalTime = toc(startTime);
            totalProcessed = successfulScenarios + failedScenarios + skippedScenarios;

            obj.logger.info('Worker %d simulation completed:', workerId);
            obj.logger.info('  Total scenarios processed: %d', totalProcessed);
            obj.logger.info('  Successful scenarios: %d', successfulScenarios);
            obj.logger.info('  Failed scenarios: %d', failedScenarios);
            obj.logger.info('  Skipped scenarios: %d', skippedScenarios);
            if totalProcessed > 0
                successRate = (successfulScenarios / totalProcessed) * 100;
            else
                successRate = 0;
            end
            obj.logger.info('  Success rate: %.1f%%', successRate);
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

        function seedValue = deriveScenarioSeed(baseSeed, scenarioId)
            %DERIVESCENARIOSEED Stable per-scenario RNG seed.
            seedValue = localScenarioSeed(baseSeed, scenarioId);
        end

        function scenarioIds = deriveScenarioIdsForWorker( ...
                totalScenarios, workerId, numWorkers)
            %DERIVESCENARIOIDSFORWORKER Test hook for worker scheduling.
            scenarioIds = localScenarioIdsForWorker( ...
                totalScenarios, workerId, numWorkers);
        end

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


function localCleanupChangShuoEngine(engine)
%LOCALCLEANUPCHANGSHUOENGINE Release a scenario engine on every exit path.
if isempty(engine)
    return;
end
if ismethod(engine, 'cleanup')
    engine.cleanup();
end
end

function tf = localToLogical(value)
%LOCALTOLOGICAL Conservative bool parsing for optional runner config.
if islogical(value) && isscalar(value)
    tf = value;
elseif isnumeric(value) && isscalar(value) && isfinite(value)
    tf = value ~= 0;
elseif ischar(value) || (isstring(value) && isscalar(value))
    tf = any(strcmpi(char(string(value)), {'true', 'on', 'yes', '1'}));
else
    tf = false;
end
end

function value = localLogicalField(source, names, defaultValue)
%LOCALLOGICALFIELD Resolve optional boolean config fields.
value = logical(defaultValue);
if ~isstruct(source)
    return;
end
for idx = 1:numel(names)
    name = names{idx};
    if isfield(source, name)
        value = localToLogical(source.(name));
        return;
    end
end
end

function stamp = localNowUtcMs()
%LOCALNOWUTCMS Return an ISO-8601 UTC timestamp with millisecond resolution.
stamp = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z'''));
end

function projectRoot = localProjectRoot()
%LOCALPROJECTROOT Resolve repository root from this package file.
projectRoot = fileparts(fileparts(mfilename('fullpath')));
end

function tf = localIsAbsolutePath(pathText)
%LOCALISABSOLUTEPATH Windows/Unix absolute path probe.
tf = ~isempty(regexp(pathText, '^[A-Za-z]:[\\/]|^[/\\]', 'once'));
end

function value = localPositiveIntegerField(source, names, defaultValue)
%LOCALPOSITIVEINTEGERFIELD Resolve optional positive integer config fields.
value = defaultValue;
if ~isstruct(source)
    return;
end
for idx = 1:numel(names)
    name = names{idx};
    if isfield(source, name) && isnumeric(source.(name)) && ...
            isscalar(source.(name)) && isfinite(source.(name)) && ...
            source.(name) > 0
        value = max(1, floor(double(source.(name))));
        return;
    end
end
end

function key = localStageKey(stageName)
%LOCALSTAGEKEY Convert a stage name to a valid struct field.
key = regexprep(char(string(stageName)), '[^A-Za-z0-9_]', '_');
if isempty(key)
    key = 'UnnamedStage';
elseif ~isletter(key(1))
    key = ['Stage_', key];
end
end

function seedValue = localSeedFromRngState(state)
%LOCALSEEDFROMRNGSTATE Derive a stable schedule seed from MATLAB RNG state.
seedValue = 0;
if ~isstruct(state) || ~isfield(state, 'State') || isempty(state.State)
    return;
end
values = double(state.State(:));
sampleCount = min(numel(values), 128);
modulus = 2^31 - 1;
hash = 5381;
for idx = 1:sampleCount
    hash = mod(hash * 33 + values(idx), modulus);
end
seedValue = double(hash);
end

function seedValue = localScenarioSeed(baseSeed, scenarioId)
%LOCALSCENARIOSEED Derive a stable global-RNG seed for one scenario.
% The seed is a function of the run-level seed and global ScenarioId only,
% so parallel workers cannot duplicate random sequences merely because each
% worker process starts from the same Runner.RandomSeed.
modulus = 2^31 - 1;
if nargin < 1 || isempty(baseSeed) || ~isnumeric(baseSeed) || ...
        ~isscalar(baseSeed) || ~isfinite(baseSeed)
    baseSeed = 0;
end
if nargin < 2 || isempty(scenarioId) || ~isnumeric(scenarioId) || ...
        ~isscalar(scenarioId) || ~isfinite(scenarioId) || scenarioId < 1
    scenarioId = 1;
end
text = sprintf('csrd-scenario-seed|%.0f|%.0f', ...
    floor(double(baseSeed)), floor(double(scenarioId)));
bytes = uint8(unicode2native(text, 'UTF-8'));
hash = 1;
for idx = 1:numel(bytes)
    hash = mod(hash * 48271 + double(bytes(idx)) + idx, modulus);
end
hash = mod(hash * 69621 + floor(double(baseSeed)) + ...
    104729 * floor(double(scenarioId)), modulus);
hash = mod(hash * 48271 + 1, modulus);
seedValue = double(mod(hash, modulus - 1)) + 1;
if seedValue < 1
    seedValue = 1;
end
end

function localAssertRuntimePlanFrameMatches(actualFrame, expectedFrame)
%LOCALASSERTRUNTIMEPLANFRAMEMATCHES Ensure plan matches current config.
required = {'FrameNumSamples', 'FrameDurationSec', ...
    'NumFramesPerScenario', 'ObservationDurationSec', 'SampleRateHz'};
for idx = 1:numel(required)
    field = required{idx};
    if ~isfield(actualFrame, field) || ~isfield(expectedFrame, field)
        error('CSRD:RuntimePlan:FrameContractMismatch', ...
            'RuntimePlan.Frame.%s is required.', field);
    end
    actual = double(actualFrame.(field));
    expected = double(expectedFrame.(field));
    tolerance = max(1e-9 * max(abs([actual, expected])), 1e-9);
    if abs(actual - expected) > tolerance
        error('CSRD:RuntimePlan:FrameContractMismatch', ...
            'RuntimePlan.Frame.%s=%g but config resolves to %g.', ...
            field, actual, expected);
    end
end
end

function scenarioIds = localScenarioIdsForWorker(totalScenarios, workerId, numWorkers)
%LOCALSCENARIOIDSFORWORKER Assign global IDs by stride to balance long tails.
if nargin < 1 || isempty(totalScenarios) || ~isnumeric(totalScenarios) || ...
        ~isscalar(totalScenarios) || ~isfinite(totalScenarios)
    totalScenarios = 0;
end
if nargin < 2 || isempty(workerId) || ~isnumeric(workerId) || ...
        ~isscalar(workerId) || ~isfinite(workerId)
    workerId = 1;
end
if nargin < 3 || isempty(numWorkers) || ~isnumeric(numWorkers) || ...
        ~isscalar(numWorkers) || ~isfinite(numWorkers)
    numWorkers = 1;
end
totalScenarios = max(0, floor(double(totalScenarios)));
workerId = max(1, floor(double(workerId)));
numWorkers = max(1, floor(double(numWorkers)));
if workerId > numWorkers || workerId > totalScenarios
    scenarioIds = zeros(1, 0);
else
    scenarioIds = workerId:numWorkers:totalScenarios;
end
end
