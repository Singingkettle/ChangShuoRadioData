function masterConfig = config_loader(config_name)
    % config_loader - Modular configuration loader for CSRD framework
    %
    % This function loads and composes complete CSRD configurations from modular
    % configuration files using inheritance and merging. It serves as the main
    % interface for all configuration loading needs in the CSRD framework.
    %
    % Features:
    %   - Loads modular configurations with inheritance support
    %   - Composes complete configurations for framework integration
    %   - Validates configuration completeness
    %   - Handles circular dependency detection
    %   - Deep merging of nested structures
    %
    % Syntax:
    %   masterConfig = csrd.utils.config_loader()
    %   masterConfig = csrd.utils.config_loader(config_name)
    %
    % Input Arguments:
    %   config_name - (optional) Specific configuration to load
    %                 Default: 'csrd2025/csrd2025.m'
    %                 Type: string or char array
    %
    % Output Arguments:
    %   masterConfig - Complete CSRD framework configuration structure
    %                  Contains: Runner, Log, Factories, Metadata
    %
    % Examples:
    %   % Load default configuration
    %   config = csrd.utils.config_loader();
    %
    %   % Load specific configuration
    %   config = csrd.utils.config_loader('csrd2025/csrd2025.m');
    %
    % Configuration File Format:
    %   function config = your_config()
    %       config.baseConfigs = {'_base_/runners/default.m', '_base_/factories/scenario_factory.m'};
    %       config.Runner.NumScenarios = 100;  % Override specific fields
    %       config.CustomField = 'custom_value';  % Add new fields
    %   end
    %
    % See also: initialize_csrd_configuration

    if nargin < 1
        config_name = 'csrd2025/csrd2025.m'; % Default configuration
    end

    % Load configuration using the modular system
    masterConfig = load_config_with_inheritance(config_name);

    % Add composition metadata for tracking
    masterConfig.Metadata.ConfigurationSystem = 'Modular';
    masterConfig.Metadata.LoadedConfig = config_name;

    if ~isfield(masterConfig.Metadata, 'Version')
        masterConfig.Metadata.Version = '2025.1.0';
    end

    if ~isfield(masterConfig.Metadata, 'CreatedDate')
        masterConfig.Metadata.CreatedDate = datetime('now');
    end

    if ~isfield(masterConfig.Metadata, 'Description')
        masterConfig.Metadata.Description = 'CSRD Framework Modular Configuration';
    end

    if ~isfield(masterConfig.Metadata, 'Author')
        masterConfig.Metadata.Author = 'ChangShuo';
    end

    if ~isfield(masterConfig.Metadata, 'Architecture')
        masterConfig.Metadata.Architecture = 'Modular-Hierarchical';
    end

    if ~isfield(masterConfig.Metadata, 'LastModified')
        masterConfig.Metadata.LastModified = datetime('now');
    end

    masterConfig.Metadata.LoaderVersion = '2.0';

    % Ensure all required top-level fields exist for framework integration
    masterConfig = ensureRequiredFields(masterConfig);

    % Validate essential factory configurations
    validateFactoryConfigurations(masterConfig);

    fprintf('[CSRD Config] Modular configuration loaded successfully: %s\n', config_name);

end

function config = load_config_with_inheritance(config_file)
    % load_config_with_inheritance - Load configuration with inheritance support
    %
    % This function handles loading of modular configuration files with
    % inheritance through baseConfigs field, providing deep merging and
    % circular dependency detection.

    % Find config directory (go up from +csrd/+utils to project root, then to config)
    utils_dir = fileparts(mfilename('fullpath'));
    csrd_dir = fileparts(utils_dir); % +csrd
    project_root = fileparts(csrd_dir); % project root
    config_dir = fullfile(project_root, 'config');

    % Resolve full path
    if ~isempty(config_file) && config_file(1) ~= filesep && (length(config_file) < 2 || config_file(2) ~= ':')
        full_path = fullfile(config_dir, config_file);
    else
        full_path = config_file;
    end

    % Load configuration with inheritance resolution
    config = load_config_recursive(full_path, config_dir, {});
end

