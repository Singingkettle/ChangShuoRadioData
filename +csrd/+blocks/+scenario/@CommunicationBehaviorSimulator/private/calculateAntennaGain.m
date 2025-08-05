function gain = calculateAntennaGain(obj, numAntennas)
    % calculateAntennaGain - Calculate antenna gain based on number of antennas
    gain = 10 * log10(numAntennas); % Simple array gain formula
end
