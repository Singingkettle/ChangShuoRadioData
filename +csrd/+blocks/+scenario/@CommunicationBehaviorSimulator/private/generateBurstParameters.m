function burstParams = generateBurstParameters(obj)
    % generateBurstParameters - Generate burst transmission parameters
    burstParams = struct();
    burstParams.startTime = randomInRange(obj, 0, 0.1); % Start within first 100ms
    burstParams.duration = randomInRange(obj, 0.01, 0.1); % 10-100ms bursts
    burstParams.period = randomInRange(obj, 0.1, 1.0); % 100ms-1s period
    burstParams.dutyCycle = burstParams.duration / burstParams.period;
end
