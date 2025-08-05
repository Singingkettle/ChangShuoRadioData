function [txConfigs, globalLayout] = allocateFrequenciesRandom(obj, txConfigs, ...
        observableRange, globalLayout)
    % allocateFrequenciesRandom - Random frequency allocation without optimization
    % Simpler random allocation for testing purposes
    [txConfigs, globalLayout] = allocateFrequenciesReceiverCentric(obj, txConfigs, ...
        observableRange, globalLayout);
end
