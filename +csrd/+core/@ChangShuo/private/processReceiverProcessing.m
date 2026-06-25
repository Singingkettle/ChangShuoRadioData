function [FrameData, FrameAnnotation] = processReceiverProcessing(obj, FrameId, signalsAtReceivers, RxInfos)
    % processReceiverProcessing - Process received signals and generate outputs
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
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

        if ~isfield(rxInfo, 'ID')
            error('CSRD:Construction:RxMissingIdentifier', ...
                'Frame %d, Rx index %d: RxInfo is missing ID.', FrameId, rxIdx);
        end
        if isfield(rxInfo, 'Status') && contains(rxInfo.Status, 'Error')
            error('CSRD:Construction:RxInvalidStatus', ...
                'Frame %d, RxID %s: RxInfo has error status %s.', ...
                FrameId, string(rxInfo.ID), string(rxInfo.Status));
        end

        try
            rxSignals = signalsAtReceivers{rxIdx};

            % Combine all signal components at this receiver
            combinedSignal = combineSignalComponents(obj, rxSignals, rxInfo);
            frameShape = combinedSignal.FrameShape;
            framePlan = localFramePlanForAnnotation(obj, FrameId);

            % Apply receiver processing using ReceiveFactory. Receivers is a
            % cell array or struct array by contract; no silent empty-config
            % fallback (that would mask a broken scenario plan).
            if iscell(obj.ScenarioConfig.Receivers)
                rxScenarioConfig = obj.ScenarioConfig.Receivers{rxIdx};
            else
                rxScenarioConfig = obj.ScenarioConfig.Receivers(rxIdx);
            end
            processedOutput = step(obj.Factories.Receive, combinedSignal, ...
                FrameId, rxInfo, rxScenarioConfig);
            if isfield(processedOutput, 'Signal')
                [processedOutput.Signal, rxFrameGating] = ...
                    localCoerceProcessedFrameLength( ...
                        processedOutput.Signal, frameShape.NumSamples);
            else
                rxFrameGating = struct( ...
                    'InputSamples', 0, ...
                    'OutputSamples', frameShape.NumSamples, ...
                    'TargetSamples', frameShape.NumSamples, ...
                    'Action', 'empty');
                processedOutput.Signal = complex(zeros(frameShape.NumSamples, 1));
            end

            FrameData{rxIdx} = struct();
            FrameData{rxIdx}.ReceiverID = rxInfo.ID;
            % processedOutput.Signal is always populated above (coerced or
            % zero-filled), so no second existence check is needed here.
            FrameData{rxIdx}.Signal = processedOutput.Signal;
            FrameData{rxIdx}.SampleRate = rxInfo.SampleRate;
            FrameData{rxIdx}.Duration = frameShape.DurationSec;
            FrameData{rxIdx}.FrameLengthSamples = frameShape.NumSamples;
            FrameData{rxIdx}.FrameShape = frameShape;
            FrameData{rxIdx}.RxFrameGating = rxFrameGating;

            FrameAnnotation{rxIdx} = struct();
            FrameAnnotation{rxIdx}.FrameId = FrameId;
            FrameAnnotation{rxIdx}.ReceiverID = rxInfo.ID;
            FrameAnnotation{rxIdx}.ReceiverType = rxInfo.Type;
            FrameAnnotation{rxIdx}.Position = rxInfo.Position;
            FrameAnnotation{rxIdx}.SampleRate = rxInfo.SampleRate;
            FrameAnnotation{rxIdx}.ObservableRange = rxInfo.ObservableRange;
            FrameAnnotation{rxIdx}.FrameLengthSamples = frameShape.NumSamples;
            FrameAnnotation{rxIdx}.FrameDurationSec = frameShape.DurationSec;
            FrameAnnotation{rxIdx}.FramePlan = framePlan;
            if isfield(obj.ScenarioConfig, 'ScenarioPlan') && ...
                    isstruct(obj.ScenarioConfig.ScenarioPlan)
                FrameAnnotation{rxIdx}.ScenarioPlan = struct( ...
                    'Frame', obj.ScenarioConfig.ScenarioPlan.Frame, ...
                    'DatasetAccounting', ...
                        obj.ScenarioConfig.ScenarioPlan.DatasetAccounting);
            end
            FrameAnnotation{rxIdx}.NumSignalComponents = length(combinedSignal.Components);
            FrameAnnotation{rxIdx}.Status = 'Success';

            % Phase 4 (audit §17.6 / H17): compute the FramePlane
            % measurements once per receiver from the combined waveform
            % (post Rx-combination, pre Rx RF chain). Each SignalSource
            % then references this cache so we never re-run obw on the
            % same combined buffer N times.
            observableBwHz = computeObservableBandwidthHz(rxInfo);
            framePlaneCache = computeFramePlaneCache( ...
                combinedSignal, rxInfo.SampleRate, observableBwHz);

            % Realized receiver thermal-noise power (input-referred) for the
            % measured received-SNR GT: per emitter, SNR = realized signal power
            % / (realized channel noise + this thermal noise). Shared across the
            % emitters at this receiver.
            thermalNoiseW = NaN;
            if isstruct(processedOutput) && ...
                    isfield(processedOutput, 'RealizedThermalNoiseInputReferredW')
                thermalNoiseW = processedOutput.RealizedThermalNoiseInputReferredW;
            end
            % ADC quantization-noise floor (input-referred), shared across the
            % emitters at this receiver. Bounds the measured SNR by the
            % converter's physical dynamic range (~6.02*AdcBits + 1.76 dB).
            quantNoiseW = NaN;
            if isstruct(processedOutput) && ...
                    isfield(processedOutput, 'RealizedAdcQuantizationNoiseInputReferredW')
                quantNoiseW = processedOutput.RealizedAdcQuantizationNoiseInputReferredW;
            end

            FrameAnnotation{rxIdx}.SignalSources = [];
            for compIdx = 1:length(combinedSignal.Components)
                comp = combinedSignal.Components{compIdx};
                comp.MeasuredReceivedSNRdB = localMeasuredReceivedSnr(comp, thermalNoiseW, quantNoiseW);
                sourceInfo = buildSourceAnnotation(comp, comp.Signal, ...
                    rxInfo.SampleRate, observableBwHz, framePlaneCache);
                FrameAnnotation{rxIdx}.SignalSources = [FrameAnnotation{rxIdx}.SignalSources, sourceInfo];
            end

            % Phase 1 (C1 / §3.6.2): surface the realized RX-side
            % RFImpairments at the frame-annotation level. SourceInfo's
            % RFImpairments field is the TX-side chain (DCOffset /
            % IQImbalance / PhaseNoise / Nonlinearity), so RX-side
            % impairments (DCOffset / IqImbalance / ThermalNoise /
            % MemorylessNonlinearity / SampleRateOffset / Type) need a
            % separate, unambiguous annotation slot to prove the receiver
            % chain actually realized them.
            if isstruct(processedOutput) && isfield(processedOutput, 'RxImpairments')
                FrameAnnotation{rxIdx}.RxImpairments = processedOutput.RxImpairments;
            end

            obj.logger.debug("Frame %d, RxID %s: Receiver processing complete (%d signal components).", ...
                FrameId, string(rxInfo.ID), length(combinedSignal.Components));

        catch ME_rx
            obj.logger.error("Frame %d, Rx %s: Receiver processing error: %s", ...
                FrameId, string(rxInfo.ID), ME_rx.message);
            rethrow(ME_rx);
        end
    end

    obj.logger.debug("Frame %d: All receiver processing complete.", FrameId);
