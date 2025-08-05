function entities = initializeEntities(obj, frameId)
    % initializeEntities - Create initial entity positions and states
    %
    % Generates initial entity configurations including transmitters and
    % receivers with randomized positions, velocities, and properties
    % within the configured geographical boundaries.
    %
    % Input Arguments:
    %   frameId - Current frame identifier
    %
    % Output Arguments:
    %   entities - Array of initialized entity structures

    entities = [];

    % Determine entity counts based on configuration (Min/Max struct format)
    if isfield(obj.Config.Entities.Transmitters, 'Count')
        txCount = obj.Config.Entities.Transmitters.Count;

        if isstruct(txCount) && isfield(txCount, 'Min') && isfield(txCount, 'Max')
            numTx = randi([txCount.Min, txCount.Max]);
        else
            obj.logger.warning('Invalid transmitter count configuration, using default: 2');
            numTx = 2;
        end

    else
        obj.logger.warning('Transmitter count not found in config, using default: 2');
        numTx = 2;
    end

    if isfield(obj.Config.Entities.Receivers, 'Count')
        rxCount = obj.Config.Entities.Receivers.Count;

        if isstruct(rxCount) && isfield(rxCount, 'Min') && isfield(rxCount, 'Max')
            numRx = randi([rxCount.Min, rxCount.Max]);
        else
            obj.logger.warning('Invalid receiver count configuration, using default: 1');
            numRx = 1;
        end

    else
        obj.logger.warning('Receiver count not found in config, using default: 1');
        numRx = 1;
    end

    obj.logger.debug('Frame %d: Initializing %d transmitters and %d receivers', frameId, numTx, numRx);

    % Initialize transmitters
    for i = 1:numTx
        txEntity = createEntity(obj, 'Transmitter', sprintf('Tx%d', i), frameId);
        entities = [entities, txEntity];
        obj.entityRegistry(txEntity.ID) = txEntity;
    end

    % Initialize receivers
    for i = 1:numRx
        rxEntity = createEntity(obj, 'Receiver', sprintf('Rx%d', i), frameId);
        entities = [entities, rxEntity];
        obj.entityRegistry(rxEntity.ID) = rxEntity;
    end

    obj.logger.debug('Frame %d: Entity initialization completed', frameId);
end
