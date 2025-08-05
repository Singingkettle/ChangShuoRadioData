function config = debug()
    % debug - Debug logging configuration
    %
    % Provides verbose logging settings for development and debugging.

    config.baseConfigs = {'_base_/logging/default.m'};

    % Override for debug settings
    config.Log.Level = 'DEBUG';
    config.Log.IncludeStackTrace = true;
    config.Log.MaxFileSize = '50MB'; % Larger files for debug logs
    config.Log.RotationCount = 10; % Keep more debug logs
end