end

function framePlan = localFramePlanForAnnotation(obj, frameId)
%LOCALFRAMEPLANFORANNOTATION Build the header frame plan from ScenarioPlan.
if isempty(obj.ScenarioPlan) || ~isstruct(obj.ScenarioPlan)
    error('CSRD:ScenarioPlan:MissingScenarioPlan', ...
        'ScenarioPlan is required to stamp FramePlan into annotation.');
end
framePlan = csrd.pipeline.runtime.buildFramePlan(obj.ScenarioPlan, frameId);
end

function sourceInfo = buildSourceAnnotation(comp, isolatedSignal, ...
        sampleRate, observableBwHz, framePlaneCache)
    %BUILDSOURCEANNOTATION Phase 4 v2 schema (annotation full-replacement).
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    %   Per Phase 4 §3.4 owner decision A_full_replace, the v1 top-level
    %   keys (`Realized` / `Planned` / `Temporal` / `Spatial` /
    %   `LinkBudget` / `Channel`) are deleted in favour of the unified
    %   Truth.{Design,Execution,Measured} hierarchy. ReceiverView is
    %   stamped by the upstream processReceiverProcessing main loop in
    %   Phase 4 §3.5 (S6 plumbing); this builder only writes the field
    %   when the caller has already attached it onto comp.ReceiverView.
    %
    %   Schema:
    %     SignalSources(k) = struct( ...
    %       'TxID',         char, ...
    %       'SegmentId',    char, ...
    %       'BurstId',      char, ...
    %       'Truth',        struct('Design', .., 'Execution', .., 'Measured', ..), ...
    %       'RFImpairments',struct(...), ...
    %       'ReceiverView', struct(...));
    %
    %   Design   : design-time blueprint values (Planned*, ModulationFamily, ...).
    %   Execution: construction-layer realised values (Modulated bandwidth,
    %              Doppler, geometry snapshot, applied SNR, ...).
    %   Measured : receiver-side measurements; SourcePlane = isolated
    %              per-emitter view (post-channel, pre-combination), and
    %              FramePlane = combined receiver view (post-combination,
    %              pre Rx-RF chain). FramePlane is supplied via
    %              framePlaneCache (computed once per receiver upstream).

    sourceInfo = struct();
    sourceInfo.TxID = comp.TxID;
    sourceInfo.SegmentId = getFieldOrEmpty(comp, 'SegmentId', '');
    sourceInfo.BurstId   = getFieldOrEmpty(comp, 'BurstId',   '');
    if isempty(sourceInfo.BurstId)
        error('CSRD:Annotation:MissingBurstId', ...
            'SignalSource TxID=%s SegmentId=%s is missing BurstId.', ...
            char(string(sourceInfo.TxID)), char(string(sourceInfo.SegmentId)));
    end

    truth = struct();
    truth.Design    = buildDesignTruth(comp);
    truth.Execution = buildExecutionTruth(comp);
    truth.Measured  = buildMeasuredTruth( ...
        isolatedSignal, sampleRate, observableBwHz, comp, framePlaneCache);
    sourceInfo.Truth = truth;

    if isfield(comp, 'RFImpairments')
        sourceInfo.RFImpairments = comp.RFImpairments;
    else
        sourceInfo.RFImpairments = struct();
    end

    if isfield(comp, 'ReceiverView') && isstruct(comp.ReceiverView) && ...
            ~isempty(fieldnames(comp.ReceiverView))
        sourceInfo.ReceiverView = comp.ReceiverView;
    else
        sourceInfo.ReceiverView = struct();
    end
