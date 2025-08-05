function simulation(worker_id, num_workers, config_name)
    % simulation - CSRD Framework Simulation Entry Point
    %
    % This function serves as the main entry point for ChangShuoRadioData (CSRD)
    % simulation execution. It creates and executes a SimulationRunner that manages
    % multiple communication scenarios, with each scenario handled by a ChangShuo
    % engine instance that generates the specified number of frames.
    %
    % Architecture Flow:
    %   simulation.m (entry) -> SimulationRunner (scenario manager) -> ChangShuo (frame generator)
    %
    % Syntax:
    %   simulation()                              % Default single worker execution
    %   simulation(worker_id)                     % Single worker with specific ID
    %   simulation(worker_id, num_workers)        % Multi-worker execution
    %   simulation(worker_id, num_workers, config_name) % Custom configuration
    %
    % Input Arguments:
    %   worker_id (optional)  - Worker identifier for parallel processing
    %                          Default: 1, Range: [1, num_workers]
    %   num_workers (optional)- Total number of workers in parallel execution
    %                          Default: 1, Range: [1, inf]
    %   config_name (optional)- Configuration name (e.g., 'csrd2025/csrd2025.m')
    %                          Default: 'csrd2025/csrd2025.m'
    %                          Type: string or char array
    %
    % Examples:
    %   % Single worker simulation with default configuration
    %   simulation();
    %
    %   % Multi-worker simulation (worker 2 of 4)
    %   simulation(2, 4);
    %
    %   % Custom configuration simulation
    %   simulation(1, 1, 'csrd2025/my_custom_config.m');
    %
    % See also: csrd.SimulationRunner, csrd.utils.config_loader, csrd.core.ChangShuo

    try
        % === MATLAB Path Setup ===
        % Add project root directory to MATLAB path to access +csrd package
        projectRoot = setupProjectPath();

        % === Input Parameter Validation and Defaults ===
        if nargin < 1 || isempty(worker_id)
            worker_id = 1;
        end

        if nargin < 2 || isempty(num_workers)
            num_workers = 1;
        end

        if nargin < 3 || isempty(config_name)
            % Default to standard modular configuration
            config_name = 'csrd2025/csrd2025.m';
        end

        % Validate input parameters
        validateInputParameters(worker_id, num_workers, config_name);

        % === Configuration Loading ===
        fprintf('[CSRD Simulation] Loading configuration: %s\n', config_name);
        configStruct = csrd.utils.config_loader(config_name);

        % === Global Logging Initialization ===
        % Reset global logging system to ensure clean initialization
        csrd.utils.logger.GlobalLogManager.reset();

        % Initialize global logging system with Log configuration
        if isfield(configStruct, 'Log')
            logConfig = configStruct.Log;
        else
            % Fallback to default log configuration
            logConfig = struct();
            logConfig.Name = 'CSRD';
            logConfig.Level = 'INFO';
            logConfig.SaveToFile = true;
            logConfig.DisplayInConsole = true;
        end

        if isfield(configStruct, 'Runner') && isfield(configStruct.Runner, 'Data') && ...
                isfield(configStruct.Runner.Data, 'OutputDirectory')
            outputDir = fullfile(projectRoot, 'data', configStruct.Runner.Data.OutputDirectory);
        else
            outputDir = fullfile(projectRoot, 'data');
        end

        % Initialize global logging system
        csrd.utils.logger.GlobalLogManager.initialize(logConfig, outputDir);
        logger = csrd.utils.logger.GlobalLogManager.getLogger();

        logger.info('=== CSRD Simulation Session Started ===');
        logger.info('Worker: %d of %d', worker_id, num_workers);
        logger.info('Configuration: %s', config_name);
        logger.info('Output Directory: %s', outputDir);

        % === System Configuration Information ===
        sysInfoCollector = csrd.utils.sysinfo.SystemInfoCollector();
        sysInfoCollector.collectAndLog(logger);

        % === SimulationRunner Creation and Execution ===
        logger.info('Creating SimulationRunner for worker %d of %d', worker_id, num_workers);

        % Create SimulationRunner with complete configuration
        runner = csrd.SimulationRunner('RunnerConfig', configStruct.Runner);

        % Configure runner with factory configurations (includes scenario config)
        runner.FactoryConfigs = configStruct.Factories;

        logger.info('Starting scenario-based simulation execution...');

        % Execute simulation with worker parameters
        % SimulationRunner will manage scenarios and instantiate ChangShuo for each scenario
        runner(worker_id, num_workers);

        logger.info('=== CSRD Simulation Session Completed Successfully ===');
        logger.info('Worker %d finished processing', worker_id);

    catch simulationError
        % Enhanced error handling with global logging
        if exist('logger', 'var') && ~isempty(logger)
            logger.error('=== CSRD Simulation Session Failed ===');
            logger.error('Critical error in worker %d: %s', worker_id, simulationError.message);
            logger.error('Error identifier: %s', simulationError.identifier);

            if ~isempty(simulationError.stack)
                logger.error('Error location: %s (line %d)', ...
                    simulationError.stack(1).file, simulationError.stack(1).line);
            end

            logger.error('Full stack trace: %s', getReport(simulationError, 'extended', 'hyperlinks', 'off'));
        else
            % Fallback to console if logger not available
            fprintf(2, '[CSRD Simulation] Critical error in worker %d: %s\n', worker_id, simulationError.message);
        end

        % Re-throw with enhanced context
        error('CSRD:SimulationFailed', 'Simulation failed for worker %d: %s', worker_id, simulationError.message);
    end

