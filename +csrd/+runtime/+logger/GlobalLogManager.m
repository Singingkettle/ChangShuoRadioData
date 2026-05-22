classdef GlobalLogManager < handle
    % GlobalLogManager - Global logging manager for CSRD framework
    %
    % This class provides a singleton pattern for logging across the entire
    % ChangShuoRadioData (CSRD) framework, ensuring all components use the
    % same logger instance with consistent configuration and output.
    %
    % Key Features:
    %   - Singleton pattern for global logger access
    %   - Automatic log folder creation and management
    %   - Consistent logging configuration across all components
    %   - File and console output coordination
    %   - Session-based log file organization
    %
    % Usage:
    %   % Initialize global logging (typically called once at startup)
    %   csrd.runtime.logger.GlobalLogManager.initialize(runtimePlan.Logging, outputDir);
    %
    %   % Get logger instance (called by any component)
    %   logger = csrd.runtime.logger.GlobalLogManager.getLogger();
    %
    %   % Use logger
    %   logger.info('This message goes to both console and file');

    properties (Access = private, Constant)
        % Default logger name for CSRD framework
        DEFAULT_LOGGER_NAME = 'CSRD';
    end

    properties (Access = private)
        % The global logger instance
        loggerInstance

        % Logger configuration
        logConfig

        % Output directory for log files
        logDirectory

        % Initialization status
        isInitialized = false
    end

    methods (Access = private)

        function obj = GlobalLogManager()
            % Private constructor for singleton pattern
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
        end

    end

    methods (Static)

        function initialize(logConfig, outputDirectory)
            % initialize - Initialize global logging system
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            %
            % This method sets up the global logger with specified configuration
            % and output directory. Should be called once at application startup.
            %
            % Syntax:
            %   GlobalLogManager.initialize(logConfig, outputDirectory)
            %
            % Input Arguments:
            %   logConfig - RuntimePlan.Logging structure
            %               .Policy - Log policy tier
            %               .ConsoleThreshold - Console threshold level
            %               .FileThreshold - File threshold level
            %               .ConsoleEnabled - Enable console logging
            %               .FileEnabled - Enable file logging
            %   outputDirectory - Base directory for log files

            manager = csrd.runtime.logger.GlobalLogManager.getInstance();

            if manager.isInitialized
                warning('GlobalLogManager:AlreadyInitialized', ...
                'Global log manager is already initialized. Skipping re-initialization.');
                return;
            end

            % Store the resolved runtime logging plan.
            logConfig = localResolveLogConfig(logConfig);
            manager.logConfig = logConfig;

            % Setup log directory
            if nargin < 2 || isempty(outputDirectory)
                outputDirectory = fullfile(pwd, 'artifacts', 'tests', ...
                    'runs', 'global_logs');
            end

            % Create timestamped session directory
            currentTime = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
            sessionDirectory = fullfile(outputDirectory, sprintf('session_%s', currentTime));
            manager.logDirectory = fullfile(sessionDirectory, 'logs');

            % Create directory if it doesn't exist
            if ~exist(manager.logDirectory, 'dir')
                [status, msg] = mkdir(manager.logDirectory);

                if ~status
                    error('GlobalLogManager:DirectoryError', ...
                        'Failed to create log directory "%s": %s', manager.logDirectory, msg);
                end

            end

            % Create logger instance with timestamped name
            loggerName = sprintf('%s_%s', manager.DEFAULT_LOGGER_NAME, currentTime);
            manager.loggerInstance = csrd.runtime.logger.Log.getInstance(loggerName);

            % Set log thresholds and output directory
            if logConfig.FileEnabled
                manager.loggerInstance.FileThreshold = logConfig.FileThreshold;
                manager.loggerInstance.LogFolder = manager.logDirectory;
            else
                manager.loggerInstance.FileThreshold = csrd.runtime.logger.mlog.Level.NONE; % Disable file logging
            end

            if logConfig.ConsoleEnabled
                manager.loggerInstance.CommandWindowThreshold = logConfig.ConsoleThreshold;
            else
                manager.loggerInstance.CommandWindowThreshold = csrd.runtime.logger.mlog.Level.NONE; % Disable console logging
            end

            manager.isInitialized = true;

            % Log initialization success
            manager.loggerInstance.info('=== CSRD Global Logging System Initialized ===');
            manager.loggerInstance.info('Log Policy: %s', logConfig.Policy);
            manager.loggerInstance.info('File Logging: %s', string(logConfig.FileEnabled));
            manager.loggerInstance.info('Console Logging: %s', string(logConfig.ConsoleEnabled));
            manager.loggerInstance.info('Log Directory: %s', manager.logDirectory);
            manager.loggerInstance.info('Logger Name: %s', loggerName);
        end

        function logger = getLogger()
            % getLogger - Get the global logger instance
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            %
            % Returns the global logger instance. If not initialized, returns
            % a default logger with warning.
            %
            % Syntax:
            %   logger = GlobalLogManager.getLogger()
            %
            % Output Arguments:
            %   logger - Global logger instance

            manager = csrd.runtime.logger.GlobalLogManager.getInstance();

            if ~manager.isInitialized
                warning('GlobalLogManager:NotInitialized', ...
                'Global log manager not initialized. Creating default logger.');

                % Create default configuration
                defaultConfig = struct();
                defaultConfig.Name = manager.DEFAULT_LOGGER_NAME;
                defaultConfig.Level = 'INFO';
                defaultConfig.SaveToFile = true;
                defaultConfig.DisplayInConsole = true;

                % Initialize with defaults
                csrd.runtime.logger.GlobalLogManager.initialize(defaultConfig);
            end

            logger = manager.loggerInstance;
        end

        function logDir = getLogDirectory()
            % getLogDirectory - Get the current log directory path
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            %
            % Returns the path where log files are being saved.
            %
            % Syntax:
            %   logDir = GlobalLogManager.getLogDirectory()
            %
            % Output Arguments:
            %   logDir - Path to log directory

            manager = csrd.runtime.logger.GlobalLogManager.getInstance();

            if manager.isInitialized
                logDir = manager.logDirectory;
            else
                logDir = '';
            end

        end

        function reset()
            % reset - Reset the global logging system
            %
            % This method resets the global logging system, allowing for
            % re-initialization. Useful for testing or configuration changes.

            manager = csrd.runtime.logger.GlobalLogManager.getInstance();

            if manager.isInitialized && ~isempty(manager.loggerInstance)
                manager.loggerInstance.info('=== CSRD Global Logging System Reset ===');
            end

            manager.isInitialized = false;
            manager.loggerInstance = [];
            manager.logConfig = [];
            manager.logDirectory = '';
        end

        function status = getInitializationStatus()
            % getInitializationStatus - Check if global logging is initialized
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.
            %
            % Returns true if the global logging system has been initialized.
            %
            % Syntax:
            %   status = GlobalLogManager.getInitializationStatus()
            %
            % Output Arguments:
            %   status - True if initialized, false otherwise

            manager = csrd.runtime.logger.GlobalLogManager.getInstance();
            status = manager.isInitialized;
        end

    end

    methods (Static, Access = private)

        function obj = getInstance()
            % getInstance - Get singleton instance of GlobalLogManager
            % Inputs: see signature arguments and local validation.
            % Outputs: see signature return values and contract fields.

            persistent instance

            if isempty(instance) || ~isvalid(instance)
                instance = csrd.runtime.logger.GlobalLogManager();
            end

            obj = instance;
        end

    end

