function [FrameData, FrameAnnotation] = processReceiverProcessing(obj, FrameId, signalsAtReceivers, RxInfos)
    % processReceiverProcessing - Process received signals and generate outputs
    %
    % This method combines all received signal components and generates
    % the final frame data and annotations.
    %
    % Inputs:
    %   FrameId - Frame identifier
    %   signalsAtReceivers - Cell array of received signals per receiver
    %   RxInfos - Cell array of receiver information structures
    %
    % Outputs:
    %   FrameData - Final frame data structure
    %   FrameAnnotation - Frame annotation structure

    obj.logger.debug("Frame %d: Processing receiver outputs.", FrameId);

    numRx = length(RxInfos);
    FrameData = cell(1, numRx);
    FrameAnnotation = cell(1, numRx);

    for rxIdx = 1:numRx
        rxInfo = RxInfos{rxIdx};

        if ~isfield(rxInfo, 'ID') || contains(rxInfo.Status, 'Error')
            FrameData{rxIdx} = [];
            FrameAnnotation{rxIdx} = struct('FrameId', FrameId, 'ReceiverID', 'Unknown', 'Status', 'Error');
            continue;
        end

        try
            rxSignals = signalsAtReceivers{rxIdx};

            % Combine all signal components at this receiver
            combinedSignal = combineSignalComponents(obj, rxSignals, rxInfo);

            % Apply receiver processing using ReceiveFactory
            % Handle both cell array and struct array formats
            if iscell(obj.ScenarioConfig.Receivers)
                rxScenarioConfig = obj.ScenarioConfig.Receivers{rxIdx};
            elseif isstruct(obj.ScenarioConfig.Receivers)
                rxScenarioConfig = obj.ScenarioConfig.Receivers(rxIdx);
            else
                rxScenarioConfig = struct();
            end
            processedOutput = step(obj.Factories.Receive, combinedSignal, ...
                FrameId, rxInfo, rxScenarioConfig);

            FrameData{rxIdx} = struct();
            FrameData{rxIdx}.ReceiverID = rxInfo.ID;
            if isfield(processedOutput, 'Signal')
                FrameData{rxIdx}.Signal = processedOutput.Signal;
            else
                FrameData{rxIdx}.Signal = [];
            end
            FrameData{rxIdx}.SampleRate = rxInfo.SampleRate;
            if ~isempty(FrameData{rxIdx}.Signal)
                FrameData{rxIdx}.Duration = length(FrameData{rxIdx}.Signal) / rxInfo.SampleRate;
            else
                FrameData{rxIdx}.Duration = 0;
            end

            FrameAnnotation{rxIdx} = struct();
            FrameAnnotation{rxIdx}.FrameId = FrameId;
            FrameAnnotation{rxIdx}.ReceiverID = rxInfo.ID;
            FrameAnnotation{rxIdx}.ReceiverType = rxInfo.Type;
            FrameAnnotation{rxIdx}.Position = rxInfo.Position;
            FrameAnnotation{rxIdx}.SampleRate = rxInfo.SampleRate;
            FrameAnnotation{rxIdx}.ObservableRange = rxInfo.ObservableRange;
            FrameAnnotation{rxIdx}.NumSignalComponents = length(rxSignals.SignalComponents);
            FrameAnnotation{rxIdx}.Status = 'Success';

            FrameAnnotation{rxIdx}.SignalSources = [];
            for compIdx = 1:length(rxSignals.SignalComponents)
                comp = rxSignals.SignalComponents{compIdx};
                sourceInfo = struct();
                sourceInfo.TxID = comp.TxID;
                sourceInfo.SegmentID = comp.SegmentID;

                sourceInfo.Realized = struct();
                sourceInfo.Realized.FrequencyOffset = comp.FrequencyOffset;
                sourceInfo.Realized.Bandwidth = comp.Bandwidth;
                sourceInfo.Realized.SampleRate = comp.SampleRate;
                if isfield(comp, 'ChannelModel')
                    sourceInfo.Realized.ChannelModel = comp.ChannelModel;
                end
                if isfield(comp, 'RayCount')
                    sourceInfo.Realized.RayCount = comp.RayCount;
                end
                if isfield(comp, 'ChannelFallback')
                    sourceInfo.Realized.ChannelFallback = comp.ChannelFallback;
                end

                if isfield(comp, 'Planned')
                    sourceInfo.Planned = comp.Planned;
                else
                    sourceInfo.Planned = struct('FrequencyOffset', comp.FrequencyOffset, ...
                                                'Bandwidth', comp.Bandwidth);
                end

                if isfield(comp, 'ModulationType')
                    sourceInfo.ModulationType = comp.ModulationType;
                end
                if isfield(comp, 'RFImpairments')
                    sourceInfo.RFImpairments = comp.RFImpairments;
                end

                % Spatial and link budget annotation
                sourceInfo.Spatial = struct();
                if isfield(comp, 'TxPosition')
                    sourceInfo.Spatial.TxPosition = comp.TxPosition;
                end
                if isfield(comp, 'TxVelocity')
                    sourceInfo.Spatial.TxVelocity = comp.TxVelocity;
                end
                if isfield(comp, 'RxPosition')
                    sourceInfo.Spatial.RxPosition = comp.RxPosition;
                end
                if isfield(comp, 'LinkDistance')
                    sourceInfo.Spatial.LinkDistance = comp.LinkDistance;
                end
                if isfield(comp, 'PathLoss')
                    sourceInfo.Spatial.PathLoss = comp.PathLoss;
                end
                if isfield(comp, 'ComputedSNR')
                    sourceInfo.Spatial.ComputedSNR = comp.ComputedSNR;
                end
                if isfield(comp, 'AppliedSNRdB')
                    sourceInfo.Spatial.AppliedSNRdB = comp.AppliedSNRdB;
                end
                if isfield(comp, 'AppliedPathLoss')
                    sourceInfo.Spatial.AppliedPathLoss = comp.AppliedPathLoss;
                end
                if isfield(comp, 'ChannelInfo')
                    sourceInfo.Channel = comp.ChannelInfo;
                end

                FrameAnnotation{rxIdx}.SignalSources = [FrameAnnotation{rxIdx}.SignalSources, sourceInfo];
            end

            obj.logger.debug("Frame %d, RxID %s: Receiver processing complete (%d signal components).", ...
                FrameId, string(rxInfo.ID), length(rxSignals.SignalComponents));

        catch ME_rx
            obj.logger.error("Frame %d, Rx %s: Receiver processing error: %s", ...
                FrameId, string(rxInfo.ID), ME_rx.message);
            FrameData{rxIdx} = [];
            FrameAnnotation{rxIdx} = struct('FrameId', FrameId, 'ReceiverID', rxInfo.ID, ...
                'Status', 'Error', 'ErrorMessage', ME_rx.message);
        end
    end

    obj.logger.debug("Frame %d: All receiver processing complete.", FrameId);
