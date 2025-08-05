function receiverType = selectReceiverType(obj, receiver, factoryConfig)
    % selectReceiverType - Select appropriate receiver type from top-level receiver types
    % Only select from receiver types (e.g., 'Simulation'), not receiver models
    if isfield(factoryConfig, 'Types') && ~isempty(factoryConfig.Types)
        availableTypes = factoryConfig.Types;
        receiverType = availableTypes{randi(length(availableTypes))};
    else
        % Fallback: look for receiver types directly in factoryConfig
        excludeFields = {'Parameters', 'LogDetails', 'Description', 'Types'};
        allFields = fieldnames(factoryConfig);
        availableTypes = setdiff(allFields, excludeFields);

        if isempty(availableTypes)
            obj.logger.warning('No receiver types found in factory config, defaulting to Simulation');
            receiverType = 'Simulation';
        else
            receiverType = availableTypes{randi(length(availableTypes))};
        end

    end

end
