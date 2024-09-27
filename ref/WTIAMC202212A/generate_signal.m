function t = generate_signal(lf, hf, fs, spf, spses, modulationTypes, channel)

if lf < hf
    % Select the modulation type randomly
    mid = randi(length(modulationTypes));
    
    % Select the sps randomly, which is the key to decide the bandwidth size
    sid = randi(length(spses));
    
    % Select the SNR randomly
    snr = -8:2:20;
    snr = snr(randi(length(snr)));
    channel.SNR = snr;

    src = helperModClassGetSource(modulationTypes(mid), spses(sid), 2*spf, fs);
    modulator = MyModClassGetModulator(modulationTypes(mid), spses(sid), fs);
    
    x = src();
    y = modulator(x);
    
    bw = obw(y, fs);
    
    if bw > (hf-lf)
        t = {};
    else
        % 1.3 is the protect gap to prevent the spectrum interference
        protect_gap = 1.3;
        fcd = rand(1)*(hf-lf-bw*protect_gap);
        fc = fcd + lf + bw*protect_gap/2;
        c = expWave(fc, fs, spf);
        specAn0 = dsp.SpectrumAnalyzer("SampleRate", fs, ...
                            "Method", "Filter bank",...
                            "AveragingMethod", "Exponential", ...
                            "Title", "Data0");
        specAn0(y);
        y = lowpass(y, bw/2, fs, ImpulseResponse="fir", Steepness=0.99);
        
        
        specAn1 = dsp.SpectrumAnalyzer("SampleRate", fs, ...
                    "Method", "Filter bank",...
                    "AveragingMethod", "Exponential", ...
                    "Title", "Data1");
        specAn1(y);

        specAn2 = dsp.SpectrumAnalyzer("SampleRate", fs, ...
                    "Method", "Filter bank",...
                    "AveragingMethod", "Exponential", ...
                    "Title", "Data2");
        tmp = fft(y);
        left = floor(bw/fs*length(y)/2 + 1);
        right = floor(length(y) - bw/fs*length(y)/2 - 1);
        tmp(left:right) = 0;
        tmp = ifft(tmp);
        specAn2(tmp);

        if contains(char(modulationTypes(mid)), {'B-FM','DSB-AM','SSB-AM'})
          % Analog modulation types use a center frequency of 100 MHz
          channel.CarrierFrequency = 100e6;
        else
          % Digital modulation types use a center frequency of 902 MHz
          channel.CarrierFrequency = 902e6;
        end
        
        y = y.*c;
        rxSamples = channel(y);
        frame = helperModClassFrameGenerator(rxSamples, spf, spf, 50, spses(sid));
        
        t.data = frame;
        t.fc = fc;
        t.bw = bw;
        t.snr = snr;
        t.mod = modulationTypes(mid);

        t = {t};
        l = generate_signal(lf, fcd + lf, fs, spf, spses, modulationTypes, channel);
        if ~isempty(l)
            t = [l, t];
        end
        r = generate_signal(fcd + lf + bw*protect_gap, hf, fs, spf, spses, modulationTypes, channel);
        if ~isempty(r)
            t = [t, r];
        end
    end
else
    t = {};
end

end

function y = expWave(fc, fs, spf)

sine = dsp.SineWave("Frequency",fc,"SampleRate",fs, ...
    "ComplexOutput",false, "SamplesPerFrame",2*spf);
cosine = dsp.SineWave("Frequency",fc,"SampleRate",fs, ...
    "ComplexOutput",false, "SamplesPerFrame",2*spf, ...
    "PhaseOffset", pi/2);

y = complex(cosine(), sine());

end
