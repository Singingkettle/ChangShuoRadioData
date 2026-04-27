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
    duration = endTime - startTime;

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
