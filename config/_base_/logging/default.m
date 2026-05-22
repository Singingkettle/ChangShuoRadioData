function config = default()
    % default - Default logging configuration
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    %
    % Provides standard logging settings suitable for most use cases.

    config.Logging.Name = 'CSRD';
    config.Logging.Policy = 'Standard';
    config.Logging.Console.Enabled = true;
    config.Logging.File.Enabled = true;
    config.Logging.Progress.Mode = 'Detailed';
    config.Logging.TimestampFormat = 'yyyy-MM-dd HH:mm:ss.SSS';
    config.Logging.IncludeStackTrace = false;
end
