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

    signalSegmentsPerTx = cell(1, currentTxScenario.NumSegments);

    for segIdx = 1:currentTxScenario.NumSegments

        try
            signalSegmentsPerTx{segIdx} = processSingleSegment(obj, FrameId, currentTxScenario, currentTxId, segIdx);
        catch ME_seg
            obj.logger.error('Frame %d, TxID %s, Seg %d: Error processing segment: %s', ...
                FrameId, string(currentTxId), segIdx, ME_seg.message);
            signalSegmentsPerTx{segIdx} = [];
        end

    end

end
