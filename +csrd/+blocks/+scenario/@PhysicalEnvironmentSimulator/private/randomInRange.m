function value = randomInRange(obj, minVal, maxVal)
    % randomInRange - Generate random value in specified range
    %
    % Input Arguments:
    %   minVal - Minimum value of range
    %   maxVal - Maximum value of range
    %
    % Output Arguments:
    %   value - Random value between minVal and maxVal

    value = minVal + (maxVal - minVal) * rand();
end
