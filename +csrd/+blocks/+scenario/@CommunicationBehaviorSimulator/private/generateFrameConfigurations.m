function [txConfigs, rxConfigs, globalLayout] = generateFrameConfigurations(obj, frameId, entities)
    % generateFrameConfigurations - Generate frame-specific configurations
    %
    % Creates frame-specific configurations by copying the fixed scenario
    % configurations and updating only the temporal/transmission state parameters.
    %
    % The temporal state is updated for each transmitter based on:
    %   - The frame ID
    %   - The transmitter's transmission pattern (Continuous, Burst, Scheduled, Random)
    %
    % Input Arguments:
    %   frameId - Current frame identifier
    %   entities - Entity references for Snapshot updates
    %
    % Output Arguments:
    %   txConfigs - Updated transmitter configurations
    %   rxConfigs - Updated receiver configurations (unchanged)
    %   globalLayout - Updated global layout

    % Start with scenario configurations (cell arrays)
    txConfigs = obj.scenarioTxConfigs;
    rxConfigs = obj.scenarioRxConfigs;
    globalLayout = obj.scenarioGlobalLayout;

    % Update frame-specific information
    globalLayout.FrameId = frameId;

    % Update transmission states for each transmitter
    for i = 1:length(txConfigs)
        if iscell(txConfigs)
            txConfig = txConfigs{i};
        else
            txConfig = txConfigs(i);
        end
        txConfig.FrameId = frameId;

        % Sync real-time position from physical entity
        [entityIdx, entity] = findEntityById(entities, txConfig.EntityID);
        if entityIdx > 0
            txConfig.Physical.Position = entity.Position;
            if isfield(entity, 'Velocity')
                txConfig.Physical.Velocity = entity.Velocity;
            end
        end

        % Update transmission state based on pattern
        txConfig.TransmissionState = calculateTransmissionState(obj, frameId, txConfig);

        % Add pattern-specific parameters to transmission state
        if isfield(txConfig, 'Temporal') && isstruct(txConfig.Temporal)
            temporalType = '';
            if isfield(txConfig.Temporal, 'Type'), temporalType = txConfig.Temporal.Type; end
            if strcmp(temporalType, 'Burst') && isfield(txConfig.Temporal, 'DutyCycle')
                txConfig.TransmissionState.DutyCycle = txConfig.Temporal.DutyCycle;
            elseif strcmp(temporalType, 'Scheduled') && isfield(txConfig.Temporal, 'Schedule')
                txConfig.TransmissionState.Schedule = txConfig.Temporal.Schedule;
            end
        end

        if iscell(txConfigs)
            txConfigs{i} = txConfig;
        else
            txConfigs(i) = txConfig;
        end

        % Update Entity Snapshot with temporal state
        [entityIdx, entity] = findEntityById(entities, txConfig.EntityID);
        if entityIdx > 0
            entities(entityIdx) = updateEntityTemporalSnapshot(obj, entity, frameId, txConfig);
        end
    end

    % Update receiver states
    for i = 1:length(rxConfigs)
        if iscell(rxConfigs)
            rxConfig = rxConfigs{i};
        else
            rxConfig = rxConfigs(i);
        end
        rxConfig.FrameId = frameId;

        % Sync real-time position from physical entity
        [~, rxEntity] = findEntityById(entities, rxConfig.EntityID);
        if ~isempty(rxEntity)
            rxConfig.Physical.Position = rxEntity.Position;
            if isfield(rxEntity, 'Velocity')
                rxConfig.Physical.Velocity = rxEntity.Velocity;
            end
        end

        if iscell(rxConfigs)
            rxConfigs{i} = rxConfig;
        else
            rxConfigs(i) = rxConfig;
        end
    end

    obj.logger.debug('Frame %d: Updated transmission states for %d transmitters', ...
        frameId, length(txConfigs));
    globalLayout.Entities = entities;
end

function [idx, entity] = findEntityById(entities, entityId)
    % findEntityById - Find entity by its ID
    idx = 0;
    entity = [];
    for i = 1:length(entities)
        if strcmp(entities(i).ID, entityId)
            idx = i;
            entity = entities(i);
            return;
        end
    end
end

function entity = updateEntityTemporalSnapshot(obj, entity, frameId, txConfig)
    % updateEntityTemporalSnapshot - Update entity's temporal state in Snapshot
    %
    % This updates the entity's Snapshot with current frame's temporal state.
    % Note: Entity Snapshots are managed by reference (shared with PhysicalEnv).

    if ~isfield(entity, 'Snapshots') || isempty(entity.Snapshots)
        obj.logger.debug('Frame %d: Entity %s has no Snapshots, skipping temporal update', ...
            frameId, entity.ID);
        return;
    end

    % Ensure we have TransmissionState
    if ~isfield(txConfig, 'TransmissionState') || isempty(txConfig.TransmissionState)
        obj.logger.debug('Frame %d: Entity %s has no TransmissionState, skipping', ...
            frameId, entity.ID);
        return;
    end

    % Get or create snapshot for this frame
    snapshot = getOrCreateSnapshot(entity, frameId);

    % Update temporal state with defensive access
    if isfield(txConfig.TransmissionState, 'IsActive')
        snapshot.Temporal.IsTransmitting = txConfig.TransmissionState.IsActive;
    else
        snapshot.Temporal.IsTransmitting = true;
    end

    if isfield(txConfig.TransmissionState, 'CurrentIntervalIdx')
        snapshot.Temporal.CurrentIntervalIdx = txConfig.TransmissionState.CurrentIntervalIdx;
    else
        snapshot.Temporal.CurrentIntervalIdx = 1;
    end

    if isfield(txConfig, 'Temporal') && isfield(txConfig.Temporal, 'Type')
        snapshot.Temporal.PatternType = txConfig.Temporal.Type;
    else
        snapshot.Temporal.PatternType = 'Unknown';
    end

    % Store back - extend Snapshots cell array if needed
    if length(entity.Snapshots) < frameId
        entity.Snapshots{frameId} = [];
    end
    entity.Snapshots{frameId} = snapshot;
end

function snapshot = getOrCreateSnapshot(entity, frameId)
    % getOrCreateSnapshot - Get snapshot for frame or create new one
    
    if length(entity.Snapshots) >= frameId && ~isempty(entity.Snapshots{frameId})
        snapshot = entity.Snapshots{frameId};
    else
        % Copy from previous frame or create new
        if frameId > 1 && length(entity.Snapshots) >= frameId - 1 && ~isempty(entity.Snapshots{frameId - 1})
            snapshot = entity.Snapshots{frameId - 1};
            snapshot.FrameId = frameId;
        else
            snapshot = struct();
            snapshot.FrameId = frameId;
            snapshot.Physical = struct();
            snapshot.Communication = struct();
            snapshot.Temporal = struct();
        end
    end
end
