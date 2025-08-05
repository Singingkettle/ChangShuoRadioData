function [transmitters, receivers] = separateEntitiesByType(obj, entities)
    % separateEntitiesByType - Separate entities by type for processing
    transmitters = [];
    receivers = [];

    for i = 1:length(entities)
        entity = entities(i);

        if strcmp(entity.Type, 'Transmitter')
            transmitters = [transmitters, entity];
        elseif strcmp(entity.Type, 'Receiver')
            receivers = [receivers, entity];
        end

    end

end
