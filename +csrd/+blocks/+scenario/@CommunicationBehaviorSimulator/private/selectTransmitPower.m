function power = selectTransmitPower(obj, transmitter, factoryConfig)
    % selectTransmitPower - Select transmit power
    range = factoryConfig.Parameters.Power;
    power = randomInRange(obj, range.Min, range.Max);
end
