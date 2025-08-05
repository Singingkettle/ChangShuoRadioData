function transmissionPattern = generateTransmissionPattern(obj, transmitter, factoryConfig)
    % generateTransmissionPattern - Generate fixed transmission pattern for scenario
    transmissionPattern = struct();

    % Select pattern type
    patternType = selectTransmissionPatternType(obj);
    transmissionPattern.Type = patternType;

    switch patternType
        case 'Continuous'
            transmissionPattern.StartTime = 0;
            transmissionPattern.Duration = Inf;
            transmissionPattern.DutyCycle = 1.0;

        case 'Burst'
            burstParams = generateBurstParameters(obj);
            transmissionPattern.Duration = burstParams.duration;
            transmissionPattern.BurstPeriod = burstParams.period;
            transmissionPattern.DutyCycle = burstParams.dutyCycle;

        case 'Scheduled'
            transmissionPattern.TimeSlotDuration = 0.01; % 10ms slots
            transmissionPattern.FrameLength = 0.1; % 100ms frames
            transmissionPattern.DutyCycle = randomInRange(obj, 0.1, 0.8);

        otherwise
            % Default to continuous
            transmissionPattern.Type = 'Continuous';
            transmissionPattern.StartTime = 0;
            transmissionPattern.Duration = Inf;
            transmissionPattern.DutyCycle = 1.0;
    end

end
