function patternType = selectTransmissionPatternType(obj)
    % selectTransmissionPatternType - Select transmission pattern type
    patterns = {'Continuous', 'Burst', 'Scheduled'};
    weights = [0.6, 0.3, 0.1]; % Prefer continuous transmissions

    cumWeights = cumsum(weights);
    r = rand();
    idx = find(r <= cumWeights, 1);
    patternType = patterns{idx};
end
