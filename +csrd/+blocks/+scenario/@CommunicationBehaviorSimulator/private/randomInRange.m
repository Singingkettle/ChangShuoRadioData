function value = randomInRange(obj, minVal, maxVal)
    % randomInRange - Generate random value in specified range
    value = minVal + (maxVal - minVal) * rand();
end
