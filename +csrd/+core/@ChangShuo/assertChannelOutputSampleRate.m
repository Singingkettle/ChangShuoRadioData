function assertChannelOutputSampleRate(channelOutput, FrameId, txId, rxId, segIdx)
    %ASSERTCHANNELOUTPUTSAMPLERATE Phase 3 strict check on channel output rate.
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 assertChannelOutputSampleRate 实现。
    %
    %   csrd.core.ChangShuo.assertChannelOutputSampleRate( ...
    %       channelOutput, FrameId, txId, rxId, segIdx)
    %
    %   The legacy `processChannelPropagation` walked through a
    %   three-tier fallback (channel -> segment -> rxInfo SampleRate)
    %   when the ChannelFactory forgot to set SampleRate on its
    %   output. That hid ChannelFactory bugs and silently re-rated
    %   downstream signals; the fallbacks were removed under
    %   phase-3-construction.md §3.2.C in favour of this single-tier
    %   strict check.
    %
    %   Throws CSRD:Construction:ChannelMissingSampleRate when
    %   channelOutput.SampleRate is missing, empty, non-numeric,
    %   non-scalar or non-positive.

    if ~isstruct(channelOutput) ...
            || ~isfield(channelOutput, 'SampleRate') ...
            || isempty(channelOutput.SampleRate) ...
            || ~isnumeric(channelOutput.SampleRate) ...
            || ~isscalar(channelOutput.SampleRate) ...
            || channelOutput.SampleRate <= 0
        error('CSRD:Construction:ChannelMissingSampleRate', ...
            ['Frame %d, Tx %s -> Rx %s, Seg %d: channelOutput.SampleRate is ', ...
             'required (positive scalar). The segment / receiver fallback ', ...
             'chain was removed in Phase 3.'], ...
            FrameId, string(txId), string(rxId), segIdx);
    end
end
