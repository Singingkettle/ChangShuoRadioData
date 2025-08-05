function validateFactoryConfigs(obj)
    % validateFactoryConfigs - Validate factory configuration structures
    %
    % This method validates that all factory configurations conform to the
    % required structure with proper handle and config fields. It ensures
    % that each factory configuration is properly structured for instantiation.
    %
    % Required Factory Structure:
    %   - .handle (char/string): Factory class name for instantiation
    %   - .Config (struct): Factory-specific configuration parameters
    %
    % Validated Factories:
    %   - Message: Message generation factory
    %   - Modulate: Modulation processing factory
    %   - Scenario: Scenario instantiation factory
    %   - Transmit: Transmitter RF front-end factory
    %   - Channel: Channel modeling factory
    %   - Receive: Receiver processing factory

    factories = {'Message', 'Modulate', 'Scenario', 'Transmit', 'Channel', 'Receive'};

    for i = 1:length(factories)
        factoryName = factories{i};

        if ~isprop(obj, factoryName) || isempty(obj.(factoryName)) || ...
                ~isstruct(obj.(factoryName)) || ~isfield(obj.(factoryName), 'handle') || ...
                ~isfield(obj.(factoryName), 'Config') % Config field must exist
            error('ChangShuo:ConfigurationError', ...
                'Property ''%s'' must be a struct with ''handle'' and ''Config'' fields.', factoryName);
        end

        if ~ischar(obj.(factoryName).handle) && ~isstring(obj.(factoryName).handle)
            error('ChangShuo:ConfigurationError', ...
                'Property ''%s.handle'' must be a character string (e.g., ''csrd.factories.MessageFactory'').', factoryName);
        end

        % Config must now be a struct
        if ~isstruct(obj.(factoryName).Config)
            error('ChangShuo:ConfigurationError', ...
                'Property ''%s.Config'' must now be a configuration struct.', factoryName);
        end

    end

end
