function [txConfigs, rxConfigs, globalLayout] = stepImpl(obj, frameId, entities)
    % stepImpl - Generate frame-specific communication states
    %
    % TWO-PHASE ARCHITECTURE:
    %   Phase 1 (first frame only):
    %     - Initialize scenario-level configurations (frequency, bandwidth allocation)
    %     - These remain fixed throughout the scenario (temporal properties)
    %
    %   Phase 2 (every frame):
    %     - Update frame-specific temporal behaviors (transmission timing, on/off states)
    %     - Update Entity Snapshots with current temporal state
    %
    % DESIGN PRINCIPLE:
    %   - Uses obj.Config (set during construction) instead of passed parameter
    %   - All configuration comes from scenario_factory.m via obj.Config
    %   - No need to pass config every frame since it's static
    %
    % Input Arguments:
    %   frameId - Current frame identifier
    %   entities - Entity references from PhysicalEnvironmentSimulator (shared)
    %
    % Output Arguments:
    %   txConfigs - Transmitter configurations for current frame
    %   rxConfigs - Receiver configurations for current frame
    %   globalLayout - Global communication layout

    obj.logger.debug('Frame %d: Processing communication behavior for %d entities', ...
        frameId, length(entities));

    workingEntities = synchronizeScenarioEntities(obj.scenarioEntities, entities, frameId);
    if isempty(workingEntities)
        workingEntities = entities;
    end

    % Phase 1: Initialize scenario-level configurations on first frame
    if ~obj.scenarioInitialized
        obj.logger.debug('Frame %d: Initializing scenario-level communication configurations', frameId);
        workingEntities = initializeScenarioConfigurations(obj, workingEntities);
        obj.scenarioInitialized = true;
    end
    obj.scenarioEntities = workingEntities;

    % Phase 2: Generate frame-specific configurations (temporal state updates)
    [txConfigs, rxConfigs, globalLayout] = generateFrameConfigurations(obj, frameId, obj.scenarioEntities);
    if isfield(globalLayout, 'Entities') && ~isempty(globalLayout.Entities)
        obj.scenarioEntities = globalLayout.Entities;
    end

    % Store frame state for continuity
    frameState = struct();
    frameState.txConfigs = txConfigs;
    frameState.rxConfigs = rxConfigs;
    frameState.globalLayout = globalLayout;
    frameState.frameId = frameId;
    obj.allocationHistory(frameId) = frameState;

    obj.logger.debug('Frame %d: Communication behavior processing completed', frameId);
end

function mergedEntities = synchronizeScenarioEntities(previousEntities, currentEntities, frameId)
    if isempty(previousEntities)
        mergedEntities = currentEntities;
        return;
    end

    mergedEntities = currentEntities;
    for idx = 1:length(currentEntities)
        matchIdx = find(arrayfun(@(e) strcmp(e.ID, currentEntities(idx).ID), previousEntities), 1, 'first');
        if isempty(matchIdx)
            continue;
        end

        previousEntity = previousEntities(matchIdx);
        mergedEntity = currentEntities(idx);

        if isfield(previousEntity, 'Snapshots') && iscell(previousEntity.Snapshots)
            mergedEntity.Snapshots = previousEntity.Snapshots;
        end

        if ~isfield(mergedEntity, 'Snapshots') || ~iscell(mergedEntity.Snapshots)
            mergedEntity.Snapshots = cell(1, max(100, frameId));
        end

        if numel(mergedEntity.Snapshots) < frameId
            mergedEntity.Snapshots{frameId} = [];
        end

        if isempty(mergedEntity.Snapshots{frameId})
            if frameId > 1 && numel(mergedEntity.Snapshots) >= frameId - 1 && ~isempty(mergedEntity.Snapshots{frameId - 1})
                mergedEntity.Snapshots{frameId} = mergedEntity.Snapshots{frameId - 1};
            else
                mergedEntity.Snapshots{frameId} = struct('Physical', struct(), 'Communication', struct(), 'Temporal', struct());
            end
        end

        if isfield(currentEntities(idx), 'Snapshots') && iscell(currentEntities(idx).Snapshots) && ...
                numel(currentEntities(idx).Snapshots) >= frameId && ~isempty(currentEntities(idx).Snapshots{frameId}) && ...
                isfield(currentEntities(idx).Snapshots{frameId}, 'Physical')
            mergedEntity.Snapshots{frameId}.Physical = currentEntities(idx).Snapshots{frameId}.Physical;
        else
            mergedEntity.Snapshots{frameId}.Physical.Position = mergedEntity.Position;
            mergedEntity.Snapshots{frameId}.Physical.Velocity = mergedEntity.Velocity;
            mergedEntity.Snapshots{frameId}.Physical.Orientation = mergedEntity.Orientation;
            mergedEntity.Snapshots{frameId}.Physical.AngularVelocity = mergedEntity.AngularVelocity;
        end

        mergedEntity.Snapshots{frameId}.FrameId = frameId;
        if isfield(currentEntities(idx), 'LastUpdateTime')
            mergedEntity.Snapshots{frameId}.Timestamp = currentEntities(idx).LastUpdateTime;
        end

        mergedEntities(idx) = mergedEntity;
    end
end
