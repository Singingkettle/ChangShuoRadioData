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

            % Phase 4 (audit §17.6 / H17): compute the FramePlane
            % measurements once per receiver from the combined waveform
            % (post Rx-combination, pre Rx RF chain). Each SignalSource
            % then references this cache so we never re-run obw on the
            % same combined buffer N times.
            observableBwHz = computeObservableBandwidthHz(rxInfo);
            framePlaneCache = computeFramePlaneCache( ...
                combinedSignal, rxInfo.SampleRate, observableBwHz);

            FrameAnnotation{rxIdx}.SignalSources = [];
            for compIdx = 1:length(rxSignals.SignalComponents)
                comp = rxSignals.SignalComponents{compIdx};
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
                FrameId, string(rxInfo.ID), length(rxSignals.SignalComponents));

        catch ME_rx
            obj.logger.error("Frame %d, Rx %s: Receiver processing error: %s", ...
                FrameId, string(rxInfo.ID), ME_rx.message);
            rethrow(ME_rx);
        end
    end

    obj.logger.debug("Frame %d: All receiver processing complete.", FrameId);
end

function sourceInfo = buildSourceAnnotation(comp, isolatedSignal, ...
        sampleRate, observableBwHz, framePlaneCache)
    %BUILDSOURCEANNOTATION Phase 4 v2 schema (annotation full-replacement).
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
    design.ModulationFamily  = getFieldOrEmpty(plannedSrc, 'ModulationFamily', '');
    design.ModulationOrder   = getFieldOrDefault(plannedSrc, 'ModulationOrder', NaN);
    design.PayloadLengthBits = getFieldOrDefault(plannedSrc, 'PayloadLengthBits', NaN);
    design.NumTransmitAntennas = getFieldOrDefault(plannedSrc, 'NumTransmitAntennas', NaN);
end

function execution = buildExecutionTruth(comp)
    %BUILDEXECUTIONTRUTH Construction-layer ground truth (post-channel).
    %
    %   Phase 4 §3.4 / §6 C8: `ModulatedBandwidthHz` is now the
    %   `obwActual` measurement performed in `processChannelPropagation`
    %   on the **clean** modulator output (zero AWGN); the legacy
    %   modulator-analytical scalar is preserved on the side as
    %   `AnalyticalBandwidthHz` so historical baselines can still be
    %   compared. If the measurement is absent for any reason the
    %   analytical value remains the fallback (still scalar Hz).
    execution = struct();
    measuredBwHz = getFieldOrDefault(comp, 'ModulatedBandwidthHz', NaN);
    if ~isfinite(measuredBwHz) || measuredBwHz <= 0
        measuredBwHz = getFieldOrDefault(comp, 'AnalyticalBandwidthHz', NaN);
        if ~isfinite(measuredBwHz) || measuredBwHz <= 0
            measuredBwHz = getFieldOrDefault(comp, 'Bandwidth', NaN);
        end
    end
    execution.ModulatedBandwidthHz    = measuredBwHz;
    execution.AnalyticalBandwidthHz   = getFieldOrDefault(comp, 'AnalyticalBandwidthHz', ...
        getFieldOrDefault(comp, 'Bandwidth', NaN));
    execution.CenterFrequencyOffsetHz = getFieldOrDefault(comp, 'FrequencyOffset', NaN);
    execution.SampleRate              = getFieldOrDefault(comp, 'SampleRate', NaN);
    execution.ChannelModel            = getFieldOrEmpty(comp, 'ChannelModel', '');
    execution.PathLossDB              = getFieldOrDefault(comp, 'PathLoss', NaN);
    execution.AnalyticalSNRdB         = getFieldOrDefault(comp, 'ComputedSNR', NaN);
    execution.AppliedSNRdB            = getFieldOrDefault(comp, 'AppliedSNRdB', NaN);
    execution.DopplerShiftHz          = getFieldOrDefault(comp, 'DopplerShiftHz', NaN);
    execution.RadialVelocityMps       = getFieldOrDefault(comp, 'RadialVelocityMps', NaN);

    geom = struct();
    geom.TxPositionM   = getFieldOrDefault(comp, 'TxPosition', [NaN, NaN, NaN]);
    geom.TxVelocityMps = getFieldOrDefault(comp, 'TxVelocity', [NaN, NaN, NaN]);
    geom.RxPositionM   = getFieldOrDefault(comp, 'RxPosition', [NaN, NaN, NaN]);
    geom.LinkDistanceM = getFieldOrDefault(comp, 'LinkDistance', NaN);
    execution.GeometrySnapshot = geom;
end

