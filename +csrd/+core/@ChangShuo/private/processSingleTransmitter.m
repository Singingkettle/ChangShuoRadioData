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
    if txIdx > length(obj.ScenarioConfig.Transmitters) || ~isfield(obj.ScenarioConfig.Transmitters(txIdx), 'ID')
        obj.logger.warning('Frame %d, Tx Index %d: Scenario definition issue or ID missing.', FrameId, txIdx);
        signalSegmentsPerTx = {};
        TxInfo = struct('Status', 'Error_MissingTxScenarioID');
        return;
    end

    currentTxScenario = obj.ScenarioConfig.Transmitters(txIdx);
    currentTxId = currentTxScenario.ID;

    obj.logger.debug("Frame %d, TxID %s: Configuring transmitter.", FrameId, string(currentTxId));

    % Validate number of segments
    if ~isfield(currentTxScenario, 'NumSegments') || currentTxScenario.NumSegments <= 0
        obj.logger.warning('Frame %d, TxID %s: NumSegments not defined or invalid.', FrameId, string(currentTxId));
        signalSegmentsPerTx = {};
        TxInfo = struct('ID', currentTxId, 'Status', 'Error_InvalidNumSegments');
        return;
    end

    % Setup transmitter configuration
    TxInfo = setupTransmitterInfo(obj, FrameId, currentTxScenario, currentTxId);

    % Process all segments for this transmitter
    signalSegmentsPerTx = processTransmitterSegments(obj, FrameId, currentTxScenario, currentTxId);

    % Update antenna configuration based on modulator output
    updateTransmitterAntennaConfig(obj, FrameId, currentTxId, signalSegmentsPerTx, TxInfo);
end
