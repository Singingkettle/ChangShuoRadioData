function txsSignalSegments = processTransmitImpairments(obj, FrameId, txsSignalSegments, TxInfos)
    % processTransmitImpairments - Apply transmitter frontend impairments
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 processTransmitImpairments 实现。
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

                            % Phase 3 (§3.2.B): the segment-signal contract is
                            % enforced by a Static, Hidden helper on the class so
                            % the same fail-fast surface can be exercised from
                            % unit tests. The legacy `2.5 * plannedBW` derive
                            % branch and the `FrequencyOffset = 0` /
                            % `TransmitError = true` swallows have been removed.
                            segSignal = txsSignalSegments{txIdx}{segIdx};
                            csrd.core.ChangShuo.assertSegmentSignalReadyForImpairments( ...
                                segSignal, FrameId, currentTxId, segIdx);

                            if ~isfield(segSignal, 'Signal') || isempty(segSignal.Signal)
                                obj.logger.debug("Frame %d, TxID %s, Seg %d: No signal data, skipping transmit impairments.", ...
                                    FrameId, string(currentTxId), segIdx);
                                continue;
                            end

                            txOut = step(obj.Factories.Transmit, ...
                                segSignal, FrameId, currentTxInfo, txScenarioConfig);
                            txOut = csrd.pipeline.signal.gateToDuration( ...
                                txOut, localSegmentDurationSec(txOut), ...
                                'TransmitOutput');
                            txsSignalSegments{txIdx}{segIdx} = txOut;

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

function durationSec = localSegmentDurationSec(segSignal)
    % localSegmentDurationSec - Production declaration in CSRD.
    % 中文说明：localSegmentDurationSec 在 CSRD 生产链路中执行对应处理。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    if isfield(segSignal, 'FrameRelativeStartTime') && ...
            isfield(segSignal, 'FrameRelativeEndTime') && ...
            ~isempty(segSignal.FrameRelativeStartTime) && ...
            ~isempty(segSignal.FrameRelativeEndTime)
        durationSec = double(segSignal.FrameRelativeEndTime) - ...
            double(segSignal.FrameRelativeStartTime);
    elseif isfield(segSignal, 'Duration') && ~isempty(segSignal.Duration)
        durationSec = double(segSignal.Duration);
    else
        error('CSRD:Signal:MissingSegmentDuration', ...
            'Segment signal is missing Duration/FrameRelative time fields.');
    end
    if durationSec < 0 || ~isfinite(durationSec)
        error('CSRD:Signal:InvalidSegmentDuration', ...
            'Segment duration must be finite and non-negative.');
    end
end
