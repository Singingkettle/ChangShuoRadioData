function config = debug()
    % debug - Debug logging configuration
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    %
    % Provides verbose logging settings for development and debugging.

    config.baseConfigs = {'_base_/logging/default.m'};

    % Override for debug settings.
    config.Logging.Policy = 'Dev';
    config.Logging.IncludeStackTrace = true;
    config.Logging.Progress.Mode = 'Detailed';
end
