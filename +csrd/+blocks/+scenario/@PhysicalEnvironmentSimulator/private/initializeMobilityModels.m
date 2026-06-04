function initializeMobilityModels(obj)
    % initializeMobilityModels - Initialize available mobility models
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    % Note: These classes need to be implemented separately

    obj.mobilityModels('ConstantVelocity') = [];
    obj.mobilityModels('RandomWalk') = []; % Unsupported by midpoint evaluator.
    obj.mobilityModels('Waypoint') = []; % Unsupported by midpoint evaluator.
    obj.mobilityModels('Stationary') = [];

    obj.logger.debug('Initialized %d mobility models', obj.mobilityModels.Count);
end
