function gain = calculateAntennaGain(obj, numAntennas)
    % calculateAntennaGain - Calculate antenna gain based on number of antennas
    % Inputs / 输入: see signature arguments and local validation.
    % 输出 / Outputs: see signature return values and contract fields.
    % 中文说明：提供 CSRD 生产链路中的 calculateAntennaGain 实现。
    gain = 10 * log10(numAntennas); % Simple array gain formula
end
