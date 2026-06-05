function modulatedSignalSegment = processSingleSegment(obj, FrameId, currentTxScenario, currentTxId, segIdx)
    % processSingleSegment - Process a single segment for message generation and modulation
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
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

    % Phase 3 (§3.2.A): the segment builder lives on the class as a
    % Static, Hidden method so unit tests can pin the fail-fast
    % contract without standing up the engine. Returning [] is
    % reserved for benign control-flow (no Temporal.Intervals or
    % segIdx past the last interval); planner-side errors raise
    % CSRD:Construction:Missing* identifiers and propagate up.
    currentSegmentScenario = csrd.core.ChangShuo.buildSegmentConfigFromTxScenario( ...
        currentTxScenario, segIdx);

    if isempty(currentSegmentScenario)
        obj.logger.debug(['Frame %d, TxID %s, Segment %d: no sample-grid ', ...
            'segment config for this frame, skipping.'], ...
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
        segmentId = sprintf('%s.Seg%03d', char(string(currentTxId)), segIdx);
        burstId = sprintf('%s.Burst%03d', char(string(currentTxId)), segIdx);
        modulatedSignalSegment.ID = segmentId;
        modulatedSignalSegment.TxId = currentTxId;
        modulatedSignalSegment.SegmentId = segmentId;
        modulatedSignalSegment.BurstId = burstId;
        modulatedSignalSegment.StartTime = currentSegmentScenario.Placement.StartTime;
        modulatedSignalSegment.Duration = currentSegmentScenario.Placement.Duration;
        modulatedSignalSegment.EndTime = currentSegmentScenario.Placement.EndTime;
        modulatedSignalSegment.FrameWindow = currentSegmentScenario.Placement.FrameWindow;
        modulatedSignalSegment.FrameRelativeStartTime = ...
            currentSegmentScenario.Placement.FrameRelativeStartTime;
        modulatedSignalSegment.FrameRelativeEndTime = ...
            currentSegmentScenario.Placement.FrameRelativeEndTime;
        modulatedSignalSegment.GeometryEvaluationTimeSec = ...
            currentSegmentScenario.Placement.GeometryEvaluationTimeSec;
        modulatedSignalSegment.GeometryEvaluationPolicy = ...
            currentSegmentScenario.Placement.GeometryEvaluationPolicy;
        modulatedSignalSegment.FrequencyOffset = currentSegmentScenario.Placement.FrequencyOffset;

        % Modulators are required to set SampleRate explicitly. The
        % previous implementation back-derived SampleRate from
        % length(Signal)/Duration, which silently masks modulator bugs
        % and produces non-physical sampling rates whenever the segment
        % length is not aligned with the planned duration. Fail fast
        % instead so the offending modulator is fixed at the source.
        if ~isfield(modulatedSignalSegment, 'SampleRate') || ...
                isempty(modulatedSignalSegment.SampleRate) || ...
                modulatedSignalSegment.SampleRate <= 0
            error('CSRD:Core:MissingSampleRate', ...
                ['Frame %d, TxID %s, Segment %d: modulator returned no ', ...
                 'valid SampleRate. Modulators MUST populate ', ...
                 'modulatedSignalSegment.SampleRate; back-derivation ', ...
                 'from length(Signal)/Duration is no longer permitted.'], ...
                FrameId, string(currentTxId), segIdx);
        end

        modulatedSignalSegment = csrd.pipeline.signal.gateToDuration( ...
            modulatedSignalSegment, ...
            currentSegmentScenario.Placement.FrameRelativeEndTime - ...
                currentSegmentScenario.Placement.FrameRelativeStartTime, ...
            'ModulatorOutput', 'MinPositiveSamples', true);

        modulatedSignalSegment.Planned = struct();
        modulatedSignalSegment.Planned.Bandwidth = currentSegmentScenario.Placement.TargetBandwidth;
        modulatedSignalSegment.Planned.FrequencyOffset = currentSegmentScenario.Placement.FrequencyOffset;
        if isfield(currentTxScenario, 'Regulatory') && ...
                isstruct(currentTxScenario.Regulatory)
            modulatedSignalSegment.Planned.Regulatory = currentTxScenario.Regulatory;
        else
            modulatedSignalSegment.Planned.Regulatory = ...
                csrd.catalog.spectrum.RegulatoryValidator.emptyRegulatoryTruth();
        end

        % Phase 4 (§5 Truth.Design): the v2 annotation Design block reads
        % `comp.Planned.{PlannedCenterFrequencyHz, PlannedBandwidthHz,
        % PlannedSampleRate, ModulationFamily, ModulationOrder,
        % PayloadLengthBits, NumTransmitAntennas}` to publish the
        % design-time blueprint values verbatim. Project them off
        % currentTxScenario here (the planner-side ground truth) so the
        % downstream `buildSourceAnnotation` does not have to reach back
        % into TxScenario or fall back on NaN sentinels (which get
        % flagged by `validateMeasurementCompleteness` / smoke tests).
        modulatedSignalSegment.Planned.PlannedBandwidthHz = ...
            currentSegmentScenario.Placement.TargetBandwidth;
        modulatedSignalSegment.Planned.PlannedCenterFrequencyHz = ...
            currentSegmentScenario.Placement.FrequencyOffset;
        modulatedSignalSegment.Planned.StartTimeSec = ...
            currentSegmentScenario.Placement.FrameRelativeStartTime;
        modulatedSignalSegment.Planned.EndTimeSec = ...
            currentSegmentScenario.Placement.FrameRelativeEndTime;
        modulatedSignalSegment.Planned.DurationSec = ...
            currentSegmentScenario.Placement.Duration;
        modulatedSignalSegment.Planned.ScenarioStartTimeSec = ...
            currentSegmentScenario.Placement.StartTime;
        modulatedSignalSegment.Planned.ScenarioEndTimeSec = ...
            currentSegmentScenario.Placement.EndTime;
        modulatedSignalSegment.Planned.GeometryEvaluationTimeSec = ...
            currentSegmentScenario.Placement.GeometryEvaluationTimeSec;
        modulatedSignalSegment.Planned.GeometryEvaluationPolicy = ...
            currentSegmentScenario.Placement.GeometryEvaluationPolicy;
        if isfield(currentTxScenario, 'Spectrum') && ...
                isstruct(currentTxScenario.Spectrum) && ...
                isfield(currentTxScenario.Spectrum, 'ReceiverSampleRate') && ...
                ~isempty(currentTxScenario.Spectrum.ReceiverSampleRate)
            modulatedSignalSegment.Planned.PlannedSampleRate = ...
                currentTxScenario.Spectrum.ReceiverSampleRate;
        else
            error('CSRD:Construction:MissingPlannedSampleRate', ...
                ['Frame %d, TxID %s, Segment %d: ', ...
                 'currentTxScenario.Spectrum.ReceiverSampleRate is required. ', ...
                 'Execution SampleRate must not be used to backfill Design truth.'], ...
                FrameId, string(currentTxId), segIdx);
        end
        if isfield(currentTxScenario, 'Modulation') && isstruct(currentTxScenario.Modulation)
            modSrc = currentTxScenario.Modulation;
            if isfield(modSrc, 'Type') && ~isempty(modSrc.Type)
                modulatedSignalSegment.Planned.ModulationFamily = char(modSrc.Type);
            elseif isfield(modSrc, 'TypeID') && ~isempty(modSrc.TypeID)
                modulatedSignalSegment.Planned.ModulationFamily = char(modSrc.TypeID);
            else
                modulatedSignalSegment.Planned.ModulationFamily = '';
            end
            if isfield(modSrc, 'Order') && ~isempty(modSrc.Order) && isnumeric(modSrc.Order)
                modulatedSignalSegment.Planned.ModulationOrder = double(modSrc.Order);
            else
                modulatedSignalSegment.Planned.ModulationOrder = 0;
            end
            if isfield(modSrc, 'ModulatorConfig') && isstruct(modSrc.ModulatorConfig) && ...
                    isfield(modSrc.ModulatorConfig, 'mimo') && ...
                    isstruct(modSrc.ModulatorConfig.mimo) && ...
                    isfield(modSrc.ModulatorConfig.mimo, 'Mode') && ...
                    ~isempty(modSrc.ModulatorConfig.mimo.Mode)
                modulatedSignalSegment.Planned.ModulationSpatialMode = ...
                    char(string(modSrc.ModulatorConfig.mimo.Mode));
            else
                modulatedSignalSegment.Planned.ModulationSpatialMode = '';
            end
        else
            modulatedSignalSegment.Planned.ModulationFamily = '';
            modulatedSignalSegment.Planned.ModulationOrder = 0;
            modulatedSignalSegment.Planned.ModulationSpatialMode = '';
        end
        if isfield(currentTxScenario, 'Message') && isstruct(currentTxScenario.Message) && ...
                isfield(currentTxScenario.Message, 'Length') && ...
                ~isempty(currentTxScenario.Message.Length) && ...
                isnumeric(currentTxScenario.Message.Length)
            modulatedSignalSegment.Planned.PayloadLengthBits = ...
                double(currentSegmentScenario.Message.Length);
        else
            modulatedSignalSegment.Planned.PayloadLengthBits = 0;
        end
        if isfield(currentTxScenario, 'Hardware') && isstruct(currentTxScenario.Hardware) && ...
                isfield(currentTxScenario.Hardware, 'NumAntennas') && ...
                ~isempty(currentTxScenario.Hardware.NumAntennas) && ...
                isnumeric(currentTxScenario.Hardware.NumAntennas)
            modulatedSignalSegment.Planned.NumTransmitAntennas = ...
                double(currentTxScenario.Hardware.NumAntennas);
        else
            error('CSRD:Construction:MissingTxNumAntennas', ...
                ['Frame %d, TxID %s, Segment %d: ', ...
                 'currentTxScenario.Hardware.NumAntennas is required.'], ...
                FrameId, string(currentTxId), segIdx);
        end
    end
end
