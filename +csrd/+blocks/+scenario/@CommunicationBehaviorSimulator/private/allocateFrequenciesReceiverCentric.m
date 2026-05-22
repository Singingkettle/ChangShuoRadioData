function [txConfigs, globalLayout] = allocateFrequenciesReceiverCentric(obj, txConfigs, ...
        rxConfigs, observableRange, globalLayout)
    %allocateFrequenciesReceiverCentric Receiver-centric frequency allocation.
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    %
    %   Allocates an emitter-global PlannedFreqOffset per Tx inside the
    %   unified observable range using random placement + collision
    %   avoidance, then projects every Tx onto every Rx and writes the
    %   per-pair `ReceiverViews` struct array (Phase 3, see
    %   docs/audits/phases/phase-3-construction.md §3.1).
    %
    %   Phase 3 unified-receiver contract: every Receiver shares the
    %   same `Observation.CenterFrequency` and `Observation.ObservableRange`
    %   (see `CommunicationBehaviorSimulator.unifiedReceiverConfig`), so
    %   the projected center offset for each (Tx, Rx) pair equals the
    %   placed `Spectrum.PlannedFreqOffset`. Phase 4 will swap this for
    %   true heterogeneous-receiver arithmetic without changing the
    %   ReceiverView schema -- the projection logic itself lives on the
    %   simulator class as a Hidden static helper
    %   (`projectReceiverViews`) and only the inputs change.

    usedRanges = [];
    globalLayout.FrequencyAllocations = {};
    isCellArray = iscell(txConfigs);

    for i = 1:length(txConfigs)
        if isCellArray
            txConfig = txConfigs{i};
        else
            txConfig = txConfigs(i);
        end
        txBW = txConfig.Spectrum.PlannedBandwidth;

        % Random placement within observable range
        minCenter = observableRange(1) + txBW / 2;
        maxCenter = observableRange(2) - txBW / 2;

        if minCenter >= maxCenter
            % Signal too wide for range, place at center
            centerFreq = mean(observableRange);
            obj.logger.warning('Transmitter %s bandwidth too large, placing at center', txConfig.EntityID);
        else
            % Try multiple placements to avoid overlap
            maxAttempts = 50;
            placed = false;

            for attempt = 1:maxAttempts
                centerFreq = randomInRange(obj, minCenter, maxCenter);
                proposedRange = [centerFreq - txBW / 2, centerFreq + txBW / 2];

                % Check overlap with existing allocations
                hasOverlap = false;

                for j = 1:size(usedRanges, 1)

                    if checkFrequencyOverlap(obj, proposedRange, usedRanges(j, :))
                        hasOverlap = true;
                        break;
                    end

                end

                if ~hasOverlap
                    usedRanges = [usedRanges; proposedRange];
                    placed = true;
                    break;
                end

            end

            if ~placed
                centerFreq = localFindNonOverlappingCenter(obj, txBW, ...
                    minCenter, maxCenter, usedRanges);
                if isfinite(centerFreq)
                    proposedRange = [centerFreq - txBW / 2, centerFreq + txBW / 2];
                    usedRanges = [usedRanges; proposedRange]; %#ok<AGROW>
                    placed = true;
                elseif isfield(globalLayout, 'OverlapAllowed') && ...
                        isequal(globalLayout.OverlapAllowed, true)
                    centerFreq = randomInRange(obj, minCenter, maxCenter);
                    globalLayout.OverlapOccurred = true;
                    obj.logger.warning(['Could not avoid overlap for transmitter %s; ', ...
                        'using explicit overlap policy "%s".'], ...
                        txConfig.EntityID, ...
                        string(getStructField(globalLayout, 'OverlapReason', '')));
                else
                    error('CSRD:Scenario:FrequencyPlacementFailed', ...
                        ['Could not place transmitter %s without overlap after ', ...
                         '%d random attempts plus deterministic gap search. ', ...
                         'Default generation does not silently overlap spectrum.'], ...
                        txConfig.EntityID, maxAttempts);
                end
            end

        end

        % Apply frequency allocation to transmitter
        txConfig.Spectrum.PlannedFreqOffset = centerFreq;
        txConfig.Spectrum.LowerBound = centerFreq - txBW / 2;
        txConfig.Spectrum.UpperBound = centerFreq + txBW / 2;

        % Phase 3: project the placed spectrum onto every Receiver
        txConfig.ReceiverViews = ...
            csrd.blocks.scenario.CommunicationBehaviorSimulator.projectReceiverViews( ...
            txConfig.Spectrum, rxConfigs, observableRange);

        if isCellArray
            txConfigs{i} = txConfig;
        else
            txConfigs(i) = txConfig;
        end
        globalLayout.FrequencyAllocations{i} = [centerFreq - txBW / 2, centerFreq + txBW / 2];

        obj.logger.debug('Allocated frequency [%.1f, %.1f] MHz to transmitter %s (projected onto %d receivers)', ...
            txConfig.Spectrum.LowerBound / 1e6, ...
            txConfig.Spectrum.UpperBound / 1e6, txConfig.EntityID, numel(txConfig.ReceiverViews));
    end

end

function centerFreq = localFindNonOverlappingCenter(obj, txBW, minCenter, ...
        maxCenter, usedRanges)
%LOCALFINDNONOVERLAPPINGCENTER Deterministic fallback for finite gap search.
% Inputs: see function signature and validation.
% Outputs: see return values and contract fields.
centerFreq = NaN;
if isempty(usedRanges)
    centerFreq = (minCenter + maxCenter) / 2;
    return;
end
minSeparation = obj.Config.FrequencyAllocation.MinSeparation;
candidateCenters = [minCenter, maxCenter, (minCenter + maxCenter) / 2];
for idx = 1:size(usedRanges, 1)
    candidateCenters(end + 1) = usedRanges(idx, 1) - minSeparation - txBW / 2; %#ok<AGROW>
    candidateCenters(end + 1) = usedRanges(idx, 2) + minSeparation + txBW / 2; %#ok<AGROW>
end
candidateCenters = unique(candidateCenters(isfinite(candidateCenters)));
candidateCenters = candidateCenters(candidateCenters >= minCenter & ...
    candidateCenters <= maxCenter);
candidateCenters = sort(candidateCenters);
for idx = 1:numel(candidateCenters)
    proposedRange = [candidateCenters(idx) - txBW / 2, ...
        candidateCenters(idx) + txBW / 2];
    hasOverlap = false;
    for usedIdx = 1:size(usedRanges, 1)
        if checkFrequencyOverlap(obj, proposedRange, usedRanges(usedIdx, :))
            hasOverlap = true;
            break;
        end
    end
    if ~hasOverlap
        centerFreq = candidateCenters(idx);
        return;
    end
end
end

function value = getStructField(s, fieldName, defaultValue)
    % getStructField - CSRD MATLAB declaration.
    % Inputs: see function signature and validation.
    % Outputs: see return values and contract fields.
if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
    value = s.(fieldName);
else
    value = defaultValue;
end
end
