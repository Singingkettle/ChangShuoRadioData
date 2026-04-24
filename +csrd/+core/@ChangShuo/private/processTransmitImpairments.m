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

    if ~isempty(obj.Factories.Transmit)
        obj.logger.debug("Frame %d: Applying transmit impairments.", FrameId);

        for txIdx = 1:length(txsSignalSegments)

            if txIdx <= length(TxInfos) && ~isempty(TxInfos{txIdx}) && isfield(TxInfos{txIdx}, 'ID')
                currentTxId = TxInfos{txIdx}.ID;

                if ~isempty(txsSignalSegments{txIdx})
                    currentTxInfo = TxInfos{txIdx};

                    % Get transmitter scenario config (handle both cell array and struct array)
                    if iscell(obj.ScenarioConfig.Transmitters)
                        txScenarioConfig = obj.ScenarioConfig.Transmitters{txIdx};
                    elseif isstruct(obj.ScenarioConfig.Transmitters)
                        txScenarioConfig = obj.ScenarioConfig.Transmitters(txIdx);
                    else
                        txScenarioConfig = struct();
                    end
                    for segIdx = 1:length(txsSignalSegments{txIdx})

                        if ~isempty(txsSignalSegments{txIdx}{segIdx}) && isstruct(txsSignalSegments{txIdx}{segIdx})
                            obj.logger.debug("Frame %d, TxID %s, Seg %d: Applying transmit impairments.", ...
                                FrameId, string(currentTxId), segIdx);

                            try
                                segSignal = txsSignalSegments{txIdx}{segIdx};

                                if ~isfield(segSignal, 'FrequencyOffset')
                                    segSignal.FrequencyOffset = 0;
                                end
                                if ~isfield(segSignal, 'SampleRate')
                                    segSignal.SampleRate = 200e3;
                                end
                                if ~isfield(segSignal, 'Signal') || isempty(segSignal.Signal)
                                    obj.logger.debug("Frame %d, TxID %s, Seg %d: No signal data, skipping transmit impairments.", ...
                                        FrameId, string(currentTxId), segIdx);
                                    continue;
                                end

                                txsSignalSegments{txIdx}{segIdx} = step(obj.Factories.Transmit, ...
                                    segSignal, FrameId, currentTxInfo, txScenarioConfig);
                            catch ME_transmit
                                obj.logger.error("Frame %d, TxID %s, Seg %d: Error during transmit impairments: %s", ...
                                    FrameId, string(currentTxId), segIdx, ME_transmit.message);
                                txsSignalSegments{txIdx}{segIdx}.TransmitError = true;
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
