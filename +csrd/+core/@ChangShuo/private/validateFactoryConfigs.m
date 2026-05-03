function validateFactoryConfigs(obj)
    % validateFactoryConfigs - Validate factory configuration structures
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 validateFactoryConfigs 实现。
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