end

function design = buildDesignTruth(comp)
    %BUILDDESIGNTRUTH Project comp.Planned (modulator-set) into v2 Design.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    design = struct();
    plannedSrc = struct();
    if isfield(comp, 'Planned') && isstruct(comp.Planned)
        plannedSrc = comp.Planned;
    end
    design.PlannedCenterFrequencyHz = getFieldOrDefault(plannedSrc, 'CenterFrequency', NaN);
    if isnan(design.PlannedCenterFrequencyHz)
        design.PlannedCenterFrequencyHz = getFieldOrDefault(plannedSrc, 'PlannedCenterFrequencyHz', NaN);
    end
    design.PlannedBandwidthHz = getFieldOrDefault(plannedSrc, 'Bandwidth', NaN);
    if isnan(design.PlannedBandwidthHz)
        design.PlannedBandwidthHz = getFieldOrDefault(plannedSrc, 'PlannedBandwidthHz', NaN);
    end
    design.PlannedSampleRate = getFieldOrDefault(plannedSrc, 'SampleRate', NaN);
    if isnan(design.PlannedSampleRate)
        design.PlannedSampleRate = getFieldOrDefault(plannedSrc, 'PlannedSampleRate', NaN);
    end
    design.StartTimeSec = getFieldOrDefault(plannedSrc, 'StartTimeSec', NaN);
    design.EndTimeSec = getFieldOrDefault(plannedSrc, 'EndTimeSec', NaN);
    design.DurationSec = getFieldOrDefault(plannedSrc, 'DurationSec', NaN);
    design.ScenarioStartTimeSec = getFieldOrDefault(plannedSrc, ...
        'ScenarioStartTimeSec', NaN);
    design.ScenarioEndTimeSec = getFieldOrDefault(plannedSrc, ...
        'ScenarioEndTimeSec', NaN);
    design.GeometryEvaluationTimeSec = getFieldOrDefault(plannedSrc, ...
        'GeometryEvaluationTimeSec', NaN);
    design.GeometryEvaluationPolicy = getFieldOrEmpty(plannedSrc, ...
        'GeometryEvaluationPolicy', '');
    if isfield(plannedSrc, 'GeometrySnapshot') && ...
            isstruct(plannedSrc.GeometrySnapshot)
        design.GeometrySnapshot = plannedSrc.GeometrySnapshot;
    else
        design.GeometrySnapshot = struct();
    end
    design.ModulationFamily  = getFieldOrEmpty(plannedSrc, 'ModulationFamily', '');
    design.ModulationOrder   = getFieldOrDefault(plannedSrc, 'ModulationOrder', NaN);
    design.ModulationSpatialMode = getFieldOrEmpty(plannedSrc, 'ModulationSpatialMode', '');
    design.MessageSource     = getFieldOrEmpty(plannedSrc, 'MessageSource', '');
    design.IsDigital         = getFieldOrDefault(plannedSrc, 'IsDigital', true);
    design.PayloadLengthBits = getFieldOrDefault(plannedSrc, 'PayloadLengthBits', NaN);
    design.NumTransmitAntennas = getFieldOrDefault(plannedSrc, 'NumTransmitAntennas', NaN);
    design.Regulatory = getFieldOrDefault(plannedSrc, 'Regulatory', ...
        csrd.catalog.spectrum.RegulatoryValidator.emptyRegulatoryTruth());
end

