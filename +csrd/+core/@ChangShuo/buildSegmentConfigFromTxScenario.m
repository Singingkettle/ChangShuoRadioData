function segmentConfig = buildSegmentConfigFromTxScenario(txScenario, segIdx)
    %BUILDSEGMENTCONFIGFROMTXSCENARIO Phase 3 strict-construction segment builder.
    %
    %   segmentConfig = csrd.core.ChangShuo.buildSegmentConfigFromTxScenario( ...
    %       txScenario, segIdx)
    %
    %   Builds the per-segment execution config from the upstream
    %   TxPlan struct emitted by CommunicationBehaviorSimulator. The
    %   helper is the canonical Phase 3 fail-fast surface for the
    %   message / modulation / spectrum / receiver-view contract; all
    %   missing fields raise CSRD:Construction:Missing* identifiers
    %   instead of falling back to PSK / RandomBit / 1024 / 4 magic
    %   constants (those silent fallbacks were removed under
    %   phase-3-construction.md §3.2.A).
    %
    %   Returns [] when:
    %     * `txScenario.Temporal.Intervals` is missing (caller already
    %       has no segments to build), OR
    %     * the requested `segIdx` is past the number of intervals
    %       (caller iterates past the last segment).
    %
    %   In both of those benign control-flow cases the caller decides
    %   to skip; they are NOT planner errors.

    segmentConfig = struct();

    if ~isfield(txScenario, 'Temporal') || ~isfield(txScenario.Temporal, 'Intervals')
        segmentConfig = [];
        return;
    end

    intervals = txScenario.Temporal.Intervals;
    if segIdx > size(intervals, 1)
        segmentConfig = [];
        return;
    end

    startTime = intervals(segIdx, 1);
    endTime = intervals(segIdx, 2);
    originalStartTime = startTime;
    originalEndTime = endTime;

    frameWindow = [0, 0];
    if isfield(txScenario, 'TransmissionState') && ...
            isstruct(txScenario.TransmissionState) && ...
            isfield(txScenario.TransmissionState, 'FrameWindow') && ...
            numel(txScenario.TransmissionState.FrameWindow) >= 2
        frameWindow = double(txScenario.TransmissionState.FrameWindow(1:2));
    end
    if isfield(txScenario, 'TransmissionState') && ...
            isstruct(txScenario.TransmissionState) && ...
            isfield(txScenario.TransmissionState, 'ActiveIntervals') && ...
            size(txScenario.TransmissionState.ActiveIntervals, 1) >= 1
        activePositions = find(double(txScenario.TransmissionState.ActiveIntervalIndices(:)) == segIdx, 1, 'first');
        if ~isempty(activePositions)
            clipped = double(txScenario.TransmissionState.ActiveIntervals(activePositions, :));
            startTime = clipped(1);
            endTime = clipped(2);
        end
    end
    duration = endTime - startTime;
    if localDurationResolvesToNoSamples(txScenario, duration)
        segmentConfig = [];
        return;
    end

    % --- Message ---------------------------------------------------------
    % Upstream contract (generateScenarioTransmitterConfigurations ->
    % generateMessageConfig) populates `txPlan.Message.Type` and
    % `txPlan.Message.Length` for every emitter. Anything missing here
    % is a planner-side regression and must crash the segment build
    % instead of being papered over with the legacy `RandomBit / 1024`
    % defaults.
    if ~isfield(txScenario, 'Message') || ~isstruct(txScenario.Message)
        error('CSRD:Construction:MissingMessageConfig', ...
            ['buildSegmentConfigFromTxScenario: txScenario.Message is required ', ...
             '(struct with Type and Length); the legacy ', ...
             '''RandomBit/1024'' fallback was removed in Phase 3.']);
    end
    if ~isfield(txScenario.Message, 'Type') && ~isfield(txScenario.Message, 'TypeID')
        error('CSRD:Construction:MissingMessageType', ...
            ['buildSegmentConfigFromTxScenario: txScenario.Message must carry a ', ...
             '''Type'' (or legacy ''TypeID'') field; the implicit ', ...
             '''RandomBit'' default was removed in Phase 3.']);
    end
    if ~isfield(txScenario.Message, 'Length') || isempty(txScenario.Message.Length) ...
            || ~isnumeric(txScenario.Message.Length) || txScenario.Message.Length <= 0
        error('CSRD:Construction:MissingMessageLength', ...
            ['buildSegmentConfigFromTxScenario: txScenario.Message.Length is ', ...
             'required and must be a positive scalar; the implicit ', ...
             '1024 default was removed in Phase 3.']);
    end
    segmentConfig.Message = txScenario.Message;
    if isfield(txScenario.Message, 'Type')
        segmentConfig.Message.TypeID = txScenario.Message.Type;
    else
        segmentConfig.Message.TypeID = txScenario.Message.TypeID;
    end

    % --- Modulation ------------------------------------------------------
    % `generateModulationConfig` populates `txPlan.Modulation` with
    % `.Type / .Order / .SymbolRate / .SamplesPerSymbol / .BitsPerSymbol`
    % unconditionally. Missing fields here are a planner regression
    % and must crash the segment build instead of being papered over
    % with the legacy `PSK / Order=4 / SymbolRate=100kHz / SPS=4`
    % magic constants.
    if ~isfield(txScenario, 'Modulation') || ~isstruct(txScenario.Modulation)
        error('CSRD:Construction:MissingModulationConfig', ...
            ['buildSegmentConfigFromTxScenario: txScenario.Modulation is required ', ...
             '(struct with Type, Order, SymbolRate, SamplesPerSymbol); ', ...
             'the legacy PSK/QPSK/100kHz/SPS=4 fallback was removed in ', ...
             'Phase 3.']);
    end
    if ~isfield(txScenario.Modulation, 'Type') && ~isfield(txScenario.Modulation, 'TypeID')
        error('CSRD:Construction:MissingModulationType', ...
            ['buildSegmentConfigFromTxScenario: txScenario.Modulation must carry a ', ...
             '''Type'' (or legacy ''TypeID'') field; the implicit ', ...
             '''PSK'' default was removed in Phase 3.']);
    end
    if ~isfield(txScenario.Modulation, 'SymbolRate') ...
            || isempty(txScenario.Modulation.SymbolRate) ...
            || ~isnumeric(txScenario.Modulation.SymbolRate) ...
            || txScenario.Modulation.SymbolRate <= 0
        error('CSRD:Construction:MissingModulationSymbolRate', ...
            ['buildSegmentConfigFromTxScenario: txScenario.Modulation.SymbolRate ', ...
             'is required (positive scalar); upstream blueprint must ', ...
             'derive it from PlannedBandwidth / RolloffFactor in ', ...
             'Phase 3.']);
    end
    segmentConfig.Modulation = txScenario.Modulation;
    if isfield(txScenario.Modulation, 'Type')
        segmentConfig.Modulation.TypeID = txScenario.Modulation.Type;
    else
        segmentConfig.Modulation.TypeID = txScenario.Modulation.TypeID;
    end
    segmentConfig.Message.Duration = duration;
    segmentConfig.Message.Length = localPerSegmentMessageLength( ...
        txScenario.Message, txScenario.Modulation, duration);
    segmentConfig.Message.LengthDerivation = 'PerSegmentDuration';
    if ~isfield(txScenario, 'Hardware') || ~isstruct(txScenario.Hardware) || ...
            ~isfield(txScenario.Hardware, 'NumAntennas') || ...
            isempty(txScenario.Hardware.NumAntennas) || ...
            ~isnumeric(txScenario.Hardware.NumAntennas) || ...
            ~isscalar(txScenario.Hardware.NumAntennas) || ...
            txScenario.Hardware.NumAntennas <= 0
        error('CSRD:Construction:MissingTxNumAntennas', ...
            ['buildSegmentConfigFromTxScenario: txScenario.Hardware.NumAntennas ', ...
             'is required so the modulator, channel, and annotation share ', ...
             'the same Tx antenna count.']);
    end
    segmentConfig.Modulation.NumTransmitAntennas = ...
        double(txScenario.Hardware.NumAntennas);

    % --- Placement -------------------------------------------------------
    % Phase 3 (audit §3.1.ter A / phase-3-construction.md §3.1):
    % downstream consumers MUST read the per-Rx ReceiverView
    % projection rather than the emitter-global
    % Spectrum.PlannedFreqOffset. In the Phase 3 unified-receiver
    % contract every ReceiverView shares the same
    % ProjectedCenterOffsetHz, so picking ReceiverViews(1) is
    % canonical at the modulator stage (which has no rxIdx context).
    % Phase 4 will introduce true heterogeneous receivers; only the
    % per-Rx consumers (processChannelPropagation) need to switch to
    % ReceiverViews(rxIdx) at that point.
    segmentConfig.Placement = struct();
    segmentConfig.Placement.StartTime = startTime;
    segmentConfig.Placement.Duration = duration;
    segmentConfig.Placement.EndTime = endTime;
    segmentConfig.Placement.OriginalStartTime = originalStartTime;
    segmentConfig.Placement.OriginalEndTime = originalEndTime;
    segmentConfig.Placement.FrameWindow = frameWindow;
    segmentConfig.Placement.FrameRelativeStartTime = max(0, startTime - frameWindow(1));
    segmentConfig.Placement.FrameRelativeEndTime = max( ...
        segmentConfig.Placement.FrameRelativeStartTime, endTime - frameWindow(1));
    segmentConfig.Placement.MidpointTime = startTime + duration / 2;
    segmentConfig.Placement.GeometryEvaluationTimeSec = ...
        segmentConfig.Placement.MidpointTime;
    segmentConfig.Placement.GeometryEvaluationPolicy = 'SegmentMidpoint';

    if ~isfield(txScenario, 'ReceiverViews') || isempty(txScenario.ReceiverViews) ...
            || ~isstruct(txScenario.ReceiverViews) ...
            || ~isfield(txScenario.ReceiverViews(1), 'ProjectedCenterOffsetHz')
        error('CSRD:Construction:MissingReceiverViews', ...
            ['buildSegmentConfigFromTxScenario: txScenario must carry a non-empty ', ...
             'ReceiverViews struct with ProjectedCenterOffsetHz; the ', ...
             'emitter-global Spectrum.PlannedFreqOffset is no longer the ', ...
             'source of truth in Phase 3.']);
    end
    projectedOffset = txScenario.ReceiverViews(1).ProjectedCenterOffsetHz;
    if isempty(projectedOffset) || ~isnumeric(projectedOffset) || ~isscalar(projectedOffset)
        error('CSRD:Construction:MissingProjectedCenterOffset', ...
            ['buildSegmentConfigFromTxScenario: ReceiverViews(1).ProjectedCenterOffsetHz ', ...
             'is required (scalar numeric).']);
    end
    segmentConfig.Placement.FrequencyOffset = projectedOffset;

    if ~isfield(txScenario, 'Spectrum') || ~isstruct(txScenario.Spectrum) ...
            || ~isfield(txScenario.Spectrum, 'PlannedBandwidth') ...
            || isempty(txScenario.Spectrum.PlannedBandwidth) ...
            || txScenario.Spectrum.PlannedBandwidth <= 0
        error('CSRD:Construction:MissingPlannedBandwidth', ...
            ['buildSegmentConfigFromTxScenario: txScenario.Spectrum.PlannedBandwidth ', ...
             'is required (received empty / non-positive).']);
    end
    segmentConfig.Placement.TargetBandwidth = txScenario.Spectrum.PlannedBandwidth;
end

function tf = localDurationResolvesToNoSamples(txScenario, durationSec)
    % localDurationResolvesToNoSamples - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    tf = false;
    if isempty(durationSec) || ~isnumeric(durationSec) || ...
            ~isscalar(durationSec) || ~isfinite(durationSec) || ...
            durationSec < 0
        return;
    end
    if durationSec == 0
        tf = true;
        return;
    end
    sampleRate = NaN;
    if isfield(txScenario, 'Spectrum') && isstruct(txScenario.Spectrum) && ...
            isfield(txScenario.Spectrum, 'ReceiverSampleRate') && ...
            isnumeric(txScenario.Spectrum.ReceiverSampleRate) && ...
            isscalar(txScenario.Spectrum.ReceiverSampleRate) && ...
            isfinite(txScenario.Spectrum.ReceiverSampleRate) && ...
            txScenario.Spectrum.ReceiverSampleRate > 0
        sampleRate = double(txScenario.Spectrum.ReceiverSampleRate);
    end
    if ~isfinite(sampleRate)
        return;
    end
    tf = round(double(durationSec) * sampleRate) == 0;
end

function lengthBits = localPerSegmentMessageLength(messageConfig, modulationConfig, durationSec)
    % localPerSegmentMessageLength - Derive payload bits from this segment.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
    if isfield(messageConfig, 'LengthMin') && ~isempty(messageConfig.LengthMin)
        lengthMin = double(messageConfig.LengthMin);
    else
        lengthMin = double(messageConfig.Length);
    end
    if isfield(messageConfig, 'LengthMax') && ~isempty(messageConfig.LengthMax)
        lengthMax = double(messageConfig.LengthMax);
    else
        lengthMax = double(messageConfig.Length);
    end
    if lengthMax < lengthMin
        error('CSRD:Construction:InvalidMessageLengthBounds', ...
            'Message length bounds must satisfy LengthMin <= LengthMax.');
    end
    if ~isfield(modulationConfig, 'BitsPerSymbol') || ...
            isempty(modulationConfig.BitsPerSymbol) || ...
            ~isnumeric(modulationConfig.BitsPerSymbol) || ...
            modulationConfig.BitsPerSymbol <= 0
        error('CSRD:Construction:MissingModulationBitsPerSymbol', ...
            ['Modulation.BitsPerSymbol is required to derive per-segment ', ...
             'message length. Do not fall back to 1 bit/symbol.']);
    end
    bitsPerSymbol = double(modulationConfig.BitsPerSymbol);
    calculatedLength = ceil(double(modulationConfig.SymbolRate) * ...
        bitsPerSymbol * double(durationSec) * 1.1);
    lengthBits = max(lengthMin, min(lengthMax, calculatedLength));
end
