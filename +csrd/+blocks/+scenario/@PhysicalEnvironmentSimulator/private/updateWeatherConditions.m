function weather = updateWeatherConditions(obj, currentWeather, deltaTime)
    % updateWeatherConditions - Configurable weather evolution model
    %
    % Input Arguments:
    %   obj - PhysicalEnvironmentSimulator object with configuration
    %   currentWeather - Current weather state
    %   deltaTime - Time elapsed since last update
    %
    % Output Arguments:
    %   weather - Updated weather conditions

    weather = currentWeather;

    % Enable=false must behave exactly like an absent Weather block. The
    % caller (updateEnvironmentalConditions) already gates on it; this
    % early return keeps the contract even for a direct call, and matters
    % beyond semantics -- the evolution below consumes randn() draws, so a
    % disabled config that still ran here would shift the global RNG
    % stream relative to a config with no Weather block at all.
    if isfield(obj.Config, 'Environment') && ...
            isfield(obj.Config.Environment, 'Weather') && ...
            isequal(getFieldOrDefault(obj.Config.Environment.Weather, ...
                'Enable', true), false)
        return;
    end

    % Get weather evolution parameters from configuration
    if isfield(obj.Config, 'Environment') && ...
            isfield(obj.Config.Environment, 'Weather') && ...
            isfield(obj.Config.Environment.Weather, 'Evolution')

        evolution = obj.Config.Environment.Weather.Evolution;

        % Use configured variations or defaults
        tempVar = getFieldOrDefault(evolution, 'TemperatureVariation', 0.1);
        humidityVar = getFieldOrDefault(evolution, 'HumidityVariation', 0.5);
        pressureVar = getFieldOrDefault(evolution, 'PressureVariation', 0.1);
        windSpeedVar = getFieldOrDefault(evolution, 'WindSpeedVariation', 0.2);
        windDirVar = getFieldOrDefault(evolution, 'WindDirectionVariation', 5);
    else
        % Default variations
        tempVar = 0.1;
        humidityVar = 0.5;
        pressureVar = 0.1;
        windSpeedVar = 0.2;
        windDirVar = 5;
    end

    % Get weather constraints from configuration
    if isfield(obj.Config, 'Environment') && ...
            isfield(obj.Config.Environment, 'Weather') && ...
            isfield(obj.Config.Environment.Weather, 'Constraints')

        constraints = obj.Config.Environment.Weather.Constraints;

        % Use configured constraints or defaults
        tempRange = getFieldOrDefault(constraints, 'TemperatureRange', [-40, 60]);
        humidityRange = getFieldOrDefault(constraints, 'HumidityRange', [0, 100]);
        pressureRange = getFieldOrDefault(constraints, 'PressureRange', [900, 1100]);
        windSpeedRange = getFieldOrDefault(constraints, 'WindSpeedRange', [0, 50]);
    else
        % Default constraints
        tempRange = [-40, 60];
        humidityRange = [0, 100];
        pressureRange = [900, 1100];
        windSpeedRange = [0, 50];
    end

    % Apply random variations with configured parameters
    weather.Temperature = weather.Temperature + randn() * tempVar;
    weather.Humidity = weather.Humidity + randn() * humidityVar;
    weather.Pressure = weather.Pressure + randn() * pressureVar;

    % Add wind speed and direction updates if they exist
    if isfield(weather, 'WindSpeed')
        weather.WindSpeed = weather.WindSpeed + randn() * windSpeedVar;
    end

    if isfield(weather, 'WindDirection')
        weather.WindDirection = weather.WindDirection + randn() * windDirVar;
    end

    % Apply constraints
    weather.Temperature = max(tempRange(1), min(tempRange(2), weather.Temperature));
    weather.Humidity = max(humidityRange(1), min(humidityRange(2), weather.Humidity));
    weather.Pressure = max(pressureRange(1), min(pressureRange(2), weather.Pressure));

    if isfield(weather, 'WindSpeed')
        weather.WindSpeed = max(windSpeedRange(1), min(windSpeedRange(2), weather.WindSpeed));
    end

    if isfield(weather, 'WindDirection')
        % Keep wind direction in 0-360 degree range
        weather.WindDirection = mod(weather.WindDirection, 360);
    end

end

function value = getFieldOrDefault(structure, fieldName, defaultValue)
    % Helper function to get field value or return default
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    if isfield(structure, fieldName)
        value = structure.(fieldName);
    else
        value = defaultValue;
    end

end
