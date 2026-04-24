function modulatedSignalSegment = processSingleSegment(obj, FrameId, currentTxScenario, currentTxId, segIdx)
    % processSingleSegment - Process a single segment for message generation and modulation
    %
    % This method handles the complete processing of one segment including
    % message generation and modulation.
    %
    % In the new config structure, each "segment" corresponds to a transmission interval
    % defined in TransmissionPattern.Intervals.
    %
    % Inputs:
    %   FrameId - Global frame identifier
    %   currentTxScenario - Current transmitter scenario configuration
    %   currentTxId - Current transmitter ID
    %   segIdx - Segment index (corresponds to interval index)
    %
    % Outputs:
    %   modulatedSignalSegment - Modulated signal segment

    % Build segment config from transmitter config (new structure adaptation)
    currentSegmentScenario = buildSegmentConfig(currentTxScenario, segIdx);

    if isempty(currentSegmentScenario)
        obj.logger.warning('Frame %d, TxID %s, Segment %d: Failed to build segment config.', ...
            FrameId, string(currentTxId), segIdx);
        modulatedSignalSegment = [];
        return;
    end

    % Skip zero-duration segments
    if isfield(currentSegmentScenario, 'Placement') && ...
            isfield(currentSegmentScenario.Placement, 'Duration') && ...
            currentSegmentScenario.Placement.Duration <= 0
        obj.logger.debug('Frame %d, TxID %s, Segment %d: Zero duration, skipping.', ...
            FrameId, string(currentTxId), segIdx);
        modulatedSignalSegment = [];
        return;
    end

    % Validate message configuration
    if ~validateSegmentMessageConfig(obj, currentSegmentScenario, FrameId, currentTxId, segIdx)
        modulatedSignalSegment = [];
        return;
    end

    % Validate modulation configuration
    if ~validateSegmentModulationConfig(obj, currentSegmentScenario, FrameId, currentTxId, segIdx)
        modulatedSignalSegment = [];
        return;
    end

    % Generate message
    rawMessageStruct = generateSegmentMessage(obj, FrameId, currentTxId, segIdx, currentSegmentScenario);

    if isempty(rawMessageStruct)
        modulatedSignalSegment = [];
        return;
    end

    % Modulate message
    modulatedSignalSegment = modulateSegmentMessage(obj, FrameId, currentTxId, segIdx, ...
        currentSegmentScenario, rawMessageStruct);

    if ~isempty(modulatedSignalSegment)
        modulatedSignalSegment.SegmentId = segIdx;
        modulatedSignalSegment.StartTime = currentSegmentScenario.Placement.StartTime;
        modulatedSignalSegment.Duration = currentSegmentScenario.Placement.Duration;
        modulatedSignalSegment.FrequencyOffset = currentSegmentScenario.Placement.FrequencyOffset;

        % Ensure SampleRate is explicitly set
        if ~isfield(modulatedSignalSegment, 'SampleRate') || isempty(modulatedSignalSegment.SampleRate)
            if isfield(modulatedSignalSegment, 'Signal') && ~isempty(modulatedSignalSegment.Signal)
                modulatedSignalSegment.SampleRate = length(modulatedSignalSegment.Signal) / ...
                    max(modulatedSignalSegment.Duration, eps);
            end
        end

        modulatedSignalSegment.Planned = struct();
        modulatedSignalSegment.Planned.Bandwidth = currentSegmentScenario.Placement.TargetBandwidth;
        modulatedSignalSegment.Planned.FrequencyOffset = currentSegmentScenario.Placement.FrequencyOffset;
    end
end

function segmentConfig = buildSegmentConfig(txScenario, segIdx)
    % buildSegmentConfig - Build segment configuration from TxPlan
    %
    % Adapts the TxPlan structure to the segment execution format

    segmentConfig = struct();

    % Check if we have temporal pattern with intervals
    if ~isfield(txScenario, 'Temporal') || ~isfield(txScenario.Temporal, 'Intervals')
        segmentConfig = [];
        return;
    end

    intervals = txScenario.Temporal.Intervals;
    if segIdx > size(intervals, 1)
        segmentConfig = [];
        return;
    end

    % Get timing for this segment
    startTime = intervals(segIdx, 1);
    endTime = intervals(segIdx, 2);
    duration = endTime - startTime;

    % Build Message config
    segmentConfig.Message = struct();
    if isfield(txScenario, 'Message') && isstruct(txScenario.Message)
        segmentConfig.Message = txScenario.Message;
        if isfield(txScenario.Message, 'Type')
            segmentConfig.Message.TypeID = txScenario.Message.Type;
        elseif isfield(txScenario.Message, 'TypeID')
            segmentConfig.Message.TypeID = txScenario.Message.TypeID;
        else
            segmentConfig.Message.TypeID = 'RandomBit';
        end
    else
        segmentConfig.Message.TypeID = 'RandomBit';
        segmentConfig.Message.Length = 1024;
    end

    % Build Modulation config
    segmentConfig.Modulation = struct();
    if isfield(txScenario, 'Modulation') && isstruct(txScenario.Modulation)
        segmentConfig.Modulation = txScenario.Modulation;
        if isfield(txScenario.Modulation, 'Type')
            segmentConfig.Modulation.TypeID = txScenario.Modulation.Type;
        elseif isfield(txScenario.Modulation, 'TypeID')
            segmentConfig.Modulation.TypeID = txScenario.Modulation.TypeID;
        else
            segmentConfig.Modulation.TypeID = 'PSK';
        end
    else
        segmentConfig.Modulation.TypeID = 'PSK';
        segmentConfig.Modulation.Order = 4;
        segmentConfig.Modulation.SymbolRate = 100e3;
        segmentConfig.Modulation.SamplesPerSymbol = 4;
    end

    % Build Placement config with timing and frequency from Spectrum
    segmentConfig.Placement = struct();
    segmentConfig.Placement.StartTime = startTime;
    segmentConfig.Placement.Duration = duration;

    if isfield(txScenario, 'Spectrum') && isstruct(txScenario.Spectrum)
        if isfield(txScenario.Spectrum, 'PlannedFreqOffset')
            segmentConfig.Placement.FrequencyOffset = txScenario.Spectrum.PlannedFreqOffset;
        else
            segmentConfig.Placement.FrequencyOffset = 0;
        end
        if isfield(txScenario.Spectrum, 'PlannedBandwidth')
            segmentConfig.Placement.TargetBandwidth = txScenario.Spectrum.PlannedBandwidth;
        else
            segmentConfig.Placement.TargetBandwidth = 100e3;
        end
    else
        segmentConfig.Placement.FrequencyOffset = 0;
        segmentConfig.Placement.TargetBandwidth = 100e3;
    end
end
