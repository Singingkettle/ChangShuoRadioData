function entities = updateEntityCommunicationState(obj, entities, txConfigs, rxConfigs)
    % updateEntityCommunicationState - Update Entity Snapshots with communication state
    %
    % This function updates the Communication section of Entity Snapshots with
    % the allocated frequency, bandwidth, modulation, and other communication
    % parameters. These are "temporal" properties that are set once during
    % scenario initialization and don't change during the scenario.
    %
    % DESIGN PRINCIPLE:
    %   - Entity is shared between PhysicalEnvSimulator and CommBehaviorSimulator
    %   - PhysicalEnvSimulator manages Physical state
    %   - CommBehaviorSimulator manages Communication and Temporal state
    %   - This function updates the Communication state in Entity Snapshots
    %
    % Input Arguments:
    %   entities - Array of entity structures with Snapshots
    %   txConfigs - Transmitter configurations from scenario initialization
    %   rxConfigs - Receiver configurations from scenario initialization

    obj.logger.debug('Updating Entity Snapshots with communication state...');

    % Update transmitter entities
    for i = 1:length(txConfigs)
        if iscell(txConfigs)
            txConfig = txConfigs{i};
        else
            txConfig = txConfigs(i);
        end

        % Find corresponding entity
        [entityIdx, entity] = findEntityById(entities, txConfig.EntityID);
        if entityIdx == 0
            obj.logger.warning('Entity %s not found for communication state update', txConfig.EntityID);
            continue;
        end

        % Update the Communication state in the latest Snapshot
        entities(entityIdx) = updateTransmitterSnapshot(obj, entity, txConfig);

        freqOffset = 0; bw = 0; modType = 'Unknown';
        if isfield(txConfig, 'Spectrum')
            if isfield(txConfig.Spectrum, 'PlannedFreqOffset'), freqOffset = txConfig.Spectrum.PlannedFreqOffset; end
            if isfield(txConfig.Spectrum, 'PlannedBandwidth'), bw = txConfig.Spectrum.PlannedBandwidth; end
        end
        if isfield(txConfig, 'Modulation') && isfield(txConfig.Modulation, 'Type'), modType = txConfig.Modulation.Type; end
        obj.logger.debug('Updated Entity %s Communication state: Freq=%.1f MHz, BW=%.1f kHz, Mod=%s', ...
            txConfig.EntityID, freqOffset / 1e6, bw / 1e3, modType);
    end

    % Update receiver entities
    for i = 1:length(rxConfigs)
        if iscell(rxConfigs)
            rxConfig = rxConfigs{i};
        else
            rxConfig = rxConfigs(i);
        end

        % Find corresponding entity
        [entityIdx, entity] = findEntityById(entities, rxConfig.EntityID);
        if entityIdx == 0
            obj.logger.warning('Entity %s not found for communication state update', rxConfig.EntityID);
            continue;
        end

        % Update the Communication state in the latest Snapshot
        entities(entityIdx) = updateReceiverSnapshot(entity, rxConfig);

        rxSR = 0;
        if isfield(rxConfig, 'Observation') && isfield(rxConfig.Observation, 'SampleRate'), rxSR = rxConfig.Observation.SampleRate; end
        obj.logger.debug('Updated Entity %s Communication state: SampleRate=%.1f MHz', ...
            rxConfig.EntityID, rxSR / 1e6);
    end

    obj.logger.debug('Entity Snapshot communication state update completed');
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

function entity = updateTransmitterSnapshot(obj, entity, txConfig)
    % updateTransmitterSnapshot - Update transmitter entity's Communication snapshot
    
    if ~isfield(entity, 'Snapshots') || isempty(entity.Snapshots)
        obj.logger.warning('Entity %s has no Snapshots, skipping communication update', entity.ID);
        return;
    end

    % Find the latest non-empty snapshot
    latestIdx = findLatestSnapshotIndex(entity.Snapshots);
    if latestIdx == 0
        obj.logger.warning('Entity %s has no valid Snapshots', entity.ID);
        return;
    end

    snapshot = entity.Snapshots{latestIdx};

    % Update Communication state (temporal properties - set once)
    if isfield(txConfig, 'Spectrum')
        if isfield(txConfig.Spectrum, 'PlannedFreqOffset'), snapshot.Communication.Frequency = txConfig.Spectrum.PlannedFreqOffset; end
        if isfield(txConfig.Spectrum, 'PlannedBandwidth'), snapshot.Communication.Bandwidth = txConfig.Spectrum.PlannedBandwidth; end
    end
    if isfield(txConfig, 'Modulation')
        if isfield(txConfig.Modulation, 'Type'), snapshot.Communication.ModulationType = txConfig.Modulation.Type; end
        if isfield(txConfig.Modulation, 'Order'), snapshot.Communication.ModulationOrder = txConfig.Modulation.Order; end
    end
    if isfield(txConfig, 'Hardware')
        if isfield(txConfig.Hardware, 'Power'), snapshot.Communication.Power = txConfig.Hardware.Power; end
        if isfield(txConfig.Hardware, 'NumAntennas'), snapshot.Communication.NumAntennas = txConfig.Hardware.NumAntennas; end
    end
    snapshot.Communication.Initialized = true;

    % Store Temporal info (also temporal - set once)
    if isfield(txConfig, 'Temporal')
        if isfield(txConfig.Temporal, 'Type'), snapshot.Temporal.PatternType = txConfig.Temporal.Type; end
        if isfield(txConfig.Temporal, 'Intervals'), snapshot.Temporal.Intervals = txConfig.Temporal.Intervals; end
    end

    % Store back
    entity.Snapshots{latestIdx} = snapshot;
end

function entity = updateReceiverSnapshot(entity, rxConfig)
    % updateReceiverSnapshot - Update receiver entity's Communication snapshot
    
    if ~isfield(entity, 'Snapshots') || isempty(entity.Snapshots)
        return;
    end

    % Find the latest non-empty snapshot
    latestIdx = findLatestSnapshotIndex(entity.Snapshots);
    if latestIdx == 0
        return;
    end

    snapshot = entity.Snapshots{latestIdx};

    % Update Communication state for receiver
    if isfield(rxConfig, 'Observation')
        if isfield(rxConfig.Observation, 'SampleRate'), snapshot.Communication.SampleRate = rxConfig.Observation.SampleRate; end
        if isfield(rxConfig.Observation, 'ObservableRange'), snapshot.Communication.ObservableRange = rxConfig.Observation.ObservableRange; end
        if isfield(rxConfig.Observation, 'RealCarrierFrequency'), snapshot.Communication.RealCarrierFrequency = rxConfig.Observation.RealCarrierFrequency; end
        if isfield(rxConfig.Observation, 'CenterFrequency'), snapshot.Communication.CenterFrequency = rxConfig.Observation.CenterFrequency; end
    end
    if isfield(rxConfig, 'Hardware') && isfield(rxConfig.Hardware, 'NumAntennas')
        snapshot.Communication.NumAntennas = rxConfig.Hardware.NumAntennas;
    end
    snapshot.Communication.Initialized = true;

    % Store back
    entity.Snapshots{latestIdx} = snapshot;
end

function idx = findLatestSnapshotIndex(snapshots)
    % findLatestSnapshotIndex - Find index of latest non-empty snapshot
    idx = 0;
    for i = length(snapshots):-1:1
        if ~isempty(snapshots{i})
            idx = i;
            return;
        end
    end
end
