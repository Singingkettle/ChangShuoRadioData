function config = debug()
    % debug - Debug logging configuration
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 debug 实现。
    %
    % Provides verbose logging settings for development and debugging.

    config.baseConfigs = {'_base_/logging/default.m'};

    % Override for debug settings
    config.Log.Level = 'DEBUG';
    config.Log.IncludeStackTrace = true;
    config.Log.MaxFileSize = '50MB'; % Larger files for debug logs
    config.Log.RotationCount = 10; % Keep more debug logs
end