end

function resolved = localResolveLogConfig(logConfig)
    % localResolveLogConfig - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if nargin < 1 || isempty(logConfig) || ~isstruct(logConfig)
    logConfig = struct();
end

if isfield(logConfig, 'Policy')
    policyName = char(string(logConfig.Policy));
elseif isfield(logConfig, 'Level')
    policyName = localPolicyFromLevel(logConfig.Level);
else
    policyName = 'Standard';
end
policy = csrd.runtime.logger.policy.LogPolicy(policyName);
desc = policy.describe();

resolved = struct();
resolved.Name = localTextField(logConfig, 'Name', 'CSRD');
resolved.Policy = desc.Level;
resolved.ConsoleThreshold = localLevelField(logConfig, ...
    'ConsoleThreshold', desc.ConsoleThreshold);
resolved.FileThreshold = localLevelField(logConfig, ...
    'FileThreshold', desc.FileThreshold);
resolved.ConsoleEnabled = localLogicalField(logConfig, ...
    {'ConsoleEnabled', 'DisplayInConsole'}, true);
resolved.FileEnabled = localLogicalField(logConfig, ...
    {'FileEnabled', 'SaveToFile'}, true);
end

function policyName = localPolicyFromLevel(level)
    % localPolicyFromLevel - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
levelText = upper(char(string(level)));
switch levelText
    case {'DEBUG', 'DETAIL', 'TRACE'}
        policyName = 'Dev';
    case {'WARNING', 'ERROR', 'CRITICAL', 'FATAL'}
        policyName = 'LargeMC';
    otherwise
        policyName = 'Standard';
end
end

function value = localTextField(source, fieldName, defaultValue)
    % localTextField - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
value = char(defaultValue);
if isfield(source, fieldName) && ~isempty(source.(fieldName))
    value = char(string(source.(fieldName)));
end
end

function value = localLevelField(source, fieldName, defaultValue)
    % localLevelField - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isfield(source, fieldName) && ~isempty(source.(fieldName))
    value = localParseLevel(source.(fieldName));
else
    value = localParseLevel(defaultValue);
end
end

function level = localParseLevel(value)
    % localParseLevel - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isa(value, 'csrd.runtime.logger.mlog.Level')
    level = value;
    return;
end
levelText = upper(char(string(value)));
switch levelText
    case 'NONE'
        level = csrd.runtime.logger.mlog.Level.NONE;
    case 'FATAL'
        level = csrd.runtime.logger.mlog.Level.FATAL;
    case 'CRITICAL'
        level = csrd.runtime.logger.mlog.Level.CRITICAL;
    case 'ERROR'
        level = csrd.runtime.logger.mlog.Level.ERROR;
    case 'WARNING'
        level = csrd.runtime.logger.mlog.Level.WARNING;
    case 'INFO'
        level = csrd.runtime.logger.mlog.Level.INFO;
    case 'MESSAGE'
        level = csrd.runtime.logger.mlog.Level.MESSAGE;
    case 'DEBUG'
        level = csrd.runtime.logger.mlog.Level.DEBUG;
    case 'DETAIL'
        level = csrd.runtime.logger.mlog.Level.DETAIL;
    case 'TRACE'
        level = csrd.runtime.logger.mlog.Level.TRACE;
    otherwise
        error('GlobalLogManager:InvalidLogLevel', ...
            'Unsupported log threshold "%s".', levelText);
end
end

function value = localLogicalField(source, names, defaultValue)
    % localLogicalField - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
value = logical(defaultValue);
for idx = 1:numel(names)
    name = names{idx};
    if ~isfield(source, name) || isempty(source.(name))
        continue;
    end
    raw = source.(name);
    if islogical(raw) && isscalar(raw)
        value = raw;
    elseif isnumeric(raw) && isscalar(raw) && isfinite(raw)
        value = raw ~= 0;
    elseif ischar(raw) || (isstring(raw) && isscalar(raw))
        value = any(strcmpi(char(string(raw)), {'true', 'on', 'yes', '1'}));
    end
    return;
end
end
