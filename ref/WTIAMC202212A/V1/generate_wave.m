sps = 32;               % Samples per symbol, must be an even number
spf = 4096;             % Samples per frame
fs = 200e3;             % Sample rate
sb = 3*fs/sps;          % Signal bandwidth
num_bands = floor((fs-sb)/sb/2)*2+1;

bands_index = 1:num_bands;
bands = (bands_index-(num_bands+1)/2).*sb;
carriers = complex(zeros(num_bands, spf));

for i=1:num_bands
    carriers(i, :) = expWave(bands(i), fs, spf);
end

function y = expWave(fc, fs, spf)

sine = dsp.SineWave("Frequency",fc,"SampleRate",fs, ...
    "ComplexOutput",false, "SamplesPerFrame",spf);
cosine = dsp.SineWave("Frequency",fc,"SampleRate",fs, ...
    "ComplexOutput",false, "SamplesPerFrame",spf, ...
    "PhaseOffset", pi/2);

y = complex(cosine(), sine());

end