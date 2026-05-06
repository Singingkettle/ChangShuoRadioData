function [txConfigs, rxConfigs, globalLayout] = stepImpl(obj, frameId, entities)
    % stepImpl - Generate frame-specific communication states
    % 中文说明：提供 CSRD 生产链路中的 stepImpl 实现。
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

    % Phase 1 / A4 fail-fast: if there are NO physical entities at all
    % we cannot safely fabricate a communication behaviour. Raise a
    % whitelisted scenario-skip exception so SimulationRunner skips this
    % scenario instead of silently producing an empty frame.
    if isempty(entities)
        error('CSRD:Scenario:EmptyEntities', ...
            ['Frame %d: No physical entities provided to ' ...
             'CommunicationBehaviorSimulator.stepImpl. The scenario ' ...
             'must be skipped rather than fabricated.'], frameId);
    end

    workingEntities = synchronizeScenarioEntities(obj.scenarioEntities, entities, frameId);
    if isempty(workingEntities)
        % Phase 1 / A4: previously we silently fell back to `entities`
        % whenever synchronisation returned empty, masking real entity
        % drift between the physical scenario layer and the cached
        % scenarioEntities. The new behaviour distinguishes the two
        % failure modes and raises a whitelisted scenario-skip error
        % that SimulationRunner will translate into a "scenario
        % skipped" record via isScenarioSkipException.
        if ~isempty(obj.scenarioEntities)
            error('CSRD:Scenario:EntityDriftDetected', ...
                ['Frame %d: synchronizeScenarioEntities produced an ' ...
                 'empty merge between %d cached scenarioEntities and ' ...
                 '%d incoming entities. This indicates the physical ' ...
                 'scenario layer changed entity IDs mid-scenario; ' ...
                 'skipping rather than masking the drift.'], ...
                frameId, numel(obj.scenarioEntities), numel(entities));
        else
            error('CSRD:Scenario:EmptyEntities', ...
                ['Frame %d: synchronizeScenarioEntities produced an ' ...
                 'empty result on the first frame; cannot proceed.'], frameId);
        end
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
    % synchronizeScenarioEntities - Production declaration in CSRD.
    % 中文说明：synchronizeScenarioEntities 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
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
            if isfield(mergedEntity, 'PositionUnit')
                mergedEntity.Snapshots{frameId}.Physical.PositionUnit = mergedEntity.PositionUnit;
            else
                mergedEntity.Snapshots{frameId}.Physical.PositionUnit = 'meters';
            end
            if isfield(mergedEntity, 'GeoPositionDeg')
                mergedEntity.Snapshots{frameId}.Physical.GeoPositionDeg = mergedEntity.GeoPositionDeg;
            else
                mergedEntity.Snapshots{frameId}.Physical.GeoPositionDeg = [];
            end
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
