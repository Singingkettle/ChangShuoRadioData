function framesPerScenario = getFramesPerScenarioFromConfig(obj)
    % getFramesPerScenarioFromConfig - Extract frame count from scenario configuration
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    %
    % This method parses the scenario configuration to determine how many
    % frames should be generated for the current scenario instance. It
    % demonstrates the clean architecture where frame count is determined
    % by scenario configuration rather than external parameters.
    %
    % Configuration Path:
    %   ScenarioPlan.Frame.NumFramesPerScenario
    %
    % Output:
    %   framesPerScenario - Number of frames to generate for this scenario
    %
    % Default Behavior:
    %   None. Missing or invalid frame configuration is a contract error.
    %
    if isempty(obj.ScenarioPlan) || ~isstruct(obj.ScenarioPlan) || ...
            ~isfield(obj.ScenarioPlan, 'Frame') || ...
            ~isfield(obj.ScenarioPlan.Frame, 'NumFramesPerScenario')
        error('CSRD:ScenarioPlan:MissingFrameContract', ...
            'ScenarioPlan.Frame.NumFramesPerScenario is required.');
    end
    framesPerScenario = obj.ScenarioPlan.Frame.NumFramesPerScenario;
    obj.logger.debug("Frame count extracted from scenario plan: %d frames", ...
        framesPerScenario);

end
