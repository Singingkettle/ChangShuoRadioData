function sampleRate = selectSampleRate(obj, receiver, factoryConfig)
    % selectSampleRate - Select sample rate for receiver
    if isfield(factoryConfig.Parameters, 'SampleRateRange')
        range = factoryConfig.Parameters.SampleRateRange;
        sampleRate = randomInRange(obj, range.Min, range.Max);
    else
        sampleRate = 20e6; % Default 20 MHz
    end

end