function execution = buildExecutionTruth(comp)
    %BUILDEXECUTIONTRUTH Construction-layer ground truth (post-channel).
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    %   Phase 4 §3.4 / §6 C8: `ModulatedBandwidthHz` is now the
    %   `obwActual` measurement performed in `processChannelPropagation`
    %   on the **clean** modulator output (zero AWGN); the legacy
    %   modulator-analytical scalar is preserved on the side as
    %   `AnalyticalBandwidthHz` so historical baselines can still be
    %   compared. Phase 18 removes the analytical fallback: execution
    %   truth must report what the channel/modulator path actually
    %   produced.
    execution = struct();
    measuredBwHz = getFieldOrDefault(comp, 'ModulatedBandwidthHz', NaN);
    if ~isfinite(measuredBwHz) || measuredBwHz <= 0
        error('CSRD:Annotation:MissingExecutionBandwidth', ...
            ['Component TxID=%s BurstId=%s must carry positive ', ...
             'ModulatedBandwidthHz for Truth.Execution.'], ...
            char(string(getFieldOrEmpty(comp, 'TxID', ''))), ...
            char(string(getFieldOrEmpty(comp, 'BurstId', ''))));
    end
    execution.ModulatedBandwidthHz    = measuredBwHz;
    execution.AnalyticalBandwidthHz   = getFieldOrDefault(comp, 'AnalyticalBandwidthHz', ...
        getFieldOrDefault(comp, 'Bandwidth', NaN));
    execution.CenterFrequencyOffsetHz = getFieldOrDefault(comp, 'FrequencyOffset', NaN);
    execution.SampleRate              = getFieldOrDefault(comp, 'SampleRate', NaN);
    execution.StartTimeSec            = getFieldOrDefault(comp, 'FrameRelativeStartTime', ...
        getFieldOrDefault(comp, 'StartTime', NaN));
    execution.EndTimeSec              = getFieldOrDefault(comp, 'FrameRelativeEndTime', NaN);
    execution.DurationSec             = execution.EndTimeSec - execution.StartTimeSec;
    execution.FrameStartSample        = getFieldOrDefault(comp, 'FrameStartSample', NaN);
    execution.FrameEndSample          = getFieldOrDefault(comp, 'FrameEndSample', NaN);
    execution.FrameSampleCount        = getFieldOrDefault(comp, 'FrameSampleCount', NaN);
    execution.FrameLengthSamples      = getFieldOrDefault(comp, 'FrameLengthSamples', NaN);
    execution.ChannelModel            = getFieldOrEmpty(comp, 'ChannelModel', '');
    execution.PathLossDB              = getFieldOrDefault(comp, 'PathLoss', NaN);
    execution.AnalyticalSNRdB         = getFieldOrDefault(comp, 'ComputedSNR', NaN);
    execution.AppliedSNRdB            = getFieldOrDefault(comp, 'AppliedSNRdB', NaN);
    execution.DopplerShiftHz          = getFieldOrDefault(comp, 'DopplerShiftHz', NaN);
    execution.RadialVelocityMps       = getFieldOrDefault(comp, 'RadialVelocityMps', NaN);
    if isfield(comp, 'ChannelFallback')
        execution.ChannelFallback = getFieldOrEmpty(comp, 'ChannelFallback', '');
    end
    if isfield(comp, 'RayCount')
        execution.RayCount = getFieldOrDefault(comp, 'RayCount', NaN);
    end
    if isfield(comp, 'ChannelInfo') && isstruct(comp.ChannelInfo)
        if isfield(comp.ChannelInfo, 'MapProfile') && isstruct(comp.ChannelInfo.MapProfile)
            execution.MapProfile = comp.ChannelInfo.MapProfile;
        end
        if ~isfield(execution, 'ChannelFallback') && isfield(comp.ChannelInfo, 'Fallback')
            execution.ChannelFallback = getFieldOrEmpty(comp.ChannelInfo, 'Fallback', '');
        end
        if ~isfield(execution, 'RayCount') && isfield(comp.ChannelInfo, 'RayCount')
            execution.RayCount = getFieldOrDefault(comp.ChannelInfo, 'RayCount', NaN);
        end
    end

    geom = struct();
    geom.TxPositionM   = getFieldOrDefault(comp, 'TxPosition', [NaN, NaN, NaN]);
    geom.TxVelocityMps = getFieldOrDefault(comp, 'TxVelocity', [NaN, NaN, NaN]);
    geom.RxPositionM   = getFieldOrDefault(comp, 'RxPosition', [NaN, NaN, NaN]);
    geom.RxVelocityMps = getFieldOrDefault(comp, 'RxVelocity', [NaN, NaN, NaN]);
    geom.EvaluationTimeSec = getFieldOrDefault(comp, ...
        'GeometryEvaluationTimeSec', NaN);
    geom.EvaluationPolicy = getFieldOrEmpty(comp, ...
        'GeometryEvaluationPolicy', '');
    if isfield(comp, 'GeometrySnapshot') && isstruct(comp.GeometrySnapshot)
        geom.SegmentMidpoint = comp.GeometrySnapshot;
    end
    geom.LinkDistanceM = getFieldOrDefault(comp, 'LinkDistance', NaN);
    execution.GeometrySnapshot = geom;
    validateExecutionSampleGrid(execution, comp);
end

