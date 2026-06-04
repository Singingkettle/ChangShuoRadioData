function [entities, environment] = planInitialState(obj)
%PLANINITIALSTATE Build and cache the scenario t=0 physical state.

frameId = 1;
if isKey(obj.frameHistory, frameId)
    frameState = obj.frameHistory(frameId);
    entities = frameState.entities;
    environment = frameState.environment;
    return;
end

obj.logger.debug('Planning physical initial state at t=0 (dt=%.9g).', ...
    obj.timeResolution);

entities = initializeEntities(obj, frameId);
environment = updateEnvironmentalConditions(obj, frameId, obj.timeResolution);
entities = applyEnvironmentalConstraints(obj, entities, environment);

frameState = struct();
frameState.entities = entities;
frameState.environment = environment;
frameState.timeResolution = obj.timeResolution;
frameState.timestamp = 0;
frameState.Source = 'ScenarioPlan.InitialState';
obj.frameHistory(frameId) = frameState;
obj.stateHistory{end + 1} = frameState;

obj.logger.debug('Planned physical initial state with %d entities.', ...
    numel(entities));
end
