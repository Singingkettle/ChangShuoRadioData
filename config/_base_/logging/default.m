function config = default()
    % default - Default logging configuration
    %
    % Provides standard logging settings suitable for most use cases.

    config.Log.Name = 'CSRD';
    config.Log.Level = 'INFO';
    config.Log.SaveToFile = true;
    config.Log.DisplayInConsole = true;
    config.Log.MaxFileSize = '10MB';
    config.Log.RotationCount = 5;
    config.Log.TimestampFormat = 'yyyy-MM-dd HH:mm:ss.SSS';
    config.Log.IncludeStackTrace = false;
    config.Log.PerformanceMetrics = true;
    config.Log.SessionLogging = true;
    config.Log.ComponentLogging = true;
    config.Log.FactoryLogging = true;
    config.Log.EngineLogging = true;
    config.Log.ScenarioProgress = true;
    config.Log.GlobalErrorTracking = true;
end
