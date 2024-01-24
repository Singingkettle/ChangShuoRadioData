function t = generate_signal(lf, hf, fs, spf, spses, modulationTypes, channels, snrs)

if lf < hf
    % Select the modulation type randomly
    mid = randi(length(modulationTypes));
    
    % Select the sps randomly, which is the key to decide the bandwidth size
    sid = randi(length(spses));
    
    % Select the SNR randomly
    snr = snrs(randi(length(snrs)));

    % Select channel randomly
    cid = randi(length(channels));
    channel = channels{cid};
    channel.SNR = snr;

    src = helperModClassGetSource(modulationTypes(mid), spses(sid), spf, fs);
    modulator = MyModClassGetModulator(modulationTypes(mid), spses(sid), fs);
    
    x = src();
    y = modulator(x);
    
    bw = obw(y, fs)*1.1;
    % 1.5 is the protect gap to prevent the spectrum interference
    protect_gap = 1.5;

    if (hf-lf)>bw*protect_gap
        fcd = rand(1)*(hf-lf-bw*protect_gap);
        fc = fcd + lf + bw*protect_gap/2;
        c = expWave(fc, fs, spf);
        y = lowpass(y, bw*1.2/2, fs, ImpulseResponse="fir", Steepness=0.99);
        
        channel.CenterFrequency = fc;
        
        y = y.*c;
        frame = channel(y);

        t.data = frame;
        t.center_frequency = fc;
        t.bandwidth = bw*1.2;
        t.snr = snr;
        t.modulation = modulationTypes(mid);
        t.channel = channel.channel_type;
        t.sample_rate = fs;
        t.sample_num = spf;
        t.sample_per_symbol = spses(sid);
        
        t = {t};
        l = generate_signal(lf, fcd + lf, fs, spf, spses, modulationTypes, channels, snrs);
        if ~isempty(l)
            t = [l, t];
        end
        r = generate_signal(fcd + lf + bw*protect_gap, hf, fs, spf, spses, modulationTypes, channels, snrs);
        if ~isempty(r)
            t = [t, r];
        end
    else
        t = {};
    end
else
    t = {};
end

end

function y = expWave(fc, fs, spf)

sine = dsp.SineWave("Frequency",fc,"SampleRate",fs, ...
    "ComplexOutput",false, "SamplesPerFrame", spf);
cosine = dsp.SineWave("Frequency",fc,"SampleRate",fs, ...
    "ComplexOutput",false, "SamplesPerFrame", spf, ...
    "PhaseOffset", pi/2);

y = complex(cosine(), sine());

end
