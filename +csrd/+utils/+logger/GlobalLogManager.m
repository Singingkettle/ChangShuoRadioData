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
    %   csrd.utils.logger.GlobalLogManager.initialize(runnerConfig.Log, outputDir);
    %
    %   % Get logger instance (called by any component)
    %   logger = csrd.utils.logger.GlobalLogManager.getLogger();
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
        end

    end

    methods (Static)

        function initialize(logConfig, outputDirectory)
            % initialize - Initialize global logging system
            %
            % This method sets up the global logger with specified configuration
            % and output directory. Should be called once at application startup.
            %
            % Syntax:
            %   GlobalLogManager.initialize(logConfig, outputDirectory)
            %
            % Input Arguments:
            %   logConfig - Log configuration structure
            %               .Name - Logger name
            %               .Level - Log level ('DEBUG', 'INFO', 'WARNING', 'ERROR')
            %               .SaveToFile - Enable file logging
            %               .DisplayInConsole - Enable console logging
            %   outputDirectory - Base directory for log files

            manager = csrd.utils.logger.GlobalLogManager.getInstance();

            if manager.isInitialized
                warning('GlobalLogManager:AlreadyInitialized', ...
                'Global log manager is already initialized. Skipping re-initialization.');
                return;
            end

            % Store configuration
            manager.logConfig = logConfig;

            % Setup log directory
            if nargin < 2 || isempty(outputDirectory)
                outputDirectory = fullfile(pwd, 'csrd_simulation_output');
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
            manager.loggerInstance = csrd.utils.logger.Log.getInstance(loggerName);

            % Configure log levels
            logLevel = upper(logConfig.Level);

            switch logLevel
                case 'DEBUG'
                    mlogLevel = mlog.Level.DEBUG;
                case 'INFO'
                    mlogLevel = mlog.Level.INFO;
                case 'WARNING'
                    mlogLevel = mlog.Level.WARNING;
                case 'ERROR'
                    mlogLevel = mlog.Level.ERROR;
                case 'CRITICAL'
                    mlogLevel = mlog.Level.CRITICAL;
                otherwise
                    mlogLevel = mlog.Level.INFO; % Default
                    % Use direct console output since logger isn't fully initialized yet
                    if logConfig.DisplayInConsole
                        disp(sprintf('[GlobalLogManager] Unknown log level "%s", using INFO', logLevel));
                    end

            end

            % Set log thresholds and output directory
            if logConfig.SaveToFile
                manager.loggerInstance.FileThreshold = mlogLevel;
                manager.loggerInstance.LogFolder = manager.logDirectory;
            else
                manager.loggerInstance.FileThreshold = mlog.Level.NONE; % Disable file logging
            end

            if logConfig.DisplayInConsole
                manager.loggerInstance.CommandWindowThreshold = mlogLevel;
            else
                manager.loggerInstance.CommandWindowThreshold = mlog.Level.NONE; % Disable console logging
            end

            manager.isInitialized = true;

            % Log initialization success
            manager.loggerInstance.info('=== CSRD Global Logging System Initialized ===');
            manager.loggerInstance.info('Log Level: %s', logLevel);
            manager.loggerInstance.info('File Logging: %s', string(logConfig.SaveToFile));
            manager.loggerInstance.info('Console Logging: %s', string(logConfig.DisplayInConsole));
            manager.loggerInstance.info('Log Directory: %s', manager.logDirectory);
            manager.loggerInstance.info('Logger Name: %s', loggerName);
        end

        function logger = getLogger()
            % getLogger - Get the global logger instance
            %
            % Returns the global logger instance. If not initialized, returns
            % a default logger with warning.
            %
            % Syntax:
            %   logger = GlobalLogManager.getLogger()
            %
            % Output Arguments:
            %   logger - Global logger instance

            manager = csrd.utils.logger.GlobalLogManager.getInstance();

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
                csrd.utils.logger.GlobalLogManager.initialize(defaultConfig);
            end

            logger = manager.loggerInstance;
        end

        function logDir = getLogDirectory()
            % getLogDirectory - Get the current log directory path
            %
            % Returns the path where log files are being saved.
            %
            % Syntax:
            %   logDir = GlobalLogManager.getLogDirectory()
            %
            % Output Arguments:
            %   logDir - Path to log directory

            manager = csrd.utils.logger.GlobalLogManager.getInstance();

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

            manager = csrd.utils.logger.GlobalLogManager.getInstance();

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
            %
            % Returns true if the global logging system has been initialized.
            %
            % Syntax:
            %   status = GlobalLogManager.getInitializationStatus()
            %
            % Output Arguments:
            %   status - True if initialized, false otherwise

            manager = csrd.utils.logger.GlobalLogManager.getInstance();
            status = manager.isInitialized;
        end

    end

    methods (Static, Access = private)

        function obj = getInstance()
            % getInstance - Get singleton instance of GlobalLogManager

            persistent instance

            if isempty(instance) || ~isvalid(instance)
                instance = csrd.utils.logger.GlobalLogManager();
            end

            obj = instance;
        end

    end

end
