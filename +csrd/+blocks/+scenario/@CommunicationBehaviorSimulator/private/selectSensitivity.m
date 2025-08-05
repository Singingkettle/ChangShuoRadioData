function sensitivity = selectSensitivity(obj, receiver, factoryConfig)
    % selectSensitivity - Select receiver sensitivity
    if isfield(factoryConfig.Parameters, 'SensitivityRange')
        range = factoryConfig.Parameters.SensitivityRange;
        sensitivity = randomInRange(obj, range.Min, range.Max);
    else
        sensitivity = -90; % Default -90 dBm
    end

end
