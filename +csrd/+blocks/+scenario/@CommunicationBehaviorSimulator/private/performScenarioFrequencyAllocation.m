function [txConfigs, globalLayout] = performScenarioFrequencyAllocation(obj, txConfigs, ...
        observableRange, globalLayout)
    % performScenarioFrequencyAllocation - Allocate fixed frequencies for scenario
    %
    % Performs intelligent frequency allocation within the receiver's
    % observable range using the configured allocation strategy. These
    % frequency allocations remain fixed throughout the entire scenario.

    obj.logger.debug('Scenario: Starting frequency allocation for %d transmitters', ...
        length(txConfigs));

    % Calculate total required bandwidth
    totalRequiredBW = 0;

    for i = 1:length(txConfigs)
        totalRequiredBW = totalRequiredBW + txConfigs(i).RequiredBandwidth;
    end

    % Calculate available bandwidth
    availableBW = observableRange(2) - observableRange(1);
    minSeparation = obj.Config.FrequencyAllocation.MinSeparation;
    separationBW = (length(txConfigs) - 1) * minSeparation;
    totalNeededBW = totalRequiredBW + separationBW;

    obj.logger.debug('Scenario: Bandwidth analysis - Required: %.1f MHz, Available: %.1f MHz', ...
        totalRequiredBW / 1e6, availableBW / 1e6);

    % Determine allocation strategy
    if totalNeededBW > availableBW
        strategy = 'Overlapping';
        overlapRatio = min(obj.Config.FrequencyAllocation.MaxOverlap, ...
            (totalNeededBW - availableBW) / availableBW);
        obj.logger.warning('Scenario: Insufficient bandwidth, using overlapping allocation (%.1f%% overlap)', ...
            overlapRatio * 100);
    else
        strategy = 'NonOverlapping';
        overlapRatio = 0;
        obj.logger.debug('Scenario: Using non-overlapping frequency allocation');
    end

    globalLayout.AllocationStrategy = strategy;
    globalLayout.OverlapRatio = overlapRatio;
    globalLayout.ObservableRange = observableRange;
    globalLayout.TotalBandwidth = availableBW;

    % Perform actual frequency allocation
    switch obj.Config.FrequencyAllocation.Strategy
        case 'ReceiverCentric'
            [txConfigs, globalLayout] = allocateFrequenciesReceiverCentric(obj, txConfigs, ...
                observableRange, globalLayout);
        case 'Optimized'
            [txConfigs, globalLayout] = allocateFrequenciesOptimized(obj, txConfigs, ...
                observableRange, globalLayout);
        case 'Random'
            [txConfigs, globalLayout] = allocateFrequenciesRandom(obj, txConfigs, ...
                observableRange, globalLayout);
        otherwise
            obj.logger.warning('Unknown frequency allocation strategy: %s, using ReceiverCentric', ...
                obj.Config.FrequencyAllocation.Strategy);
            [txConfigs, globalLayout] = allocateFrequenciesReceiverCentric(obj, txConfigs, ...
                observableRange, globalLayout);
    end

    obj.logger.debug('Scenario: Frequency allocation completed using %s strategy', ...
        globalLayout.AllocationStrategy);
end
