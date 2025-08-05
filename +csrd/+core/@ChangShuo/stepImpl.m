function [ScenarioData, ScenarioAnnotation] = stepImpl(obj, scenarioId)
    % stepImpl - Execute simulation for an entire scenario
    %
    % This method handles the complete execution of a scenario by extracting
    % the frame count from scenario configuration and managing the frame-level
    % loop internally. It calls step() methods of already instantiated factories
    % (from setupImpl). It demonstrates the clean separation of responsibilities
    % where ChangShuo handles frame generation and SimulationRunner handles
    % scenario management.
    %
    % Syntax:
    %   [scenarioData, scenarioAnnotation] = stepImpl(obj, scenarioId)
    %
    % Inputs:
    %   scenarioId - Scenario identifier
    %
    % Outputs:
    %   ScenarioData - Cell array of generated signal data for all frames
    %   ScenarioAnnotation - Cell array of metadata and annotations for all frames

    % Extract frame count from scenario configuration
    framesPerScenario = getFramesPerScenarioFromConfig(obj);

    obj.logger.debug("Scenario %d: Starting simulation for %d frames (from scenario config).", ...
        scenarioId, framesPerScenario);

    % Initialize output for entire scenario
    ScenarioData = cell(1, framesPerScenario);
    ScenarioAnnotation = cell(1, framesPerScenario);

    % Loop through frames in this scenario
    for frameInScenario = 1:framesPerScenario
        % Calculate global frame ID
        FrameId = (scenarioId - 1) * framesPerScenario + frameInScenario;

        obj.logger.debug("Scenario %d, Frame %d/%d: Processing frame.", ...
            scenarioId, frameInScenario, framesPerScenario);

        % Generate single frame data
        [FrameData, FrameAnnotation] = generateSingleFrame(obj, frameInScenario);

        % Store frame data in scenario arrays
        ScenarioData{frameInScenario} = FrameData;
        ScenarioAnnotation{frameInScenario} = FrameAnnotation;

        obj.logger.debug("Scenario %d, Frame %d/%d: Frame processing completed.", ...
            scenarioId, frameInScenario, framesPerScenario);
    end

    obj.logger.debug("Scenario %d: All %d frames completed.", scenarioId, framesPerScenario);
end
