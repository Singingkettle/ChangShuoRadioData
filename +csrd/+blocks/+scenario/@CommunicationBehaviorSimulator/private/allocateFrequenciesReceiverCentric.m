function [txConfigs, globalLayout] = allocateFrequenciesReceiverCentric(obj, txConfigs, ...
        rxConfigs, observableRange, globalLayout)
    %allocateFrequenciesReceiverCentric Receiver-centric frequency allocation.
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 allocateFrequenciesReceiverCentric 实现。
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
                % Force placement if no non-overlapping position found
                centerFreq = randomInRange(obj, minCenter, maxCenter);
                obj.logger.warning('Could not avoid overlap for transmitter %s', txConfig.EntityID);
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