end

function projectRoot = setupProjectPath()
    % setupProjectPath - Setup MATLAB path for CSRD project
    %
    % This function adds the project root directory to MATLAB path
    % to ensure all packages (+csrd, +config, etc.) can be found.
    %
    % Output Arguments:
    %   projectRoot - Path to the project root directory

    % Get the directory of this script (tools/)
    scriptDir = fileparts(mfilename('fullpath'));

    % Get project root directory (parent of tools/)
    projectRoot = fileparts(scriptDir);

    % Add project root to MATLAB path if not already there
    if ~contains(path, projectRoot)
        addpath(projectRoot);
        fprintf('[CSRD Setup] Added project root to MATLAB path: %s\n', projectRoot);
    end

    % Verify that csrd package can be found
    try

        if exist('csrd.SimulationRunner', 'class') ~= 8
            fprintf('[CSRD Setup] Warning: csrd.SimulationRunner class not found after path setup\n');
        else
            fprintf('[CSRD Setup] CSRD package successfully located\n');
        end

    catch
        fprintf('[CSRD Setup] Warning: Could not verify csrd package availability\n');
    end

end

function validateInputParameters(worker_id, num_workers, config_name)
    % validateInputParameters - Validate simulation input parameters
    %
    % This function validates all input parameters for the simulation function,
    % ensuring they meet the required constraints and data types.

    % Validate worker_id
    if ~isnumeric(worker_id) || ~isscalar(worker_id) || worker_id < 1 || mod(worker_id, 1) ~= 0
        error('CSRD:InvalidWorkerID', 'worker_id must be a positive integer');
    end

    % Validate num_workers
    if ~isnumeric(num_workers) || ~isscalar(num_workers) || num_workers < 1 || mod(num_workers, 1) ~= 0
        error('CSRD:InvalidNumWorkers', 'num_workers must be a positive integer');
    end

    % Validate worker_id <= num_workers
    if worker_id > num_workers
        error('CSRD:WorkerIDExceedsTotal', 'worker_id (%d) cannot exceed num_workers (%d)', worker_id, num_workers);
    end

    % Validate config_name
    if ~ischar(config_name) && ~isstring(config_name)
        error('CSRD:InvalidConfigName', 'config_name must be a string or character array');
    end

    % Convert string to char for consistency
    if isstring(config_name)
        config_name = char(config_name);
    end

    % Validate config_name is not empty
    if isempty(config_name)
        error('CSRD:EmptyConfigName', 'config_name cannot be empty');
    end

    fprintf('[CSRD Validation] All input parameters validated successfully\n');
    fprintf('[CSRD Validation] Worker: %d of %d, Config: %s\n', worker_id, num_workers, config_name);

end
