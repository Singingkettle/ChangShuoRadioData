function environment = updateEnvironmentalConditions(obj, frameId, timeResolution)
    % updateEnvironmentalConditions - Update environmental factors
    %
    % Updates environmental conditions that may affect communication
    % and entity behavior, including weather, obstacles, and terrain.

    environment = obj.currentEnvironment;
    environment.FrameId = frameId;
    environment.Time = frameId * timeResolution;

    % Update weather conditions (simple model)
    if isfield(obj.Config, 'Environment') && isfield(obj.Config.Environment, 'Weather')
        environment.Weather = updateWeatherConditions(obj, environment.Weather, timeResolution);
    end

    % Update dynamic obstacles (if any)
    if isfield(environment, 'DynamicObstacles')
        environment.DynamicObstacles = updateDynamicObstacles(obj, environment.DynamicObstacles, timeResolution);
    end

    obj.currentEnvironment = environment;
end