function measured = buildMeasuredTruth(isolatedSignal, sampleRate, ...
        observableBwHz, comp, framePlaneCache)
    %BUILDMEASUREDTRUTH SourcePlane (isolated) + FramePlane (cached).
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    measured = struct();

    sourcePlane = struct();
    sourcePlane.OccupiedBandwidthHz  = NaN;
    sourcePlane.CenterFrequencyHz    = NaN;
    % GT principle: the Measured SNR is MEASURED from the realized signal
    % (signal power / total realized additive noise), set per emitter in the
    % receiver loop as MeasuredReceivedSNRdB. Fall back to the analytical
    % AppliedSNRdB only when the realized powers were unavailable.
    sourcePlane.SNRdB                = getFieldOrDefault(comp, 'MeasuredReceivedSNRdB', ...
        getFieldOrDefault(comp, 'AppliedSNRdB', NaN));
    sourcePlane.TimeOccupancy        = NaN;
    sourcePlane.FrequencyOccupancy   = NaN;
    sourcePlane.MeasurementSemantics = 'receiver_view_isolated';

    % Liveness is energy-based, not sample-count-based: an empty channel
    % output (e.g. a link with no propagation paths) is zero-padded to the
    % frame length by gateToDuration, producing a non-empty all-zero buffer
    % with FrameSampleCount>0. Such a silent buffer must be classified
    % NoSignal (occupied bandwidth legitimately measures 0), not a live
    % signal -- otherwise the downstream requirePositiveMeasurement would
    % reject the valid 0 and drop the whole frame.
    hasSignal = ~isempty(isolatedSignal) && size(isolatedSignal, 1) > 0 && ...
        getFieldOrDefault(comp, 'FrameSampleCount', size(isolatedSignal, 1)) > 0 && ...
        any(abs(double(isolatedSignal(:))) > 0);
    if ~hasSignal
        sourcePlane.MeasurementStatus = 'NoSignal';
    else
        sourcePlane.MeasurementStatus = 'Measured';
        sourcePlane.SNRdB = requireFiniteMeasurement( ...
            sourcePlane.SNRdB, 'Truth.Measured.SourcePlane.SNRdB');

        % Phase 21: compute OBW, center frequency, envelope, and frequency
        % occupancy from one validated signal summary. Failure remains visible
        % as CSRD:Measurement:SourceOBWFailed; legacy markers
        % CSRD:Measurement:SourceCenterFrequencyFailed and
        % CSRD:Measurement:SourceEnvelopeFailed stay here so static gates keep
        % proving live measurement failures are not silently written as NaN.
        summary = guardedMeasurement(@() ...
            csrd.pipeline.measurement.measureSignalSummary( ...
                isolatedSignal, sampleRate, observableBwHz), ...
            'CSRD:Measurement:SourceOBWFailed');
        sourcePlane.OccupiedBandwidthHz = requirePositiveMeasurement( ...
            summary.OccupiedBandwidthHz, ...
            'Truth.Measured.SourcePlane.OccupiedBandwidthHz');
        sourcePlane.CenterFrequencyHz = requireFiniteMeasurement( ...
            summary.CenterFrequencyHz, ...
            'Truth.Measured.SourcePlane.CenterFrequencyHz');
        % summary.TimeOccupancy is measured over the burst-only buffer, which is
        % clipped to the emitter's active extent -- so a continuously-modulated
        % burst reads ~1.0 regardless of how little of the frame it occupies.
        % Scale it by the burst's fraction of the frame so SourcePlane.TimeOccupancy
        % reports the emitter's activity over the whole observation window (the
        % FramePlane semantics), not within its own clipped buffer.
        bufferOccupancy = requireFiniteMeasurement( ...
            summary.TimeOccupancy, 'Truth.Measured.SourcePlane.TimeOccupancy');
        frameLenSamples = getFieldOrDefault(comp, 'FrameLengthSamples', NaN);
        frameSampleCount = getFieldOrDefault(comp, 'FrameSampleCount', NaN);
        if isnumeric(frameLenSamples) && isscalar(frameLenSamples) && isfinite(frameLenSamples) && ...
                frameLenSamples > 0 && isnumeric(frameSampleCount) && isscalar(frameSampleCount) && ...
                isfinite(frameSampleCount)
            frameFraction = min(1, max(0, double(frameSampleCount) / double(frameLenSamples)));
            sourcePlane.TimeOccupancy = min(1, max(0, bufferOccupancy * frameFraction));
        else
            sourcePlane.TimeOccupancy = bufferOccupancy;
        end
        sourcePlane.FrequencyOccupancy = requireFiniteMeasurement( ...
            summary.FrequencyOccupancy, ...
            'Truth.Measured.SourcePlane.FrequencyOccupancy');
    end

    measured.SourcePlane = sourcePlane;

    if nargin >= 5 && ~isempty(framePlaneCache) && isstruct(framePlaneCache)
        measured.FramePlane = framePlaneCache;
    else
        measured.FramePlane = makeEmptyFramePlane();
    end
end

function fp = computeFramePlaneCache(combinedSignal, sampleRate, observableBwHz)
    %COMPUTEFRAMEPLANECACHE Once-per-receiver FramePlane measurements.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    fp = makeEmptyFramePlane();
    if ~isstruct(combinedSignal) || ~isfield(combinedSignal, 'Signal') || ...
            isempty(combinedSignal.Signal)
        fp.MeasurementStatus = 'NoSignal';
        return;
    end
    if isfield(combinedSignal, 'Components') && isempty(combinedSignal.Components)
        fp.MeasurementStatus = 'NoSignal';
        return;
    end
    if isfield(combinedSignal, 'Components')
        hasLiveComponent = false;
        for k = 1:numel(combinedSignal.Components)
            comp = combinedSignal.Components{k};
            if isstruct(comp) && getFieldOrDefault(comp, 'FrameSampleCount', 0) > 0
                hasLiveComponent = true;
                break;
            end
        end
        if ~hasLiveComponent
            fp.MeasurementStatus = 'NoSignal';
            return;
        end
    end

    sig = combinedSignal.Signal;
    % Energy-based liveness (see buildMeasuredTruth): if every live-by-count
    % component contributed only zero-padding (e.g. empty channel outputs),
    % the combined buffer is silent and its occupied bandwidth legitimately
    % measures 0. Classify it NoSignal rather than letting OBW=0 trip the
    % requirePositiveMeasurement assertion and drop the frame.
    if ~any(abs(double(sig(:))) > 0)
        fp.MeasurementStatus = 'NoSignal';
        return;
    end
    fp.MeasurementStatus = 'Measured';
    % Phase 21: one summary call replaces three independent measurement
    % passes. Legacy visibility markers CSRD:Measurement:FrameCenterFrequencyFailed
    % and CSRD:Measurement:FrameEnvelopeFailed remain as comments for
    % production dead-code guards.
    summary = guardedMeasurement(@() ...
        csrd.pipeline.measurement.measureSignalSummary( ...
            sig, sampleRate, observableBwHz), ...
        'CSRD:Measurement:FrameOBWFailed');
    fp.OccupiedBandwidthHz = requirePositiveMeasurement( ...
        summary.OccupiedBandwidthHz, ...
        'Truth.Measured.FramePlane.OccupiedBandwidthHz');
    fp.CenterFrequencyHz = requireFiniteMeasurement( ...
        summary.CenterFrequencyHz, ...
        'Truth.Measured.FramePlane.CenterFrequencyHz');
    fp.TimeOccupancy = requireFiniteMeasurement( ...
        summary.TimeOccupancy, 'Truth.Measured.FramePlane.TimeOccupancy');
    fp.FrequencyOccupancy = requireFiniteMeasurement( ...
        summary.FrequencyOccupancy, ...
        'Truth.Measured.FramePlane.FrequencyOccupancy');
