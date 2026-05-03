function value = randomInRange(obj, minVal, maxVal)
    % randomInRange - Generate random value in specified range
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 randomInRange 实现。
    value = minVal + (maxVal - minVal) * rand();
end
