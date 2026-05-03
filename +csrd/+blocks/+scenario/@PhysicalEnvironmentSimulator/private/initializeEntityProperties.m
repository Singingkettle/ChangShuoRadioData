function entityProperties = initializeEntityProperties(obj, entityType)
    % initializeEntityProperties - Initialize physical properties for entity type
    % 中文说明：提供 CSRD 生产链路中的 initializeEntityProperties 实现。
    %
    % Input Arguments:
    %   entityType - Type of entity to initialize properties for
    %
    % Output Arguments:
    %   entityProperties - Structure containing entity-specific properties

    entityProperties = struct();

    switch entityType
        case 'Transmitter'
            entityProperties.Type = 'Mobile';
            entityProperties.PowerClass = randi([1, 4]); % Power class 1-4
            entityProperties.AntennaHeight = randomInRange(obj, 1.5, 3.0); % meters
            entityProperties.Mass = randomInRange(obj, 0.5, 2.0); % kg
        case 'Receiver'
            entityProperties.Type = 'Monitoring';
            entityProperties.SensitivityClass = randi([1, 3]);
            entityProperties.AntennaHeight = randomInRange(obj, 10, 50); % meters
            entityProperties.Mass = randomInRange(obj, 10, 100); % kg
    end

end