end

function fp = makeEmptyFramePlane()
    % makeEmptyFramePlane - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    fp = struct( ...
        'OccupiedBandwidthHz',  NaN, ...
        'CenterFrequencyHz',    NaN, ...
        'TimeOccupancy',        NaN, ...
        'FrequencyOccupancy',   NaN, ...
        'MeasurementStatus',    'NoSignal', ...
        'MeasurementSemantics', 'post_rx_combined_pre_rfchain');
end

function bwHz = computeObservableBandwidthHz(rxInfo)
    %COMPUTEOBSERVABLEBANDWIDTHHZ Resolve receiver observable BW (Hz).
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    if ~isstruct(rxInfo) || ~isfield(rxInfo, 'ObservableRange') || ...
            numel(rxInfo.ObservableRange) < 2
        error('CSRD:Receiver:MissingObservableRange', ...
            'rxInfo.ObservableRange is required for receiver-view measurement truth.');
    end
    rng = double(reshape(rxInfo.ObservableRange(1:2), 1, 2));
    if any(~isfinite(rng)) || rng(2) <= rng(1)
        error('CSRD:Receiver:InvalidObservableRange', ...
            'rxInfo.ObservableRange must be finite and increasing.');
    end
    bwHz = rng(2) - rng(1);
end

function validateExecutionSampleGrid(execution, comp)
    % validateExecutionSampleGrid - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    sampleRate = requirePositiveMeasurement(execution.SampleRate, ...
        'Truth.Execution.SampleRate');
    frameStart = requireFiniteMeasurement(execution.FrameStartSample, ...
        'Truth.Execution.FrameStartSample');
    frameEnd = requireFiniteMeasurement(execution.FrameEndSample, ...
        'Truth.Execution.FrameEndSample');
    frameCount = requireFiniteMeasurement(execution.FrameSampleCount, ...
        'Truth.Execution.FrameSampleCount');
    frameLength = requirePositiveMeasurement(execution.FrameLengthSamples, ...
        'Truth.Execution.FrameLengthSamples');
    if abs(frameStart - round(frameStart)) > 0 || ...
            abs(frameEnd - round(frameEnd)) > 0 || ...
            abs(frameCount - round(frameCount)) > 0 || ...
            abs(frameLength - round(frameLength)) > 0
        error('CSRD:Annotation:InvalidExecutionSampleGrid', ...
            'Execution sample-grid fields must be integer-valued samples.');
    end
    if frameStart < 0 || frameEnd < frameStart || frameEnd > frameLength || ...
            frameCount ~= frameEnd - frameStart
        error('CSRD:Annotation:InvalidExecutionSampleGrid', ...
            ['Execution sample-grid fields are inconsistent for TxID=%s BurstId=%s.'], ...
            char(string(getFieldOrEmpty(comp, 'TxID', ''))), ...
            char(string(getFieldOrEmpty(comp, 'BurstId', ''))));
    end
    startTimeSec = requireFiniteMeasurement(execution.StartTimeSec, ...
        'Truth.Execution.StartTimeSec');
    endTimeSec = requireFiniteMeasurement(execution.EndTimeSec, ...
        'Truth.Execution.EndTimeSec');
    durationSec = requireFiniteMeasurement(execution.DurationSec, ...
        'Truth.Execution.DurationSec');
    expectedStartSec = frameStart / sampleRate;
    expectedEndSec = frameEnd / sampleRate;
    expectedDurationSec = frameCount / sampleRate;
    timeTol = max(1 / sampleRate * 1e-6, 1e-12);
    if abs(startTimeSec - expectedStartSec) > timeTol || ...
            abs(endTimeSec - expectedEndSec) > timeTol || ...
            abs(durationSec - expectedDurationSec) > timeTol
        error('CSRD:Annotation:ExecutionSampleGridMismatch', ...
            ['Truth.Execution times must equal inserted sample-grid times ', ...
             '(Start=%g/%g, End=%g/%g, Duration=%g/%g).'], ...
            startTimeSec, expectedStartSec, ...
            endTimeSec, expectedEndSec, ...
            durationSec, expectedDurationSec);
    end
end

function value = guardedMeasurement(fn, errorId)
    % guardedMeasurement - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    try
        value = fn();
    catch ME
        error(errorId, 'Measurement failed: %s', ME.message);
    end
end

function value = requireFiniteMeasurement(value, label)
    % requireFiniteMeasurement - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
        error('CSRD:Measurement:InvalidMeasuredValue', ...
            '%s must be a finite numeric scalar for a live signal.', label);
    end
    value = double(value);
end

