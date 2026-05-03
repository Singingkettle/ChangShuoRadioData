function [txsSignalSegments, TxInfos] = processTransmitters(obj, FrameId, numTxThisFrame)
    %PROCESSTRANSMITTERS Phase 3 strict-construction transmitter fan-out.
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 processTransmitters 实现。
    %
    %   Iterates every transmitter scheduled for FrameId and dispatches to
    %   processSingleTransmitter. Phase 3 (audit §3.4 / §17.5 P3-6) removed
    %   the previous catch-swallow that turned any per-Tx exception into a
    %   `Status='Error_TransmitterProcessing'` sentinel and an empty signal
    %   segments cell. Errors now propagate to generateSingleFrame, which
    %   routes scenario-skip identifiers (see
    %   csrd.pipeline.scenario.isScenarioSkipException) up to SimulationRunner
    %   and turns truly unexpected crashes into a hard frame-level failure.
    %
    %   The skip-vs-crash contract is intentionally identical to the one in
    %   processTransmitterSegments / ReceiveFactory so a missing-config
    %   bug in any layer surfaces consistently.

    obj.logger.debug("Frame %d: Processing %d transmitter(s).", FrameId, numTxThisFrame);

    txsSignalSegments = cell(1, numTxThisFrame);
    TxInfos = cell(1, numTxThisFrame);

    for txIdx = 1:numTxThisFrame
        try
            [txsSignalSegments{txIdx}, TxInfos{txIdx}] = ...
                processSingleTransmitter(obj, FrameId, txIdx);
        catch ME_tx
            if csrd.pipeline.scenario.isScenarioSkipException(ME_tx)
                rethrow(ME_tx);
            end
            obj.logger.error("Frame %d, Tx Index %d: Error processing transmitter: %s", ...
                FrameId, txIdx, ME_tx.message);
            rethrow(ME_tx);
        end
    end

    obj.logger.debug("Frame %d: Message generation and modulation complete.", FrameId);
end
