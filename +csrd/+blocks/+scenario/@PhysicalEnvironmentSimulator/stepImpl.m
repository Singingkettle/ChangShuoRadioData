function [entities, environment] = stepImpl(obj, frameId)
    % stepImpl - Update physical environment state for current frame
    %
    % Updates the physical environment state including entity positions,
    % mobility states, and environmental conditions based on the internal
    % time resolution and stored historical states.
    %
    % Input Arguments:
    %   frameId - Current frame identifier
    %
    % Output Arguments:
    %   entities - Updated entity states and positions
    %   environment - Current environmental state and conditions

    obj.logger.debug('Frame %d: Updating physical environment (dt=%.3f)', frameId, obj.timeResolution);

    % Get previous state from internal history
    previousState = getPreviousState(obj, frameId);

    % Initialize or update entities based on frame context
    if frameId == 1 || isempty(previousState)
        % First frame or reset: initialize entities
        entities = initializeEntities(obj, frameId);
        obj.logger.debug('Frame %d: Initialized %d entities', frameId, length(entities));
    else
        % Update entity states based on previous frame
        entities = updateEntityStates(obj, frameId, obj.timeResolution, previousState);
        obj.logger.debug('Frame %d: Updated %d entities with temporal evolution', frameId, length(entities));
    end

    % Update environmental conditions
    environment = updateEnvironmentalConditions(obj, frameId, obj.timeResolution);

    % Apply physical constraints and collision detection
    entities = applyEnvironmentalConstraints(obj, entities, environment);

    % Store current frame state for next iteration and history
    frameState = struct();
    frameState.entities = entities;
    frameState.environment = environment;
    frameState.timeResolution = obj.timeResolution;
    frameState.timestamp = frameId * obj.timeResolution;
    obj.frameHistory(frameId) = frameState;

    % Store in state history for scenario replay functionality
    obj.stateHistory{end + 1} = frameState;

    obj.logger.debug('Frame %d: Physical environment update completed', frameId);
end
