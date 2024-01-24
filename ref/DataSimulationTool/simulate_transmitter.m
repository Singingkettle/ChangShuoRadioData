function t = simulate_transmitter(lf, hf, sr, spf, spses, modulationTypes)

if lf < hf
    % Select the modulation type randomly
    mid = randi(length(modulationTypes));
    
    % Select the sps randomly, which is the key to decide the bandwidth size
    sid = randi(length(spses));

    src = get_source(modulationTypes(mid), spses(sid), spf, sr);
    modulator = get_modulator(modulationTypes(mid), spses(sid), sr);
    
    x = src();
    y = modulator(x);
    
    bw = obw(y, sr);
    % 1.5 is the protect gap to prevent the spectrum interference
    protect_gap = 1.5;
    
    per_point_bw = sr/spf;

    if (hf-lf)>bw*protect_gap
        fcd = rand(1)*(hf-lf-bw*protect_gap);
        fc = fcd + lf + bw*protect_gap/2;
        % 按照FFT计算方式，每相邻FFT点之间的带宽是一个固定值，
        % 所以为了保证神经网络学习的方便，每个子信号的中心频率落在
        % 一个整数值的FFT点上
        fc = round(fc/per_point_bw)*per_point_bw;
        fcd = fc - lf - bw*protect_gap/2;
        c = expWave(fc, sr, spf);
        y = lowpass(y, bw*1.2/2, sr, ImpulseResponse="fir", Steepness=0.99);

        frame = y.*c;
        % make sure the input signal is normalized to unity power
        frame = frame ./ sqrt(mean(abs(frame).^2));
    
        t.data = frame;
        t.sps = spses(sid);
        t.center_frequency = fc;
        t.bandwidth = bw;
        t.modulation = modulationTypes(mid);
        t.sample_rate = sr;
        t.sample_num = spf;
        t.sample_per_symbol = spses(sid);
        
        t = {t};
        l = simulate_transmitter(lf, fcd + lf, sr, spf, spses, ...
            modulationTypes);
        if ~isempty(l)
            t = [l, t];
        end
        r = simulate_transmitter(fcd + lf + bw*protect_gap, hf, sr, ...
            spf, spses, modulationTypes);
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
