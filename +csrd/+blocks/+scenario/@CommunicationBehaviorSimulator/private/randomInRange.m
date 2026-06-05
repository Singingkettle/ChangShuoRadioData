function value = randomInRange(obj, minVal, maxVal)
    % randomInRange - Generate random value in specified range
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    value = minVal + (maxVal - minVal) * rand();
end
