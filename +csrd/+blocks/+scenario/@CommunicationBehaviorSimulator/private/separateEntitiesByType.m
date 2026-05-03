function [transmitters, receivers] = separateEntitiesByType(obj, entities)
    % separateEntitiesByType - Separate entities by type for processing
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 separateEntitiesByType 实现。
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
