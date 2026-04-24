function test_map_config_validation()
    % test_map_config_validation - Verify ScenarioFactory rejects invalid map ratio config.

    fprintf('=== Map Config Validation Test ===\n');

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(projectRoot);

    masterConfig = csrd.utils.config_loader('csrd2025/csrd2025.m');
    scenarioConfig = masterConfig.Factories.Scenario;

    scenarioConfig.PhysicalEnvironment.Map.Types = {'Statistical', 'OSM'};
    scenarioConfig.PhysicalEnvironment.Map.Ratio = [1.0];
    factory = csrd.factories.ScenarioFactory('Config', scenarioConfig);
    try
        setup(factory);
        error('test_map_config_validation:MissingError', ...
            'ScenarioFactory should reject mismatched Map.Types and Map.Ratio lengths.');
    catch ME
        assert(strcmp(ME.identifier, 'ScenarioFactory:ConfigError'), ...
            'Expected ScenarioFactory:ConfigError, got %s', ME.identifier);
        fprintf('  [OK] Rejected mismatched Map.Types / Map.Ratio.\n');
    end

    scenarioConfig = masterConfig.Factories.Scenario;
    scenarioConfig.PhysicalEnvironment.Map.Types = {'Statistical', 'OSM'};
    scenarioConfig.PhysicalEnvironment.Map.Ratio = [1.0, -1.0];
    factory = csrd.factories.ScenarioFactory('Config', scenarioConfig);
    try
        setup(factory);
        error('test_map_config_validation:MissingError', ...
            'ScenarioFactory should reject negative map ratios.');
    catch ME
        assert(strcmp(ME.identifier, 'ScenarioFactory:ConfigError'), ...
            'Expected ScenarioFactory:ConfigError, got %s', ME.identifier);
        fprintf('  [OK] Rejected negative map ratios.\n');
    end

    fprintf('=== Map Config Validation Test Passed ===\n');
end
