function framesPerScenario = getFramesPerScenarioFromConfig(obj)
    % getFramesPerScenarioFromConfig - Extract frame count from scenario configuration
    %
    % This method parses the scenario configuration to determine how many
    % frames should be generated for the current scenario instance. It
    % demonstrates the clean architecture where frame count is determined
    % by scenario configuration rather than external parameters.
    %
    % Configuration Path:
    %   FactoryConfigs.Scenario.Global.NumFramesPerScenario
    %
    % Output:
    %   framesPerScenario - Number of frames to generate for this scenario
    %
    % Default Behavior:
    %   Returns 1 frame if configuration is missing or invalid
    %
    % Example:
    %   % Scenario config defines 5 frames per scenario
    %   factoryConfigs.Scenario.Global.NumFramesPerScenario = 5;
    %   framesPerScenario = obj.getFramesPerScenarioFromConfig(); % Returns 5

    % Default value
    framesPerScenario = 1;

    % Extract from factory configurations
    if ~isempty(obj.FactoryConfigs) && isstruct(obj.FactoryConfigs) && ...
            isfield(obj.FactoryConfigs, 'Scenario') && isstruct(obj.FactoryConfigs.Scenario)

        scenarioConfig = obj.FactoryConfigs.Scenario;

        if isfield(scenarioConfig, 'Global') && isstruct(scenarioConfig.Global)

            if isfield(scenarioConfig.Global, 'NumFramesPerScenario') && ...
                    isnumeric(scenarioConfig.Global.NumFramesPerScenario) && ...
                    scenarioConfig.Global.NumFramesPerScenario > 0
                framesPerScenario = scenarioConfig.Global.NumFramesPerScenario;
                obj.logger.debug("Frame count extracted from scenario config: %d frames", framesPerScenario);
            else
                obj.logger.warning("FactoryConfigs.Scenario.Global.NumFramesPerScenario not found or invalid, using default: %d", framesPerScenario);
            end

        else
            obj.logger.warning("FactoryConfigs.Scenario.Global not found, using default frames: %d", framesPerScenario);
        end

    else
        obj.logger.warning("FactoryConfigs.Scenario not available, using default frames: %d", framesPerScenario);
    end

end
