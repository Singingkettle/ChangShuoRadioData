function initializeEnvironment(obj)
    % initializeEnvironment - Initialize environmental factors and conditions
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 initializeEnvironment 实现。
    %
    % Sets up the basic environmental structure including weather conditions
    % and obstacle initialization for the simulation.

    obj.currentEnvironment = struct();
    obj.currentEnvironment.Map = obj.mapData;

    % Initialize weather conditions from configuration
    obj.currentEnvironment.Weather = struct();

    % Get initial weather conditions from configuration or use defaults
    if isfield(obj.Config, 'Environment') && ...
            isfield(obj.Config.Environment, 'Weather') && ...
            isfield(obj.Config.Environment.Weather, 'InitialConditions')

        initial = obj.Config.Environment.Weather.InitialConditions;
        obj.currentEnvironment.Weather.Temperature = getFieldOrDefault(initial, 'Temperature', 20); % Celsius
        obj.currentEnvironment.Weather.Humidity = getFieldOrDefault(initial, 'Humidity', 50); % Percentage
        obj.currentEnvironment.Weather.Pressure = getFieldOrDefault(initial, 'Pressure', 1013); % hPa
        obj.currentEnvironment.Weather.WindSpeed = getFieldOrDefault(initial, 'WindSpeed', 0); % m/s
        obj.currentEnvironment.Weather.WindDirection = getFieldOrDefault(initial, 'WindDirection', 0); % degrees
    else
        % Default weather conditions
        obj.currentEnvironment.Weather.Temperature = 20; % Celsius
        obj.currentEnvironment.Weather.Humidity = 50; % Percentage
        obj.currentEnvironment.Weather.Pressure = 1013; % hPa
        obj.currentEnvironment.Weather.WindSpeed = 0; % m/s
        obj.currentEnvironment.Weather.WindDirection = 0; % degrees
    end

    % Initialize obstacles
    obj.currentEnvironment.StaticObstacles = generateStaticObstacles(obj);
    obj.currentEnvironment.DynamicObstacles = [];
end

function value = getFieldOrDefault(structure, fieldName, defaultValue)
    % Helper function to get field value or return default
    % 中文说明：getFieldOrDefault 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    if isfield(structure, fieldName)
        value = structure.(fieldName);
    else
        value = defaultValue;
    end

end
