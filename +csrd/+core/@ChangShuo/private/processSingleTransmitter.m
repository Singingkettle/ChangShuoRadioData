function [signalSegmentsPerTx, TxInfo] = processSingleTransmitter(obj, FrameId, txIdx)
    % processSingleTransmitter - Process a single transmitter configuration
    %
    % This method handles the complete processing of one transmitter including
    % configuration validation, message generation, and modulation for all segments.
    %
    % Inputs:
    %   FrameId - Global frame identifier
    %   txIdx - Transmitter index in the scenario
    %
    % Outputs:
    %   signalSegmentsPerTx - Cell array of signal segments for this transmitter
    %   TxInfo - Transmitter information structure

    % Validate transmitter scenario configuration
    if txIdx > length(obj.ScenarioConfig.Transmitters)
        obj.logger.warning('Frame %d, Tx Index %d: Scenario definition issue.', FrameId, txIdx);
        signalSegmentsPerTx = {};
        TxInfo = struct('Status', 'Error_MissingTxScenarioID');
        return;
    end

    % Access transmitter config (stored as cell array)
    currentTxScenario = obj.ScenarioConfig.Transmitters{txIdx};
    
    if ~isfield(currentTxScenario, 'EntityID')
        obj.logger.warning('Frame %d, Tx Index %d: EntityID missing in scenario.', FrameId, txIdx);
        signalSegmentsPerTx = {};
        TxInfo = struct('Status', 'Error_MissingTxScenarioID');
        return;
    end

    currentTxId = currentTxScenario.EntityID;

    obj.logger.debug("Frame %d, TxID %s: Configuring transmitter.", FrameId, string(currentTxId));

    % Check if transmitter is active in this frame
    if isfield(currentTxScenario, 'TransmissionState') && ...
            isfield(currentTxScenario.TransmissionState, 'IsActive') && ...
            ~currentTxScenario.TransmissionState.IsActive
        obj.logger.debug("Frame %d, TxID %s: Transmitter inactive, skipping.", FrameId, string(currentTxId));
        TxInfo = setupTransmitterInfo(obj, FrameId, currentTxScenario, currentTxId);
        signalSegmentsPerTx = {};
        return;
    end

    % Determine which segments to process based on TransmissionState
    if isfield(currentTxScenario, 'TransmissionState') && ...
            isfield(currentTxScenario.TransmissionState, 'CurrentIntervalIdx') && ...
            currentTxScenario.TransmissionState.CurrentIntervalIdx > 0
        activeIntervalIdx = currentTxScenario.TransmissionState.CurrentIntervalIdx;
        currentTxScenario.NumSegments = 1;
        currentTxScenario.ActiveSegmentIndices = activeIntervalIdx;
    elseif isfield(currentTxScenario, 'Temporal') && isfield(currentTxScenario.Temporal, 'Intervals')
        intervals = currentTxScenario.Temporal.Intervals;
        if ~isempty(intervals) && size(intervals, 1) > 0
            currentTxScenario.NumSegments = size(intervals, 1);
            currentTxScenario.ActiveSegmentIndices = 1:size(intervals, 1);
        else
            currentTxScenario.NumSegments = 1;
            currentTxScenario.ActiveSegmentIndices = 1;
        end
    else
        currentTxScenario.NumSegments = 1;
        currentTxScenario.ActiveSegmentIndices = 1;
    end

    % Setup transmitter configuration
    TxInfo = setupTransmitterInfo(obj, FrameId, currentTxScenario, currentTxId);

    % Process only active segments for this transmitter
    signalSegmentsPerTx = processTransmitterSegments(obj, FrameId, currentTxScenario, currentTxId);

    % Update antenna configuration based on modulator output
    updateTransmitterAntennaConfig(obj, FrameId, currentTxId, signalSegmentsPerTx, TxInfo);
end
