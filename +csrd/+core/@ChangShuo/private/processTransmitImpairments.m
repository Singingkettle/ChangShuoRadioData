function txsSignalSegments = processTransmitImpairments(obj, FrameId, txsSignalSegments, TxInfos)
    % processTransmitImpairments - Apply transmitter frontend impairments
    %
    % This method applies transmitter RF frontend impairments to all signal segments
    % using the TransmitFactory.
    %
    % Inputs:
    %   obj - ChangShuo object instance
    %   FrameId - Global frame identifier
    %   txsSignalSegments - Cell array of signal segments per transmitter
    %   TxInfos - Cell array of transmitter information structures
    %
    % Outputs:
    %   txsSignalSegments - Modified signal segments with impairments applied

    if ~isempty(obj.pTransmitFactory)
        obj.logger.debug("Frame %d: Applying transmit impairments using pTransmitFactory.", FrameId);

        for txIdx = 1:length(txsSignalSegments)

            if txIdx <= length(TxInfos) && ~isempty(TxInfos{txIdx}) && isfield(TxInfos{txIdx}, 'ID')
                currentTxId = TxInfos{txIdx}.ID;

                if ~isempty(txsSignalSegments{txIdx})
                    currentTxInfo = TxInfos{txIdx};

                    for segIdx = 1:length(txsSignalSegments{txIdx})

                        if ~isempty(txsSignalSegments{txIdx}{segIdx})
                            obj.logger.debug("Frame %d, TxID %s, Seg %d: Applying transmit impairments.", ...
                                FrameId, string(currentTxId), segIdx);

                            try
                                txsSignalSegments{txIdx}{segIdx} = step(obj.pTransmitFactory, ...
                                    txsSignalSegments{txIdx}{segIdx}, FrameId, currentTxInfo, segIdx);
                            catch ME_transmit
                                obj.logger.error("Frame %d, TxID %s, Seg %d: Error during transmit impairments: %s", ...
                                    FrameId, string(currentTxId), segIdx, ME_transmit.message);
                            end

                        end

                    end

                end

            end

        end

    else
        obj.logger.warning("Frame %d: TransmitFactory not initialized. Skipping transmit impairments.", FrameId);
    end

    obj.logger.debug("Frame %d: Transmit impairment stage complete.", FrameId);
end
