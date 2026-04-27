function projectedOffset = lookupReceiverViewOffset(txScenarioConfig, rxInfo, rxIdx, channelOutput)
    %LOOKUPRECEIVERVIEWOFFSET Phase 3 per-Rx ProjectedCenterOffsetHz lookup.
    %
    %   projectedOffset = csrd.core.ChangShuo.lookupReceiverViewOffset( ...
    %       txScenarioConfig, rxInfo, rxIdx, channelOutput)
    %
    %   Phase 3 (audit §3.1.ter A): pull ProjectedCenterOffsetHz off
    %   the per-Rx ReceiverViews struct populated upstream by
    %   allocateFrequenciesReceiverCentric. We match by ReceiverId
    %   first (robust against any future reordering between rxConfigs
    %   and RxInfos) and fall back to positional index when a Phase 3
    %   ReceiverView entry has no ID. Missing ReceiverViews is a hard
    %   schema violation post-S2 -- fail fast so the offending pipeline
    %   gets caught in unit/regression tests rather than silently
    %   corrupting per-Rx baseband geometry.
    %
    %   `channelOutput` is accepted for parity with the call-site
    %   signature; Phase 3 unified-receiver does not need it but it is
    %   reserved for the Phase 4 sanity-check between channel-block
    %   FrequencyOffset and per-Rx projection (heterogeneous Rx).

    if ~isstruct(txScenarioConfig) || ~isfield(txScenarioConfig, 'ReceiverViews') ...
            || isempty(txScenarioConfig.ReceiverViews)
        error('CSRD:Construction:MissingReceiverViews', ...
            ['lookupReceiverViewOffset: txScenarioConfig is missing the ', ...
             'ReceiverViews struct array; allocateFrequenciesReceiverCentric ', ...
             'should have populated it for every Tx in Phase 3.']);
    end

    rvs = txScenarioConfig.ReceiverViews;
    rxIdStr = '';
    if isstruct(rxInfo) && isfield(rxInfo, 'ID') && ~isempty(rxInfo.ID)
        rxIdStr = char(string(rxInfo.ID));
    end

    matched = [];
    if ~isempty(rxIdStr)
        for k = 1:numel(rvs)
            entry = rvs(k);
            if isfield(entry, 'ReceiverId') && ~isempty(entry.ReceiverId) ...
                    && strcmp(char(string(entry.ReceiverId)), rxIdStr)
                matched = entry;
                break;
            end
        end
    end

    if isempty(matched)
        if rxIdx < 1 || rxIdx > numel(rvs)
            error('CSRD:Construction:ReceiverViewIndexOutOfRange', ...
                ['lookupReceiverViewOffset: rxIdx=%d is outside the ', ...
                 '1..%d ReceiverViews populated for Tx; cannot fall back ', ...
                 'to positional lookup.'], rxIdx, numel(rvs));
        end
        matched = rvs(rxIdx);
    end

    if ~isfield(matched, 'ProjectedCenterOffsetHz') ...
            || isempty(matched.ProjectedCenterOffsetHz) ...
            || ~isnumeric(matched.ProjectedCenterOffsetHz)
        error('CSRD:Construction:MissingProjectedCenterOffset', ...
            ['lookupReceiverViewOffset: ReceiverView entry for Rx %s ', ...
             'is missing ProjectedCenterOffsetHz.'], rxIdStr);
    end

    projectedOffset = matched.ProjectedCenterOffsetHz;

    % Reserved for Phase 4 heterogeneous-Rx (non-unified CenterFrequency):
    % when the channel block returns a FrequencyOffset that diverges
    % from the per-Rx projection by more than 1 Hz it indicates the
    % ChannelFactory needs to learn about per-Rx CenterFrequency
    % arithmetic. In Phase 3 unified-Rx this branch is silent on
    % purpose so it does not spam logs.
    if isstruct(channelOutput) && isfield(channelOutput, 'FrequencyOffset') ...
            && ~isempty(channelOutput.FrequencyOffset) ...
            && abs(channelOutput.FrequencyOffset - projectedOffset) > 1
        % deliberately silent in Phase 3
    end
end