function config = load_config_recursive(config_file, config_dir, visited_files)
    % load_config_recursive - Recursively load and merge configurations
    %
    % This function handles the recursive loading and merging of configuration
    % files, including circular dependency detection and base configuration
    % resolution.

    % Normalize path for circular dependency detection
    [~, name, ext] = fileparts(config_file);

    if isempty(ext)
        config_file = [config_file '.m'];
    end

    % Check for circular dependencies
    if any(strcmp(config_file, visited_files))
        error('ConfigLoader:CircularDependency', ...
            'Circular dependency detected: %s', strjoin([visited_files, {config_file}], ' -> '));
    end

    % Add current file to visited list
    visited_files = [visited_files, {config_file}];

    % Check if file exists
    if ~exist(config_file, 'file')
        error('ConfigLoader:FileNotFound', 'Configuration file not found: %s', config_file);
    end

    % Load the configuration function
    [config_path, config_name, ~] = fileparts(config_file);

    % Add config path to MATLAB path temporarily
    original_path = path;
    cleanup_path = onCleanup(@() path(original_path));

    if ~isempty(config_path)
        addpath(config_path);
    end

    try
        % Execute the configuration function
        config_handle = str2func(config_name);
        config = config_handle();
    catch ME
        error('ConfigLoader:ExecutionError', ...
            'Failed to execute configuration file %s: %s', config_file, ME.message);
    end

    % Process base inheritance using baseConfigs field
    if isfield(config, 'baseConfigs') && ~isempty(config.baseConfigs)
        base_configs = config.baseConfigs;

        if ischar(base_configs) || isstring(base_configs)
            base_configs = {base_configs};
        end

        % Load and merge base configurations
        merged_base = struct();

        for i = 1:length(base_configs)
            base_file = base_configs{i};

            % Resolve relative path
            if base_file(1) ~= filesep && (length(base_file) < 2 || base_file(2) ~= ':')
                base_file = fullfile(config_dir, base_file);
            end

            % Load base configuration recursively
            base_config = load_config_recursive(base_file, config_dir, visited_files);

            % Merge base configuration
            merged_base = merge_configs(merged_base, base_config);
        end

        % Remove baseConfigs field and merge with current config
        config = rmfield(config, 'baseConfigs');
        config = merge_configs(merged_base, config);
    end

end

function merged = merge_configs(base_config, override_config)
    % merge_configs - Deep merge two configuration structures
    %
    % This function performs a deep merge of two configuration structures,
    % where override_config takes precedence over base_config for overlapping
    % fields.

    merged = base_config;

    if isempty(override_config)
        return;
    end

    override_fields = fieldnames(override_config);

    for i = 1:length(override_fields)
        field_name = override_fields{i};
        override_value = override_config.(field_name);

        if isfield(merged, field_name) && isstruct(merged.(field_name)) && isstruct(override_value)
            % Recursively merge nested structures
            merged.(field_name) = merge_configs(merged.(field_name), override_value);
        else
            % Override or add new field
            merged.(field_name) = override_value;
        end

    end

end

function masterConfig = ensureRequiredFields(masterConfig)
    % ensureRequiredFields - Ensure all required configuration fields exist
    %
    % This function ensures that the loaded configuration contains all required
    % fields and structures for the CSRD framework to function properly. It
    % sets defaults for any missing fields to prevent runtime errors.

    % Ensure Runner field exists
    if ~isfield(masterConfig, 'Runner')
        masterConfig.Runner = struct();
    end

    % Ensure Log field exists
    if ~isfield(masterConfig, 'Log')
        masterConfig.Log = struct();
    end

    % Ensure Factories field exists
    if ~isfield(masterConfig, 'Factories')
        masterConfig.Factories = struct();
    end

    % Ensure Metadata field exists
    if ~isfield(masterConfig, 'Metadata')
        masterConfig.Metadata = struct();
    end

end

function validateFactoryConfigurations(masterConfig)
    % validateFactoryConfigurations - Validate essential factory configurations
    %
    % This function ensures that critical factory configurations are present
    % and loads defaults for any missing essential factories.

    required_factories = {'Scenario'};

    for i = 1:length(required_factories)
        factory_name = required_factories{i};

        if ~isfield(masterConfig.Factories, factory_name)
            warning('ConfigLoader:MissingFactory', 'Factory %s not found', factory_name);
        end

    end

end
