% 模拟调制
% clc
% clear
% 
% fs = 100;
% t = (0:1/fs:100)';
% fc = 10; 
% x = sin(2*pi*t);
% singlescY = ssbmod(x,fc,fs);
% t = (0:1/fs:((size(x,1)-1)/fs))';
% t = t(:, ones(1, size(x, 2)));
% singleY = abs(min(x)) .* cos(2 * pi * fc * t + 0) + singlescY;
% 
% sadsb = spectrumAnalyzer( ...
%     SampleRate=fs, ...
%     PlotAsTwoSidedSpectrum=true, ...
%     YLimits=[-60 30]);
% sadsb(singlescY)
% 
% 
% plot(singlescY)
% hold on
% plot(singleY)

fs = 100;
t = (0:1/fs:100)';
fc = 10; 
x = sin(2*pi*t);
singlescY = ammod(x,fc,fs);

n = -fs/2:fs/10000:fs/2;

S = fft(singlescY);
L = length(singlescY);
P2 = abs(S/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);
f = fs*(0:(L/2))/L;
plot(f,10.*log(P1));

singleY = ammod(x, fc, fs, 0, 1);

sadsb = spectrumAnalyzer( ...
    SampleRate=fs, ...
    PlotAsTwoSidedSpectrum=false, ...
    YLimits=[-60 30]);
sadsb(singlescY, singleY)

plot(singlescY)
hold on
plot(singleY)

function h = vsb_filter(x, fc, fs)
t = (0:1/fs:((size(x,1)-1)/fs))';

end


