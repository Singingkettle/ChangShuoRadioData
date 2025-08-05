function [txsSignalSegments, TxInfos] = processTransmitters(obj, FrameId, numTxThisFrame)
    % processTransmitters - Process all transmitters in the current frame
    %
    % This method orchestrates the processing of all transmitters including
    % message generation, modulation, and signal segment creation.
    %
    % Inputs:
    %   FrameId - Global frame identifier
    %   numTxThisFrame - Number of transmitters to process
    %
    % Outputs:
    %   txsSignalSegments - Cell array of signal segments per transmitter
    %   TxInfos - Cell array of transmitter information structures

    obj.logger.debug("Frame %d: Processing %d transmitter(s).", FrameId, numTxThisFrame);

    txsSignalSegments = cell(1, numTxThisFrame);
    TxInfos = cell(1, numTxThisFrame);

    % Loop through transmitters based on ScenarioConfig
    for txIdx = 1:numTxThisFrame

        try
            [txsSignalSegments{txIdx}, TxInfos{txIdx}] = ...
                processSingleTransmitter(obj, FrameId, txIdx);
        catch ME_tx
            obj.logger.error("Frame %d, Tx Index %d: Error processing transmitter: %s", ...
                FrameId, txIdx, ME_tx.message);
            txsSignalSegments{txIdx} = {};
            TxInfos{txIdx} = struct('Status', 'Error_TransmitterProcessing', 'ErrorMessage', ME_tx.message);
        end

    end

    obj.logger.debug("Frame %d: Message generation and modulation complete.", FrameId);
end
