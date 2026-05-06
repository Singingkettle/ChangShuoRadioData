function config = default()
    % default - Default runner configuration
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 default 实现。
    %
    % Provides standard simulation execution settings.

    config.Runner.NumScenarios = 4;
    config.Runner.RandomSeed = 'shuffle';
    config.Runner.SimulationMode = 'Scenario-Driven';
    config.Runner.ValidationLevel = 'Moderate';

    % Data Storage Configuration
    config.Runner.Data.OutputDirectory = 'CSRD2025';
    config.Runner.Data.SaveFormat = 'mat';
    config.Runner.Data.CompressData = true;
    config.Runner.Data.MetadataIncluded = true;
    config.Runner.Data.BackupEnabled = false;
    config.Runner.Data.MaxFileSize = '100MB';
    config.Runner.Data.RetentionPolicy = 'Keep';
    config.Runner.Data.VersionControl = true;
    config.Runner.Data.ScenarioGrouping = true;

    % Parallel Processing Configuration
    config.Runner.Parallel.UseParallel = false;
    config.Runner.Parallel.ScenarioDistribution = 'Auto';
    config.Runner.Parallel.MaxWorkers = 4;
    config.Runner.Parallel.LoadBalancing = 'Auto';
    config.Runner.Parallel.MemoryManagement = 'Conservative';
    config.Runner.Parallel.GPUAcceleration = false;
    config.Runner.Parallel.ClusterSupport = false;

    % Engine Configuration
    config.Runner.Engine.Handle = 'csrd.core.ChangShuo';
    config.Runner.Engine.ResetBetweenScenarios = true;
    config.Runner.Engine.CacheOptimization = true;
    config.Runner.Engine.ErrorRecovery = 'Graceful';
    config.Runner.Engine.PerformanceMonitoring = true;
    config.Runner.Engine.InstancePerScenario = true;

    % Phase 21 performance tracing is opt-in. It writes only runtime timing
    % artifacts under ignored artifacts/performance/phase21/, never signal data.
    config.Runner.Performance.EnableStageTiming = false;
    config.Runner.Performance.ArtifactDirectory = fullfile('artifacts', 'performance', 'phase21');

    % Quality Assurance Configuration
    config.Runner.QualityAssurance.EnableValidation = true;
    config.Runner.QualityAssurance.ToleranceLevel = 1e-6;
    config.Runner.QualityAssurance.StatisticalChecks = true;
    config.Runner.QualityAssurance.ReferenceComparison = false;
    config.Runner.QualityAssurance.AutoCorrection = false;
    config.Runner.QualityAssurance.ScenarioValidation = true;
end
