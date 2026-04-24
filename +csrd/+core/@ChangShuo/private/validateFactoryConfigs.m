function validateFactoryConfigs(obj)
    % validateFactoryConfigs - Validate factory configuration structures
    %
    % Ensures FactoryConfigs contains all required factory configs with proper structure.
    % Each factory config should be a struct (implementation details defined in factory files).

    requiredFactories = {'Message', 'Modulation', 'Scenario', 'Transmit', 'Channel', 'Receive'};

    for i = 1:length(requiredFactories)
        name = requiredFactories{i};
        
        if ~isfield(obj.FactoryConfigs, name)
            error('ChangShuo:ConfigurationError', 'FactoryConfigs.%s is required.', name);
        end
        
        config = obj.FactoryConfigs.(name);
        
        if isempty(config) || ~isstruct(config)
            error('ChangShuo:ConfigurationError', 'FactoryConfigs.%s must be a struct.', name);
        end
    end
    
    obj.logger.debug('All factory configurations validated successfully.');
end
