function [txConfigs, globalLayout] = allocateFrequenciesReceiverCentric(obj, txConfigs, ...
        observableRange, globalLayout)
    % allocateFrequenciesReceiverCentric - Receiver-centric frequency allocation
    %
    % Allocates frequencies randomly within the receiver's observable range
    % with collision avoidance based on minimum separation requirements.

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

        if isCellArray
            txConfigs{i} = txConfig;
        else
            txConfigs(i) = txConfig;
        end
        globalLayout.FrequencyAllocations{i} = [centerFreq - txBW / 2, centerFreq + txBW / 2];

        obj.logger.debug('Allocated frequency [%.1f, %.1f] MHz to transmitter %s', ...
            txConfig.Spectrum.LowerBound / 1e6, ...
            txConfig.Spectrum.UpperBound / 1e6, txConfig.EntityID);
    end

end
