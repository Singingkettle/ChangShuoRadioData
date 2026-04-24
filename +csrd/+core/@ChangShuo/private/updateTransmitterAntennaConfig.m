function TxInfo = updateTransmitterAntennaConfig(obj, FrameId, currentTxId, signalSegmentsPerTx, TxInfo)
    % updateTransmitterAntennaConfig - Update transmitter antenna configuration.
    %
    % Thin wrapper around csrd.utils.core.applyAntennaConfigFromSegments
    % so that the pure logic can be unit-tested without standing up a
    % full ChangShuo runtime. MATLAB structs are passed by value; the
    % function MUST return the (possibly) updated TxInfo to the caller.

    previousNum = TxInfo.NumTransmitAntennas;
    [TxInfo, didChange, finalNumAntennas, ~] = ...
        csrd.utils.core.applyAntennaConfigFromSegments(TxInfo, signalSegmentsPerTx);

    if didChange
        obj.logger.debug("Frame %d, TxID %s: Updating NumTransmitAntennas from %d to %d based on modulator output.", ...
            FrameId, string(currentTxId), previousNum, finalNumAntennas);
    end
end
