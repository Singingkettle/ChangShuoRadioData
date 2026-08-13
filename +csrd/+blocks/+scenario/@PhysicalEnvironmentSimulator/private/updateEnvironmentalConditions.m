function environment = updateEnvironmentalConditions(obj, frameId, timeResolution)
    % updateEnvironmentalConditions - Update environmental factors
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    % Updates environmental conditions that may affect communication
    % and entity behavior, including weather, obstacles, and terrain.

    environment = obj.currentEnvironment;
    environment.FrameId = frameId;
    environment.Time = (frameId - 1) * timeResolution;

    % Update weather conditions (simple model). Enable=false must behave
    % exactly like an absent Weather block: the flag was documented and set
    % by four unit tests, but nothing read it -- the presence of the struct
    % alone kept the evolution running.
    if isfield(obj.Config, 'Environment') && ...
            isfield(obj.Config.Environment, 'Weather') && ...
            localWeatherEnabled(obj.Config.Environment.Weather)
        environment.Weather = updateWeatherConditions(obj, environment.Weather, timeResolution);
    end

    % Update dynamic obstacles (if any)
    if isfield(environment, 'DynamicObstacles')
        environment.DynamicObstacles = updateDynamicObstacles(obj, environment.DynamicObstacles, timeResolution);
    end

    obj.currentEnvironment = environment;
end

function enabled = localWeatherEnabled(weatherConfig)
    % localWeatherEnabled - honor Weather.Enable, defaulting to true.
    % Inputs: weatherConfig - the Environment.Weather config struct.
    % Outputs: enabled - false only when Enable is explicitly false.
    enabled = true;
    if isstruct(weatherConfig) && isfield(weatherConfig, 'Enable') && ...
            ~isempty(weatherConfig.Enable)
        enabled = logical(weatherConfig.Enable);
    end
end
