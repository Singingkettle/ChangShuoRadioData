function signalSegmentsPerTx = processTransmitterSegments(obj, FrameId, currentTxScenario, currentTxId)
    %PROCESSTRANSMITTERSEGMENTS Phase 3 strict-construction segment fan-out.
    %
    %   Iterates every active segment of currentTxScenario and dispatches
    %   to processSingleSegment. Phase 3 (audit §3.4 / §17.5 P3-6) removed
    %   the previous catch-swallow that turned a per-segment failure into
    %   `signalSegmentsPerTx{k} = []` and let the upstream loop continue
    %   silently. Errors now propagate so a planner-side bug surfaces
    %   instead of decaying into an empty annotation.
    %
    %   Scenario-skip identifiers (see
    %   csrd.utils.scenario.isScenarioSkipException) are rethrown without
    %   logging to keep the sweep log readable; everything else is logged
    %   then rethrown for diagnostics.

    if ~isfield(currentTxScenario, 'ActiveSegmentIndices')
        error('CSRD:Construction:MissingActiveSegmentIndices', ...
            ['Frame %d, TxID %s: ActiveSegmentIndices is missing. ', ...
             'processSingleTransmitter is the only valid source of ', ...
             'segment fan-out after Phase 4.'], FrameId, string(currentTxId));
    end
    activeIndices = currentTxScenario.ActiveSegmentIndices;

    signalSegmentsPerTx = cell(1, length(activeIndices));

    for k = 1:length(activeIndices)
        segIdx = activeIndices(k);

        try
            signalSegmentsPerTx{k} = processSingleSegment(obj, FrameId, currentTxScenario, currentTxId, segIdx);
        catch ME_seg
            if csrd.utils.scenario.isScenarioSkipException(ME_seg)
                rethrow(ME_seg);
            end
            obj.logger.error('Frame %d, TxID %s, Seg %d: Error processing segment: %s', ...
                FrameId, string(currentTxId), segIdx, ME_seg.message);
            rethrow(ME_seg);
        end
    end
end
