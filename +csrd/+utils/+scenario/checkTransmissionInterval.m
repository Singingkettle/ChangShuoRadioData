function [isActive, intervalIdx, startTime, endTime] = checkTransmissionInterval(frameId, pattern)
    %CHECKTRANSMISSIONINTERVAL Determine whether a frame falls in any active interval.
    %
    %   [isActive, intervalIdx, startTime, endTime] = ...
    %       csrd.utils.scenario.checkTransmissionInterval(frameId, pattern)
    %
    %   Inputs:
    %     frameId : 1-based frame index inside the observation window.
    %     pattern : struct with fields
    %                 .Intervals           Nx2 [start, end] in seconds.
    %                 .ObservationDuration scalar, seconds (optional).
    %                 .NumFrames           scalar, frames per scenario (optional).
    %                 .FrameDuration       scalar, seconds per frame (optional, preferred).
    %
    %   The mapping from frameId to scenario time uses, in priority:
    %     1. pattern.FrameDuration                                (preferred)
    %     2. pattern.ObservationDuration / pattern.NumFrames
    %
    %   When neither is available the function returns isActive=false and
    %   issues a warning. There is intentionally no magic-number fallback
    %   such as NumFrames=10, which previously caused Burst / Scheduled /
    %   Random temporal patterns to silently misalign whenever the engine
    %   ran with a different frame count than the planner assumed.

    isActive = false;
    intervalIdx = 0;
    startTime = 0;
    endTime = 0;

    if ~isfield(pattern, 'Intervals') || isempty(pattern.Intervals)
        return;
    end

    intervals = pattern.Intervals;

    frameDuration = [];
    if isfield(pattern, 'FrameDuration') && ~isempty(pattern.FrameDuration) && pattern.FrameDuration > 0
        frameDuration = pattern.FrameDuration;
    elseif isfield(pattern, 'NumFrames') && ~isempty(pattern.NumFrames) && pattern.NumFrames > 0 && ...
            isfield(pattern, 'ObservationDuration') && ~isempty(pattern.ObservationDuration) && pattern.ObservationDuration > 0
        frameDuration = pattern.ObservationDuration / pattern.NumFrames;
    end

    if isempty(frameDuration)
        warning('CSRD:Scenario:MissingFrameTiming', ...
            ['checkTransmissionInterval could not derive frame duration. ', ...
             'Provide pattern.FrameDuration or both pattern.NumFrames and ', ...
             'pattern.ObservationDuration.']);
        return;
    end

    if isfield(pattern, 'NumFrames') && ~isempty(pattern.NumFrames) && pattern.NumFrames > 0 && ...
            (frameId < 1 || frameId > pattern.NumFrames)
        warning('CSRD:Scenario:FrameOutOfRange', ...
            'frameId %d is outside [1, %d] for this temporal pattern.', frameId, pattern.NumFrames);
    end

    frameTime = (frameId - 1) * frameDuration;

    for i = 1:size(intervals, 1)
        if frameTime >= intervals(i, 1) && frameTime < intervals(i, 2)
            isActive = true;
            intervalIdx = i;
            startTime = intervals(i, 1);
            endTime = intervals(i, 2);
            return;
        end
    end
end
