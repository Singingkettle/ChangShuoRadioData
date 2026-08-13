function modulatedSignalSegment = modulateSegmentMessage(obj, FrameId, currentTxId, segIdx, currentSegmentScenario, rawMessageStruct)
    % modulateSegmentMessage - Modulate message for a single segment
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    % This method uses the ModulationFactory to modulate message data.
    %
    % Inputs:
    %   FrameId - Global frame identifier
    %   currentTxId - Current transmitter ID
    %   segIdx - Segment index
    %   currentSegmentScenario - Current segment scenario configuration
    %   rawMessageStruct - Generated message structure
    %
    % Outputs:
    %   modulatedSignalSegment - Modulated signal segment

    modConfig = currentSegmentScenario.Modulation;
    modulationConfigIdentifier = modConfig.TypeID;

    obj.logger.debug("Frame %d, TxID %s, Seg %d: Modulating message (Modulation TypeID: %s).", ...
        FrameId, string(currentTxId), segIdx, num2str(modulationConfigIdentifier));

    if isempty(obj.Factories.Modulation)
        obj.logger.error("Frame %d, TxID %s, Seg %d: Modulation factory not initialized.", FrameId, string(currentTxId), segIdx);
        modulatedSignalSegment = [];
        return;
    end

    % Setup placement configuration
    currentPlacementConfig = struct();
    if isfield(currentSegmentScenario, 'Placement')
        currentPlacementConfig = currentSegmentScenario.Placement;
    end

    % Pass the WHOLE message struct, not just .data: the message source
    % declares its native sample rate in .SymbolRate (44.1 kHz for audio
    % clips), and analog modulators need that rate to resample the message
    % onto their own grid. Forwarding only .data silently reinterpreted the
    % samples at the modulator rate, scaling the message spectrum by
    % SampleRate/44.1 kHz and decoupling every analog family from its
    % allocation.
    modulatedSignalSegment = step(obj.Factories.Modulation, ...
        rawMessageStruct, ...
        FrameId, ...
        string(currentTxId), ...
        segIdx, ...
        currentSegmentScenario.Modulation, ...
        currentPlacementConfig);
end
