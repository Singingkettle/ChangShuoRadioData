function config = csrd2025()
    % csrd2025 - CSRD2025 dataset configuration example
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
    config.Runner.FixedFrameLength = 1024; % Fixed length for all generated data frames
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

    % Quality Assurance Configuration
    config.Runner.QualityAssurance.EnableValidation = true; % Enable validation
    config.Runner.QualityAssurance.ToleranceLevel = 1e-6; % Numerical tolerance
    config.Runner.QualityAssurance.StatisticalChecks = true; % Enable statistical validation
    config.Runner.QualityAssurance.ReferenceComparison = false; % Enable reference comparison
    config.Runner.QualityAssurance.AutoCorrection = false; % Enable auto correction
    config.Runner.QualityAssurance.ScenarioValidation = true; % Enable scenario validation

    % Global Logging Configuration - matches initialize_csrd_configuration.m
    config.Log.Name = 'CSRD';
    config.Log.Level = 'DEBUG'; % Log level for this dataset
    config.Log.SaveToFile = true; % Save logs to file
    config.Log.DisplayInConsole = true; % Display logs in console
    config.Log.MaxFileSize = '10MB'; % Maximum log file size
    config.Log.RotationCount = 5; % Number of rotated log files
    config.Log.TimestampFormat = 'yyyy-MM-dd HH:mm:ss.SSS'; % Timestamp format
    config.Log.IncludeStackTrace = false; % Include stack trace
    config.Log.PerformanceMetrics = true; % Enable performance metrics
    config.Log.SessionLogging = true; % Enable session logging
    config.Log.ComponentLogging = true; % Enable component logging
    config.Log.FactoryLogging = true; % Enable factory logging
    config.Log.EngineLogging = true; % Enable engine logging
    config.Log.ScenarioProgress = true; % Log scenario progress
    config.Log.GlobalErrorTracking = true; % Enable error tracking

    % Factory Configurations - inherited from base configurations
    % The complete factory configurations are loaded via baseConfigs inheritance:
    % - Scenario: Complete scenario factory configuration (from _base_/factories/scenario_factory.m)
    % - Message: Message generation factory configuration (from _base_/factories/message_factory.m)
    % - Modulation: Modulation factory configuration (from _base_/factories/modulation_factory.m)
    % - Transmit: Transmitter factory configuration (from _base_/factories/transmit_factory.m)
    % - Channel: Channel factory configuration (from _base_/factories/channel_factory.m)
    % - Receive: Receiver factory configuration (from _base_/factories/receive_factory.m)
    % All factory configurations will be automatically merged during config loading

    % Configuration metadata - matches initialize_csrd_configuration.m structure
    config.Metadata.Version = '2025.1.0';
    config.Metadata.CreatedDate = datetime('now');
    config.Metadata.Description = 'CSRD Framework Master Configuration';
    config.Metadata.Author = 'ChangShuo';
    % config.Metadata.CompatibilityVersion removed - no longer needed
    config.Metadata.Architecture = 'Scenario-Driven';
    config.Metadata.LastModified = datetime('now');
end