function measured = buildMeasuredTruth(isolatedSignal, sampleRate, ...
        observableBwHz, comp, framePlaneCache)
    %BUILDMEASUREDTRUTH SourcePlane (isolated) + FramePlane (cached).
    measured = struct();

    sourcePlane = struct();
    sourcePlane.OccupiedBandwidthHz  = NaN;
    sourcePlane.CenterFrequencyHz    = NaN;
    sourcePlane.SNRdB                = getFieldOrDefault(comp, 'AppliedSNRdB', NaN);
    sourcePlane.TimeOccupancy        = NaN;
    sourcePlane.FrequencyOccupancy   = NaN;
    sourcePlane.MeasurementSemantics = 'receiver_view_isolated';

    if ~isempty(isolatedSignal)
        try
            % Phase 4 (audit §17.6 / §6 C8): default 99 %-energy OBW
            % with peak-relative thresholding. `obwActual` masks bins
            % below `peak * 10^(-3/10)` (i.e. -3 dBc, the half-power
            % main-lobe footprint) before the energy-mass search. The
            % previous 25 %-percentile noise-floor estimator was
            % retired in baseline_v0 because it produced a per-source
            % threshold that drifted with SNR -- the **clean** modulator
            % output (`Truth.Execution.ModulatedBandwidthHz`) bottomed
            % out near FFT-leakage levels (~-30 dBc) while the noisy
            % receiver waveform converged on the noise floor (~-6 dBc
            % at 6 dB SNR), making the C8 < 3 % gate physically
            % infeasible. The peak-relative threshold floats with the
            % signal peak, so clean and noisy measurements of the same
            % modulator output agree to <2 % across SNR in [6, 20] dB
            % (validated by tools/phase4/diag_phase4_rrc_obw on RRC
            % QPSK and OFDM cohorts).
            sourcePlane.OccupiedBandwidthHz = ...
                csrd.utils.measurement.obwActual(isolatedSignal, sampleRate);
        catch
            sourcePlane.OccupiedBandwidthHz = NaN;
        end
        try
            sourcePlane.CenterFrequencyHz = ...
                csrd.utils.measurement.spectrumCentroid(isolatedSignal, sampleRate);
        catch
            sourcePlane.CenterFrequencyHz = NaN;
        end
        try
            envInfo = csrd.utils.measurement.detectBurstEnvelope( ...
                isolatedSignal, sampleRate);
            sourcePlane.TimeOccupancy = envInfo.TimeOccupancy;
        catch
            sourcePlane.TimeOccupancy = NaN;
        end
        try
            sourcePlane.FrequencyOccupancy = ...
                csrd.utils.measurement.frequencyOccupancy( ...
                    sourcePlane.OccupiedBandwidthHz, observableBwHz);
        catch
            sourcePlane.FrequencyOccupancy = NaN;
        end
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
    fp = makeEmptyFramePlane();
    if ~isstruct(combinedSignal) || ~isfield(combinedSignal, 'Signal') || ...
            isempty(combinedSignal.Signal)
        return;
    end

    sig = combinedSignal.Signal;
    try
        % Phase 4 (audit §17.6 / §6 C8): default 99 %-energy OBW with
        % peak-relative thresholding (-3 dBc; see `buildMeasuredTruth`
        % for the rationale). The FramePlane combined waveform stacks
        % multiple emitters' AWGN, so a percentile-based floor estimate
        % would have drifted with the per-frame interferer mix; the
        % peak-relative threshold floats with the dominant emitter and
        % keeps the reported bandwidth tied to the signal envelope
        % rather than the receiver's Nyquist edge.
        fp.OccupiedBandwidthHz = csrd.utils.measurement.obwActual(sig, sampleRate);
    catch
        fp.OccupiedBandwidthHz = NaN;
    end
    try
        fp.CenterFrequencyHz = csrd.utils.measurement.spectrumCentroid(sig, sampleRate);
    catch
        fp.CenterFrequencyHz = NaN;
    end
    try
        envInfo = csrd.utils.measurement.detectBurstEnvelope(sig, sampleRate);
        fp.TimeOccupancy = envInfo.TimeOccupancy;
    catch
        fp.TimeOccupancy = NaN;
    end
    try
        fp.FrequencyOccupancy = csrd.utils.measurement.frequencyOccupancy( ...
            fp.OccupiedBandwidthHz, observableBwHz);
    catch
        fp.FrequencyOccupancy = NaN;
    end
end

function fp = makeEmptyFramePlane()
    fp = struct( ...
        'OccupiedBandwidthHz',  NaN, ...
        'CenterFrequencyHz',    NaN, ...
        'TimeOccupancy',        NaN, ...
        'FrequencyOccupancy',   NaN, ...
        'MeasurementSemantics', 'post_rx_combined_pre_rfchain');
end

function bwHz = computeObservableBandwidthHz(rxInfo)
    %COMPUTEOBSERVABLEBANDWIDTHHZ Resolve receiver observable BW (Hz).
    bwHz = NaN;
    if isfield(rxInfo, 'ObservableRange') && numel(rxInfo.ObservableRange) >= 2
        rng = rxInfo.ObservableRange;
        bwHz = abs(rng(2) - rng(1));
    elseif isfield(rxInfo, 'SampleRate') && rxInfo.SampleRate > 0
        bwHz = rxInfo.SampleRate;
    end
end

function value = getFieldOrDefault(s, fieldName, defaultValue)
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end

function value = getFieldOrEmpty(s, fieldName, defaultValue)
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    else
        value = defaultValue;
    end
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

