function y = carrierWave(carrier_frequencty, init_phase, sampleRate, samplePerFrame)
    y = dsp.SineWave( ...
        "Frequency", carrier_frequencty, ...
        "SampleRate", sampleRate, ...
        "ComplexOutput", true, ...
        "SamplesPerFrame", samplePerFrame, ...
        "PhaseOffset", init_phase);
end