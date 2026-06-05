function [signalSegmentsPerTx, TxInfo] = processSingleTransmitter(obj, FrameId, txIdx)
    % processSingleTransmitter - Process a single transmitter configuration
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
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
        error('CSRD:Construction:TxScenarioOutOfRange', ...
            ['Frame %d, Tx index %d exceeds ScenarioConfig.Transmitters. ', ...
             'The scenario planner must provide one transmitter plan per ', ...
             'requested Tx.'], FrameId, txIdx);
    end

    % Access transmitter config (stored as cell array)
    currentTxScenario = obj.ScenarioConfig.Transmitters{txIdx};
    
    if ~isfield(currentTxScenario, 'EntityID')
        error('CSRD:Construction:TxMissingEntityID', ...
            ['Frame %d, Tx index %d: transmitter scenario is missing ', ...
             'EntityID. The planner must preserve physical/communication ', ...
             'entity identity across the pipeline.'], FrameId, txIdx);
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

    % v0.4 deep refactor: TransmissionState.ActiveIntervalIndices is the
    % single source of truth. CommunicationBehaviorSimulator must populate
    % it (possibly empty) for every active transmitter; there are no
    % silent fallbacks to legacy scalar fields any more.
    if ~isfield(currentTxScenario, 'TransmissionState') || ...
            ~isfield(currentTxScenario.TransmissionState, 'ActiveIntervalIndices')
        error('CSRD:Construction:MissingActiveIntervalIndices', ...
            ['Frame %d, TxID %s: TransmissionState.ActiveIntervalIndices ' ...
             'is missing. CommunicationBehaviorSimulator must produce it.'], ...
            FrameId, string(currentTxId));
    end
    activeIdx = currentTxScenario.TransmissionState.ActiveIntervalIndices;
    if isempty(activeIdx)
        % Active transmitter with no overlapping interval in this frame
        % is a planner-side bug: IsActive should already be false.
        error('CSRD:Construction:ActiveButNoIntervals', ...
            ['Frame %d, TxID %s: TransmissionState.IsActive=true but ' ...
             'ActiveIntervalIndices is empty. The planner contract is ' ...
             'inconsistent.'], FrameId, string(currentTxId));
    end
    currentTxScenario.NumSegments = numel(activeIdx);
    currentTxScenario.ActiveSegmentIndices = double(reshape(activeIdx, 1, []));

    % Setup transmitter configuration
    TxInfo = setupTransmitterInfo(obj, FrameId, currentTxScenario, currentTxId);

    % Process only active segments for this transmitter
    signalSegmentsPerTx = processTransmitterSegments(obj, FrameId, currentTxScenario, currentTxId);
end