function value = requirePositiveMeasurement(value, label)
    % requirePositiveMeasurement - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    value = requireFiniteMeasurement(value, label);
    if value <= 0
        error('CSRD:Measurement:InvalidMeasuredValue', ...
            '%s must be positive for a live signal.', label);
    end
end

function value = getFieldOrDefault(s, fieldName, defaultValue)
    % getFieldOrDefault - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end

function value = getFieldOrEmpty(s, fieldName, defaultValue)
    % getFieldOrEmpty - Production declaration in CSRD.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end

function snrDb = localMeasuredReceivedSnr(comp, thermalNoiseW, quantNoiseW)
    % localMeasuredReceivedSnr - Measured per-emitter received SNR (dB): the
    % realized per-emitter signal power over the total realized additive noise
    % (channel noise + receiver thermal noise + ADC quantization noise). Returns
    % NaN when the realized powers are unavailable so the caller falls back to
    % the analytical label.
    snrDb = NaN;
    sigW = getFieldOrDefault(comp, 'ChannelSignalPowerW', NaN);
    if ~isnumeric(sigW) || ~isscalar(sigW) || ~isfinite(sigW)
        return;
    end
    chanNoiseW = getFieldOrDefault(comp, 'ChannelNoisePowerW', NaN);
    totalNoiseW = 0; haveNoise = false;
    if isnumeric(chanNoiseW) && isscalar(chanNoiseW) && isfinite(chanNoiseW)
        totalNoiseW = totalNoiseW + double(chanNoiseW); haveNoise = true;
    end
    if isnumeric(thermalNoiseW) && isscalar(thermalNoiseW) && isfinite(thermalNoiseW)
        totalNoiseW = totalNoiseW + double(thermalNoiseW); haveNoise = true;
    end
    if nargin >= 3 && isnumeric(quantNoiseW) && isscalar(quantNoiseW) && isfinite(quantNoiseW)
        totalNoiseW = totalNoiseW + double(quantNoiseW); haveNoise = true;
    end
    if ~haveNoise || ~(totalNoiseW > 0)
        return;
    end
    snrDb = csrd.pipeline.measurement.actualSnrFromComponents(double(sigW), totalNoiseW);
    if ~isfinite(snrDb)
        snrDb = NaN;   % keep the finite-measurement contract; fall back to label
    end
end

function combinedSignal = combineSignalComponents(obj, rxSignals, rxInfo)
    % combineSignalComponents - Combine multiple signal components at receiver
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    % Aggregates signal components with time-alignment based on StartTime.
    % Each component's StartTime determines its position in the output buffer.

    sampleRate = rxInfo.SampleRate;
    signalComponents = {};
    if isstruct(rxSignals) && isfield(rxSignals, 'SignalComponents') && ...
            ~isempty(rxSignals.SignalComponents)
        signalComponents = rxSignals.SignalComponents;
    end

    frameShape = localResolveFrameShape(obj, signalComponents, sampleRate);

    combinedSignal = struct();
    combinedSignal.Signal = complex(zeros(frameShape.NumSamples, 1));
    combinedSignal.Components = {};
    combinedSignal.FrameShape = frameShape;

    if isempty(signalComponents)
        obj.logger.debug("RxID %s: No signal components, generating fixed empty frame.", string(rxInfo.ID));
        return;
    end

    for compIdx = 1:length(signalComponents)
        comp = signalComponents{compIdx};
        if isfield(comp, 'Signal') && ~isempty(comp.Signal)
            startOffset = localFrameStartOffset(comp, sampleRate, frameShape.NumSamples);
            compSig = localCollapseAntennaSignal(comp.Signal);
            if startOffset >= frameShape.NumSamples
                comp = localUpdateComponentSampleGrid( ...
                    comp, complex(zeros(0, 1)), startOffset, ...
                    frameShape.NumSamples, sampleRate);
                combinedSignal.Components{end + 1} = comp; %#ok<AGROW>
                continue;
            end
            usableLen = min(size(compSig, 1), frameShape.NumSamples - startOffset);
            if usableLen < 0
                usableLen = 0;
            end
            compSig = compSig(1:usableLen, :);
            idxStart = startOffset + 1;
            idxEnd = startOffset + usableLen;
            if usableLen > 0
                combinedSignal.Signal(idxStart:idxEnd) = ...
                    combinedSignal.Signal(idxStart:idxEnd) + compSig;
            end
            comp = localUpdateComponentSampleGrid( ...
                comp, compSig, startOffset, frameShape.NumSamples, sampleRate);
            combinedSignal.Components{end + 1} = comp; %#ok<AGROW>
        else
            combinedSignal.Components{end + 1} = comp; %#ok<AGROW>
        end
    end
end

function frameShape = localResolveFrameShape(obj, signalComponents, sampleRate)
    % localResolveFrameShape - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    frameWindow = localFrameWindowFromComponents(signalComponents);
    if isempty(obj.ScenarioPlan) || ~isstruct(obj.ScenarioPlan) || ...
            ~isfield(obj.ScenarioPlan, 'Frame') || ...
            ~isstruct(obj.ScenarioPlan.Frame)
        error('CSRD:ScenarioPlan:MissingFrameContract', ...
            'ScenarioPlan.Frame is required to resolve receiver frame shape.');
    end
    contract = obj.ScenarioPlan.Frame;
    if ~isempty(frameWindow)
        localAssertFrameWindowMatchesPlan(frameWindow, ...
            contract.FrameNumSamples, sampleRate);
    end
    frameSamples = contract.FrameNumSamples;
    frameShape = struct( ...
        'NumSamples', frameSamples, ...
        'DurationSec', frameSamples / sampleRate, ...
        'SampleRate', sampleRate, ...
        'Source', getFieldOrEmpty(contract, 'Source', 'ScenarioPlan.Frame'));
