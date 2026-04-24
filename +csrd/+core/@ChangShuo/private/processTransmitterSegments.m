function signalSegmentsPerTx = processTransmitterSegments(obj, FrameId, currentTxScenario, currentTxId)
    % processTransmitterSegments - Process all segments for a transmitter
    %
    % This method handles message generation and modulation for all segments
    % of a single transmitter.
    %
    % Inputs:
    %   FrameId - Global frame identifier
    %   currentTxScenario - Current transmitter scenario configuration
    %   currentTxId - Current transmitter ID
    %
    % Outputs:
    %   signalSegmentsPerTx - Cell array of processed signal segments

    % Determine which interval indices to process
    if isfield(currentTxScenario, 'ActiveSegmentIndices')
        activeIndices = currentTxScenario.ActiveSegmentIndices;
    else
        activeIndices = 1:currentTxScenario.NumSegments;
    end

    signalSegmentsPerTx = cell(1, length(activeIndices));

    for k = 1:length(activeIndices)
        segIdx = activeIndices(k);

        try
            signalSegmentsPerTx{k} = processSingleSegment(obj, FrameId, currentTxScenario, currentTxId, segIdx);
        catch ME_seg
            obj.logger.error('Frame %d, TxID %s, Seg %d: Error processing segment: %s', ...
                FrameId, string(currentTxId), segIdx, ME_seg.message);
            signalSegmentsPerTx{k} = [];
        end

    end

end
