function [activeIntervalIndices, activeIntervals, frameWindow] = ...
        findOverlappingTransmissionIntervals(frameId, pattern)
%FINDOVERLAPPINGTRANSMISSIONINTERVALS Collect all transmission intervals overlapping a frame.
% Inputs: see signature arguments and local validation.
% Outputs: see signature return values and contract fields.
%
%   [activeIntervalIndices, activeIntervals, frameWindow] = ...
%       csrd.pipeline.scenario.findOverlappingTransmissionIntervals(frameId, pattern)
%
%   Inputs (mirrors csrd.pipeline.scenario.checkTransmissionInterval):
%     frameId : 1-based frame index inside the observation window.
%     pattern : struct with fields
%                 .Intervals           Nx2 [start, end] in seconds.
%                 .ObservationDuration scalar, seconds (optional).
%                 .NumFrames           scalar, frames per scenario (optional).
%                 .FrameDuration       scalar, seconds per frame (optional, preferred).
%
%   Outputs:
%     activeIntervalIndices : 1xK row vector of interval indices that
%                             overlap [frameStart, frameEnd). Empty when
%                             nothing overlaps.
%     activeIntervals       : Kx2 matrix of the overlapping intervals
%                             clipped to the current frame window.
%                             These remain absolute scenario times; the
%                             downstream receiver combiner converts them
%                             to frame-relative sample offsets.
%     frameWindow           : 1x2 [frameStart, frameEnd) for this frame.
%
%   Overlap semantics (Phase 1 / A2):
%       intervalEnd > frameStart  AND  intervalStart < frameEnd
%   This is the "any overlap" rule. The previous single-interval code
%   path used the stricter "frame start lies inside the interval" rule
%   (frameStart in [intervalStart, intervalEnd)), which silently dropped
%   bursts that started after frameStart but inside the same frame.
%
%   Frame timing resolution mirrors checkTransmissionInterval:
%     1. pattern.FrameDuration
%     2. pattern.ObservationDuration / pattern.NumFrames
%   Missing timing or out-of-range frames are planner errors and fail fast.

    activeIntervalIndices = [];
    activeIntervals = zeros(0, 2);
    frameWindow = [0, 0];

    if ~isfield(pattern, 'Intervals') || isempty(pattern.Intervals)
        return;
    end
    intervals = pattern.Intervals;

    frameDuration = [];
    if isfield(pattern, 'FrameDuration') && ~isempty(pattern.FrameDuration) && pattern.FrameDuration > 0
        frameDuration = pattern.FrameDuration;
    elseif isfield(pattern, 'NumFrames') && ~isempty(pattern.NumFrames) && pattern.NumFrames > 0 && ...
            isfield(pattern, 'ObservationDuration') && ~isempty(pattern.ObservationDuration) && ...
            pattern.ObservationDuration > 0
        frameDuration = pattern.ObservationDuration / pattern.NumFrames;
    end

    if isempty(frameDuration)
        error('CSRD:Scenario:MissingFrameTiming', ...
            ['findOverlappingTransmissionIntervals could not derive frame duration. ', ...
             'Provide pattern.FrameDuration or both pattern.NumFrames and ', ...
             'pattern.ObservationDuration.']);
    end

    if isfield(pattern, 'NumFrames') && ~isempty(pattern.NumFrames) && pattern.NumFrames > 0 && ...
            (frameId < 1 || frameId > pattern.NumFrames)
        error('CSRD:Scenario:FrameOutOfRange', ...
            'frameId %d is outside [1, %d] for this temporal pattern.', frameId, pattern.NumFrames);
    end

    frameStart = (frameId - 1) * frameDuration;
    frameEnd   = frameId * frameDuration;
    frameWindow = [frameStart, frameEnd];

    % "any overlap" rule.
    overlapMask = (intervals(:, 2) > frameStart) & (intervals(:, 1) < frameEnd);
    activeIntervalIndices = reshape(find(overlapMask), 1, []);
    activeIntervals = intervals(activeIntervalIndices, :);
    if ~isempty(activeIntervals)
        activeIntervals(:, 1) = max(activeIntervals(:, 1), frameStart);
        activeIntervals(:, 2) = min(activeIntervals(:, 2), frameEnd);
    end
end
