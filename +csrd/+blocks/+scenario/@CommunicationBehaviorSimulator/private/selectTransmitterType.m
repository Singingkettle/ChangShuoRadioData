function transmitterType = selectTransmitterType(obj, transmitter, factoryConfig)
    % selectTransmitterType - Select appropriate transmitter type
    excludeFields = {'Parameters', 'Behavior', 'LogDetails', 'Description'};
    allFields = fieldnames(factoryConfig);
    availableTypes = setdiff(allFields, excludeFields);

    if isempty(availableTypes)
        obj.logger.warning('No transmitter types found in factory config, defaulting to Simulation');
        transmitterType = 'Simulation';
    else
        transmitterType = availableTypes{randi(length(availableTypes))};
    end

end
