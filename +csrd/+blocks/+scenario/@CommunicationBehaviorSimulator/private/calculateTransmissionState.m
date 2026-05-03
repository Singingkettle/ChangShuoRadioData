function transmissionState = calculateTransmissionState(obj, frameId, txConfig)
    %CALCULATETRANSMISSIONSTATE Compute the per-frame transmission state.
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 calculateTransmissionState 实现。
    %
    %   The state is the *only* contract the downstream segment-generation
    %   code is allowed to consume. After the v0.4 deep refactor it carries
    %   exactly four fields, all required:
    %
    %       IsActive              logical scalar
    %       ActiveIntervalIndices 1xK uint32, indices into pattern.Intervals
    %       ActiveIntervals       Kx2 double, [segStart, segEnd] in seconds,
    %                             clipped to the current frame window
    %       FrameWindow           1x2 double, [frameStart, frameEnd]
    %
    %   Empty K=0 means the transmitter is silent for this frame. There are
    %   no scalar-only legacy fields (StartTime / Duration /
    %   CurrentIntervalIdx) — every consumer must walk
    %   ActiveIntervalIndices/ActiveIntervals as arrays.

    transmissionState = struct();
    transmissionState.IsActive = false;
    transmissionState.ActiveIntervalIndices = uint32([]);
    transmissionState.ActiveIntervals = zeros(0, 2);
    transmissionState.FrameWindow = [0, 0];

    if isfield(txConfig, 'Temporal') && isstruct(txConfig.Temporal)
        pattern = txConfig.Temporal;
    else
        error('CSRD:Scenario:MissingTemporalPattern', ...
            ['Frame %d: txConfig is missing the Temporal pattern struct. ' ...
             'CommunicationBehaviorSimulator must produce one when planning ' ...
             'the scenario.'], frameId);
    end

    if ~isfield(pattern, 'Type') || isempty(pattern.Type)
        error('CSRD:Scenario:MissingTemporalPatternType', ...
            'Frame %d: txConfig.Temporal lacks a non-empty Type.', frameId);
    end
    patternType = char(pattern.Type);

    switch patternType
        case 'Continuous'
            if ~isfield(pattern, 'ObservationDuration') || ...
                    ~isnumeric(pattern.ObservationDuration) || ...
                    pattern.ObservationDuration <= 0
                error('CSRD:Scenario:MissingObservationDuration', ...
                    ['Frame %d: Continuous pattern requires a positive ' ...
                     'ObservationDuration.'], frameId);
            end
            transmissionState.IsActive = true;
            transmissionState.ActiveIntervalIndices = uint32(1);
            transmissionState.ActiveIntervals = [0, pattern.ObservationDuration];
            transmissionState.FrameWindow = [0, pattern.ObservationDuration];

        case {'Burst', 'Scheduled', 'Random', 'Explicit'}
            if ~isfield(pattern, 'Intervals') || isempty(pattern.Intervals)
                error('CSRD:Scenario:MissingIntervals', ...
                    ['Frame %d: pattern type "%s" requires a non-empty ' ...
                     'Intervals matrix; the planner left it empty.'], ...
                    frameId, patternType);
            end
            [activeIdx, activeIntervals, frameWindow] = ...
                csrd.pipeline.scenario.findOverlappingTransmissionIntervals( ...
                    frameId, pattern);
            transmissionState.FrameWindow = frameWindow;
            transmissionState.ActiveIntervalIndices = uint32(activeIdx);
            transmissionState.ActiveIntervals = activeIntervals;
            transmissionState.IsActive = ~isempty(activeIdx);

        otherwise
            error('CSRD:Scenario:UnknownPatternType', ...
                'Frame %d: unknown transmission pattern type "%s".', ...
                frameId, patternType);
    end

    obj.logger.debug(['Frame %d: transmissionState patternType=%s, ' ...
        'IsActive=%d, NumActiveIntervals=%d, FrameWindow=[%.6f, %.6f]'], ...
        frameId, patternType, transmissionState.IsActive, ...
        numel(transmissionState.ActiveIntervalIndices), ...
        transmissionState.FrameWindow(1), transmissionState.FrameWindow(2));
end
