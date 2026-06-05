function gain = calculateAntennaGain(obj, numAntennas)
    % calculateAntennaGain - Calculate antenna gain based on number of antennas
    % Inputs: see signature arguments and local validation.
    % Outputs: see signature return values and contract fields.
    gain = 10 * log10(numAntennas); % Simple array gain formula
end