end

function combinedSignal = combineSignalComponents(obj, rxSignals, rxInfo)
    % combineSignalComponents - Combine multiple signal components at receiver
    %
    % Aggregates signal components with time-alignment based on StartTime.
    % Each component's StartTime determines its position in the output buffer.

    combinedSignal = struct();
    combinedSignal.Signal = [];
    combinedSignal.Components = rxSignals.SignalComponents;

    if isempty(rxSignals.SignalComponents)
        noiseDuration = 0.001;
        numSamples = round(noiseDuration * rxInfo.SampleRate);
        combinedSignal.Signal = complex(zeros(numSamples, 1));
        obj.logger.debug("RxID %s: No signal components, generating empty frame.", string(rxInfo.ID));
        return;
    end

    sampleRate = rxInfo.SampleRate;

    % Calculate total buffer length considering StartTime offsets
    totalLength = 0;
    for compIdx = 1:length(rxSignals.SignalComponents)
        comp = rxSignals.SignalComponents{compIdx};
        if isfield(comp, 'Signal') && ~isempty(comp.Signal)
            startOffset = 0;
            if isfield(comp, 'StartTime') && comp.StartTime > 0
                startOffset = round(comp.StartTime * sampleRate);
            end
            endSample = startOffset + numel(comp.Signal);
            totalLength = max(totalLength, endSample);
        end
    end

    if totalLength == 0
        noiseDuration = 0.001;
        numSamples = round(noiseDuration * sampleRate);
        combinedSignal.Signal = complex(zeros(numSamples, 1));
        return;
    end

    combinedSignal.Signal = complex(zeros(totalLength, 1));

    for compIdx = 1:length(rxSignals.SignalComponents)
        comp = rxSignals.SignalComponents{compIdx};
        if isfield(comp, 'Signal') && ~isempty(comp.Signal)
            startOffset = 0;
            if isfield(comp, 'StartTime') && comp.StartTime > 0
                startOffset = round(comp.StartTime * sampleRate);
            end
            compSig = comp.Signal(:);
            sigLen = length(compSig);
            idxStart = startOffset + 1;
            idxEnd = startOffset + sigLen;
            combinedSignal.Signal(idxStart:idxEnd) = ...
                combinedSignal.Signal(idxStart:idxEnd) + compSig;
        end
    end
end

