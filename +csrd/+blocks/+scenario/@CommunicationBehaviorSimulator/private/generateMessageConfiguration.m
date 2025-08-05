function messageConfig = generateMessageConfiguration(obj, transmitter, factoryConfig)
    % generateMessageConfiguration - Generate message configuration
    messageConfig = struct();
    messageConfig.Type = factoryConfig.Types{randi(length(factoryConfig.Types))};
    lengthRange = factoryConfig.Length;
    messageConfig.Length = randi([lengthRange.Min, lengthRange.Max]);
end
