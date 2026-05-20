function framesPerScenario = getFramesPerScenarioFromConfig(obj)
    % getFramesPerScenarioFromConfig - Extract frame count from scenario configuration
    % 中文说明：提供 CSRD 生产链路中的 getFramesPerScenarioFromConfig 实现。
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
    %   None. Missing or invalid frame configuration is a contract error.
    %
    % Example:
    %   % Scenario config defines 5 frames per scenario
    %   factoryConfigs.Scenario.Global.NumFramesPerScenario = 5;
    %   framesPerScenario = obj.getFramesPerScenarioFromConfig(); % Returns 5

    if isempty(obj.RuntimePlan) || ~isstruct(obj.RuntimePlan) || ...
            ~isfield(obj.RuntimePlan, 'Frame') || ...
            ~isfield(obj.RuntimePlan.Frame, 'NumFramesPerScenario')
        error('CSRD:RuntimePlan:MissingFrameContract', ...
            'RuntimePlan.Frame.NumFramesPerScenario is required.');
    end
    framesPerScenario = obj.RuntimePlan.Frame.NumFramesPerScenario;
    obj.logger.debug("Frame count extracted from runtime plan: %d frames", ...
        framesPerScenario);

end
