function config = default()
    % default - Default runner configuration
    %
    % Provides standard simulation execution settings.

    config.Runner.NumScenarios = 4;
    config.Runner.FixedFrameLength = 1024;
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

    % Quality Assurance Configuration
    config.Runner.QualityAssurance.EnableValidation = true;
    config.Runner.QualityAssurance.ToleranceLevel = 1e-6;
    config.Runner.QualityAssurance.StatisticalChecks = true;
    config.Runner.QualityAssurance.ReferenceComparison = false;
    config.Runner.QualityAssurance.AutoCorrection = false;
    config.Runner.QualityAssurance.ScenarioValidation = true;
end
