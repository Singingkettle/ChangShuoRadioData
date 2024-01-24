spf = 1024;                  % Samples per frame
fs = 200e3;                  % Sample rate


src = helperModClassGetSource('BPSK', 16, 2*spf, fs);
modulator = MyModClassGetModulator('BPSK', 16, fs);

x = src();
y = modulator(x);
SNR = 20;
[bw,flo0,fhi0,power] = obw(y, fs);


% 1.3 is the protect gap to prevent the spectrum interference
protect_gap = 1.3;
fcd = rand(1)*(fs-bw*protect_gap);
fc = fcd -fs/2 + bw*protect_gap/2;
c = expWave(fc, fs, spf);
y1 = lowpass(y, bw/2, fs, ImpulseResponse="fir", Steepness=0.99);
[bw0,flo0,fhi0,power] = obw(y1, fs);

fc0_l = expWave(flo0, fs, spf);
fc0_h = expWave(fhi0, fs, spf);
fc0 = expWave((flo0+fhi0)/2, fs, spf);

y2 = y1.*c;
[bw1,flo1,fhi1,power] = obw(y2, fs);

fc1_l = expWave(flo1, fs, spf);
fc1_h = expWave(fhi1, fs, spf);
fc1 = expWave((flo1+fhi1)/2, fs, spf);
y3 = y2.*conj(c);
y4 = y2.*conj(fc1);
in = y2 ./ sqrt(mean(abs(y2).^2));
rxSamples = awgn(in, SNR, 'measured');
tmp = rxSamples.*conj(fc1);
% frame = helperModClassFrameGenerator(rxSamples, spf, spf, 50, spses(sid));
frame = rxSamples(1:spf, 1);


channel_rayleigh = MyModClassTestChannel(...
                        'channel_type', 'rayleigh', ...
                        'SampleRate', fs, ...
                        'SNR', SNR, ...
                        'PathDelays', [0 1.8 3.4] / fs, ...
                        'AveragePathGains', [0 -2 -10], ...
                        'KFactor', 4, ...
                        'MaximumDopplerShift', 4, ...
                        'MaximumClockOffset', 5, ...
                        'CenterFrequency', fc);

[y5, bw2,flo2,fhi2] = channel_rayleigh(y2);
fc2_l = expWave(flo2, fs, spf);
fc2_h = expWave(fhi2, fs, spf);
fc2 = expWave((flo2+fhi2)/2, fs, spf);
y6 = y5.*conj(fc2);
function y = expWave(fc, fs, spf)

sine = dsp.SineWave("Frequency",fc,"SampleRate",fs, ...
    "ComplexOutput",false, "SamplesPerFrame",2*spf);
cosine = dsp.SineWave("Frequency",fc,"SampleRate",fs, ...
    "ComplexOutput",false, "SamplesPerFrame",2*spf, ...
    "PhaseOffset", pi/2);

y = complex(cosine(), sine());

end
