function rvEntry = lookupReceiverViewEntry(txScenarioConfig, rxInfo, rxIdx)
    %LOOKUPRECEIVERVIEWENTRY Phase 4 §S6 per-Rx ReceiverView struct lookup.
    %
    %   rvEntry = csrd.core.ChangShuo.lookupReceiverViewEntry( ...
    %       txScenarioConfig, rxInfo, rxIdx)
    %
    %   Sister to `lookupReceiverViewOffset`: returns the *full* matched
    %   ReceiverView struct (5+ canonical fields - ReceiverId,
    %   ProjectedCenterOffsetHz, ProjectedLowerEdgeHz, ProjectedUpperEdgeHz,
    %   IsVisible, VisibilityReason) so processChannelPropagation can
    %   stamp it onto each per-(Tx,Rx) component, which then bubbles up
    %   into `SignalSources(k).ReceiverView` via buildSourceAnnotation.
    %
    %   Match-by-ReceiverId first (robust to any reordering between
    %   rxConfigs and RxInfos), positional-fallback when the ReceiverView
    %   was built without a ReceiverId. Missing ReceiverViews on the Tx
    %   is a Phase 3 schema violation -- fail fast with the same
    %   identifier (`CSRD:Construction:MissingReceiverViews`) used by
    %   the offset lookup so downstream tests pin a single contract.

    if ~isstruct(txScenarioConfig) || ~isfield(txScenarioConfig, 'ReceiverViews') ...
            || isempty(txScenarioConfig.ReceiverViews)
        error('CSRD:Construction:MissingReceiverViews', ...
            ['lookupReceiverViewEntry: txScenarioConfig is missing the ', ...
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
                ['lookupReceiverViewEntry: rxIdx=%d is outside the ', ...
                 '1..%d ReceiverViews populated for Tx; cannot fall ', ...
                 'back to positional lookup.'], rxIdx, numel(rvs));
        end
        matched = rvs(rxIdx);
    end

    rvEntry = matched;
end
