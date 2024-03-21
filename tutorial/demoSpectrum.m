y = rand(1000, 1);
fs = 100e3;
spectrum = 10*log(abs(fftshift(fft(y))) / length(y));   %compute the FFT
precision = fs/length(y);
f = (-length(y)/2:length(y)/2-1)*(fs/length(y)); % Create the frequency axis and put the measure in the middle of the bin.
plot(f,spectrum);
