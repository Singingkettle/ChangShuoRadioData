function [txConfigs, globalLayout] = performScenarioFrequencyAllocation(obj, txConfigs, ...
        rxConfigs, observableRange, globalLayout)
    % 中文说明：提供 CSRD 生产链路中的 performScenarioFrequencyAllocation 实现。
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % performScenarioFrequencyAllocation - Allocate fixed frequencies for scenario
    %
    % Performs intelligent frequency allocation within the receiver's
    % observable range using the configured allocation strategy. These
    % frequency allocations remain fixed throughout the entire scenario.
    %
    % Phase 3 (audit §3.1.ter A): rxConfigs is forwarded to the strategy
    % function so that ReceiverViews can be projected onto every Receiver.

    obj.logger.debug('Scenario: Starting frequency allocation for %d transmitters', ...
        length(txConfigs));

    % Calculate available bandwidth
    availableBW = observableRange(2) - observableRange(1);

    if isfield(globalLayout, 'Regulatory') && ...
            isstruct(globalLayout.Regulatory) && ...
            isfield(globalLayout.Regulatory, 'Enable') && ...
            isequal(globalLayout.Regulatory.Enable, true)
        globalLayout.AllocationStrategy = 'RegulatoryCatalog';
        globalLayout.OverlapRatio = 0;
        globalLayout.OverlapAllowed = false;
        globalLayout.OverlapReason = '';
        globalLayout.OverlapOccurred = false;
        globalLayout.ObservableRange = observableRange;
        globalLayout.TotalBandwidth = availableBW;
        [txConfigs, globalLayout] = allocateFrequenciesFromRegulatoryPlan( ...
            obj, txConfigs, rxConfigs, observableRange, globalLayout);
        obj.logger.debug('Scenario: Frequency allocation completed from regulatory catalog');
        return;
    end

    % Calculate total required bandwidth
    totalRequiredBW = 0;

    for i = 1:length(txConfigs)
        if iscell(txConfigs)
            totalRequiredBW = totalRequiredBW + txConfigs{i}.Spectrum.PlannedBandwidth;
        else
            totalRequiredBW = totalRequiredBW + txConfigs(i).Spectrum.PlannedBandwidth;
        end
    end

    minSeparation = obj.Config.FrequencyAllocation.MinSeparation;
    separationBW = (length(txConfigs) - 1) * minSeparation;
    totalNeededBW = totalRequiredBW + separationBW;

    obj.logger.debug('Scenario: Bandwidth analysis - Required: %.1f MHz, Available: %.1f MHz', ...
        totalRequiredBW / 1e6, availableBW / 1e6);

    % Determine allocation strategy
    allowOverlap = isfield(obj.Config.FrequencyAllocation, 'AllowOverlap') && ...
        isequal(obj.Config.FrequencyAllocation.AllowOverlap, true);

    if totalNeededBW > availableBW
        if ~allowOverlap
            error('CSRD:Scenario:FrequencyAllocationInsufficientBandwidth', ...
                ['Required bandwidth plus separation is %.6g Hz, but the ', ...
                 'receiver observable range only provides %.6g Hz. ', ...
                 'Widen the receiver range, reduce transmitter count/bandwidth, ', ...
                 'or use an explicit overlap test config with AllowOverlap=true.'], ...
                totalNeededBW, availableBW);
        end
        strategy = 'Overlapping';
        overlapRatio = min(obj.Config.FrequencyAllocation.MaxOverlap, ...
            (totalNeededBW - availableBW) / availableBW);
        globalLayout.OverlapAllowed = true;
        globalLayout.OverlapReason = 'ExplicitFrequencyAllocationAllowOverlap';
        globalLayout.OverlapOccurred = false;
        obj.logger.warning('Scenario: Insufficient bandwidth, using overlapping allocation (%.1f%% overlap)', ...
            overlapRatio * 100);
    else
        strategy = 'NonOverlapping';
        overlapRatio = 0;
        globalLayout.OverlapAllowed = false;
        globalLayout.OverlapReason = '';
        globalLayout.OverlapOccurred = false;
        obj.logger.debug('Scenario: Using non-overlapping frequency allocation');
    end

    globalLayout.AllocationStrategy = strategy;
    globalLayout.OverlapRatio = overlapRatio;
    globalLayout.ObservableRange = observableRange;
    globalLayout.TotalBandwidth = availableBW;

    % Perform actual frequency allocation.
    %
    % Phase 2 (D7): only 'ReceiverCentric' is supported. The previous
    % 'Optimized' and 'Random' strategies were thin wrappers that
    % silently delegated to ReceiverCentric, and the otherwise branch
    % silently fell back to ReceiverCentric with only a warning log.
    % All silent fallbacks have been removed; any non-ReceiverCentric
    % value now raises CSRD:Scenario:UnsupportedFrequencyStrategy via
    % the Hidden static gate on the simulator class itself.
    csrd.blocks.scenario.CommunicationBehaviorSimulator.validateFrequencyAllocationStrategy( ...
        obj.Config.FrequencyAllocation.Strategy);
    [txConfigs, globalLayout] = allocateFrequenciesReceiverCentric(obj, txConfigs, ...
        rxConfigs, observableRange, globalLayout);

    obj.logger.debug('Scenario: Frequency allocation completed using %s strategy', ...
        globalLayout.AllocationStrategy);
end