end

function localAssertFrameWindowMatchesPlan(frameWindow, frameSamples, sampleRate)
    % localAssertFrameWindowMatchesPlan - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    if any(~isfinite(frameWindow)) || numel(frameWindow) < 2 || ...
            frameWindow(2) <= frameWindow(1)
        error('CSRD:Frame:InvalidFrameWindow', ...
            'FrameWindow must be a finite [start end] vector in seconds.');
    end
    computedSamples = (frameWindow(2) - frameWindow(1)) * sampleRate;
    if abs(computedSamples - frameSamples) > 1
        error('CSRD:Frame:InconsistentFrameSamples', ...
            'SignalComponents.FrameWindow resolves to %g samples but ScenarioPlan.Frame.FrameNumSamples is %d.', ...
            computedSamples, frameSamples);
    end
end

function frameWindow = localFrameWindowFromComponents(signalComponents)
    % localFrameWindowFromComponents - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    frameWindow = [];
    for k = 1:numel(signalComponents)
        comp = signalComponents{k};
        if isstruct(comp) && isfield(comp, 'FrameWindow') && ...
                numel(comp.FrameWindow) >= 2 && ...
                all(isfinite(double(comp.FrameWindow(1:2))))
            candidate = double(comp.FrameWindow(1:2));
            if candidate(2) > candidate(1)
                frameWindow = candidate;
                return;
            end
        end
    end
end

function comp = localUpdateComponentSampleGrid(comp, compSig, startOffset, ...
        frameSamples, sampleRate)
            % localUpdateComponentSampleGrid - CSRD MATLAB declaration.
            % Inputs: see function signature and validation.
            % Outputs: see return values and contract fields.
    sampleCount = size(compSig, 1);
    gridStart = min(startOffset, frameSamples);
    endOffset = max(gridStart, min(frameSamples, startOffset + sampleCount));
    comp.Signal = compSig;
    comp.FrameStartSample = gridStart;
    comp.FrameEndSample = endOffset;
    comp.FrameSampleCount = max(0, endOffset - gridStart);
    comp.FrameLengthSamples = frameSamples;
    comp.FrameRelativeStartTime = gridStart / sampleRate;
    comp.FrameRelativeEndTime = endOffset / sampleRate;
    comp.ExecutionSampleGrid = struct( ...
        'StartSample', comp.FrameStartSample, ...
        'EndSample', comp.FrameEndSample, ...
        'SampleCount', comp.FrameSampleCount, ...
        'FrameLengthSamples', frameSamples, ...
        'SampleRate', sampleRate);
end

function [signalOut, info] = localCoerceProcessedFrameLength(signalIn, targetSamples)
    % localCoerceProcessedFrameLength - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    if isempty(signalIn)
        signalIn = complex(zeros(0, 1));
    elseif isvector(signalIn)
        signalIn = signalIn(:);
    end
    inputSamples = size(signalIn, 1);
    numCols = max(1, size(signalIn, 2));
    action = 'none';
    if inputSamples > targetSamples
        signalOut = signalIn(1:targetSamples, :);
        action = 'trim';
    elseif inputSamples < targetSamples
        signalOut = [signalIn; complex(zeros(targetSamples - inputSamples, numCols))];
        action = 'pad';
    else
        signalOut = signalIn;
    end
    info = struct( ...
        'InputSamples', inputSamples, ...
        'OutputSamples', size(signalOut, 1), ...
        'TargetSamples', targetSamples, ...
        'Action', action);
end

function startOffset = localFrameStartOffset(comp, sampleRate, frameSamples)
    % localFrameStartOffset - Convert source start time into frame samples.
    % Inputs: component struct, receiver sample rate, frame length in samples.
    % Outputs: zero-based sample offset inside the current frame.
    startTime = 0;
    if isfield(comp, 'FrameRelativeStartTime') && ~isempty(comp.FrameRelativeStartTime)
        startTime = comp.FrameRelativeStartTime;
    elseif isfield(comp, 'StartTime') && ~isempty(comp.StartTime)
        startTime = comp.StartTime;
    end
    rawOffset = double(startTime) * sampleRate;
    startOffset = max(0, round(rawOffset));
    % A burst whose start lies strictly inside the frame must not be rounded
    % onto/past the frame end -- that would make combineSignalComponents drop
    % the whole burst even though the planner placed it here with overlap.
    % Clamp such a rounding overshoot to the last valid sample; only a start
    % that truly reaches the frame end (floor >= frameSamples) stays out of
    % range and is dropped.
    if startOffset >= frameSamples && floor(rawOffset) < frameSamples
        startOffset = frameSamples - 1;
    end
end

function y = localCollapseAntennaSignal(signal)
    % localCollapseAntennaSignal - Convert [samples x antennas] into one monitor stream.
    % Inputs: signal matrix from the channel component.
    % Outputs: column vector aligned to the receiver time axis.
    if isempty(signal)
        y = complex(zeros(0, 1));
        return;
    end
    if isvector(signal)
        y = signal(:);
    else
        y = sum(signal, 2);
    end
end
