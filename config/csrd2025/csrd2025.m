function config = csrd2025()
    % csrd2025 - CSRD2025 dataset configuration example
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    %
    % This example shows how to create modular configuration
    % by inheriting from base configurations and overriding specific settings.

    config.baseConfigs = {
                          '_base_/logging/default.m',
                          '_base_/runners/default.m',
                          '_base_/factories/scenario_factory.m',
                          '_base_/factories/message_factory.m',
                          '_base_/factories/modulation_factory.m',
                          '_base_/factories/transmit_factory.m',
                          '_base_/factories/channel_factory.m',
                          '_base_/factories/receive_factory.m'
                          };

    % Runner configuration - matches initialize_csrd_configuration.m structure
    config.Runner.NumScenarios = 4; % Total number of scenarios to execute
    config.Runner.RandomSeed = 'shuffle'; % Random seed for reproducibility
    config.Runner.SimulationMode = 'Scenario-Driven'; % Execution mode
    config.Runner.ValidationLevel = 'Moderate'; % Validation strictness

    % Data Storage and Management Configuration
    config.Runner.Data.OutputDirectory = 'CSRD2025';
    config.Runner.Data.SaveFormat = 'mat'; % File format
    config.Runner.Data.CompressData = true; % Enable data compression
    config.Runner.Data.MetadataIncluded = true; % Include comprehensive metadata
    config.Runner.Data.BackupEnabled = false; % Enable automatic backup
    config.Runner.Data.MaxFileSize = '100MB'; % Maximum individual file size
    config.Runner.Data.RetentionPolicy = 'Keep'; % Data retention policy
    config.Runner.Data.VersionControl = true; % Enable version control
    config.Runner.Data.ScenarioGrouping = true; % Group data by scenario
    config.Runner.Data.PrettyPrintAnnotations = false; % Compact JSON for production speed

    % Parallel Processing Configuration
    config.Runner.Parallel.UseParallel = false; % Enable parallel processing
    config.Runner.Parallel.ScenarioDistribution = 'Auto'; % Distribution strategy
    config.Runner.Parallel.MaxWorkers = 4; % Maximum number of workers
    config.Runner.Parallel.LoadBalancing = 'Auto'; % Load balancing strategy
    config.Runner.Parallel.MemoryManagement = 'Conservative'; % Memory strategy
    config.Runner.Parallel.GPUAcceleration = false; % Enable GPU acceleration
    config.Runner.Parallel.ClusterSupport = false; % Enable cluster processing

    % Engine Configuration
    config.Runner.Engine.Handle = 'csrd.core.ChangShuo';
    config.Runner.Engine.ResetBetweenScenarios = true; % Reset engine state
    config.Runner.Engine.CacheOptimization = true; % Enable caching
    config.Runner.Engine.ErrorRecovery = 'Graceful'; % Error recovery strategy
    config.Runner.Engine.PerformanceMonitoring = true; % Enable monitoring
    config.Runner.Engine.InstancePerScenario = true; % Create new instance per scenario

    % Phase 21 performance tracing. Production default stays off; profiling
    % tools turn this on and write ignored artifacts/performance/phase21/.
    config.Runner.Performance.EnableStageTiming = false;
    config.Runner.Performance.ArtifactDirectory = fullfile('artifacts', 'performance', 'phase21');

    % Quality Assurance Configuration
    config.Runner.QualityAssurance.EnableValidation = true; % Enable validation
    config.Runner.QualityAssurance.ToleranceLevel = 1e-6; % Numerical tolerance
    config.Runner.QualityAssurance.StatisticalChecks = true; % Enable statistical validation
    config.Runner.QualityAssurance.ReferenceComparison = false; % Enable reference comparison
    config.Runner.QualityAssurance.AutoCorrection = false; % Enable auto correction
    config.Runner.QualityAssurance.ScenarioValidation = true; % Enable scenario validation

    % Global logging policy.
    config.Logging.Name = 'CSRD';
    config.Logging.Policy = 'LargeMC';
    config.Logging.Console.Enabled = true;
    config.Logging.File.Enabled = true;
    config.Logging.Progress.Mode = 'Summary';
    config.Logging.TimestampFormat = 'yyyy-MM-dd HH:mm:ss.SSS';
    config.Logging.IncludeStackTrace = false;

    % Factory Configurations - inherited from base configurations
    % The complete factory configurations are loaded via baseConfigs inheritance:
    % - Scenario: Complete scenario factory configuration (from _base_/factories/scenario_factory.m)
    % - Message: Message generation factory configuration (from _base_/factories/message_factory.m)
    % - Modulation: Modulation factory configuration (from _base_/factories/modulation_factory.m)
    % - Transmit: Transmitter factory configuration (from _base_/factories/transmit_factory.m)
    % - Channel: Channel factory configuration (from _base_/factories/channel_factory.m)
    % - Receive: Receiver factory configuration (from _base_/factories/receive_factory.m)
    % All factory configurations will be automatically merged during config loading

    % Dataset SNR shaping: use the controlled target-SNR mode so each burst's
    % realized SNR is drawn uniformly from a spectrum-sensing-useful band rather
    % than the physically-emergent link-budget value. Even at realistic
    % distances the link-budget SNR is dominated by high broadcast/mobile
    % transmit powers and narrowband noise bandwidths and sits far too high
    % (median ~58 dB) for detection/classification training. The physical
    % distance still drives path loss and Doppler, the link-budget SNR is still
    % recorded as ComputedSNR provenance, and the receiver ADC dynamic range
    % still bounds the realized SNR.
    config.Factories.Channel.LinkBudget.EnableDistanceBasedSNR = false;
    config.Factories.Channel.LinkBudget.TargetSnrRangeDb = [-10, 30];

    % Configuration metadata - matches initialize_csrd_configuration.m structure
    config.Metadata.Version = '2025.1.0';
    config.Metadata.CreatedDate = datetime('now');
    config.Metadata.Description = 'CSRD Framework Master Configuration';
    config.Metadata.Author = 'ChangShuo';
    % config.Metadata.CompatibilityVersion removed - no longer needed
    config.Metadata.Architecture = 'Scenario-Driven';
    config.Metadata.LastModified = datetime('now');
end
