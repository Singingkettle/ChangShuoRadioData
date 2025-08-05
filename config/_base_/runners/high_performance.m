function config = high_performance()
    % high_performance - High performance runner configuration
    %
    % Optimized settings for high-throughput simulation runs.

    config.baseConfigs = {'_base_/runners/default.m'};

    % Override for performance
    config.Runner.NumScenarios = 100;
    config.Runner.Parallel.UseParallel = true;
    config.Runner.Parallel.MaxWorkers = 8;
    config.Runner.Parallel.MemoryManagement = 'Aggressive';
    config.Runner.Parallel.GPUAcceleration = true;
    config.Runner.Engine.CacheOptimization = true;
    config.Runner.QualityAssurance.StatisticalChecks = false; % Disable for speed
end
