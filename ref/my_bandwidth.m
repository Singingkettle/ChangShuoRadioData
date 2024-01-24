clc 
clear 
close all

% 参考https://dsp.stackexchange.com/questions/61340/how-to-generate-random-data-with-a-specific-bandwidth
span = 20;      % Filter span in symbols
rolloff = 0.35; % Rolloff factor
sps = 10;
Rs = 50e3;
Ts = 1/Rs;
fs = 200e3;     % Sample rate

b = randi([0,1],10000,1); % generate bits
a_ = 2*b-1;  % generate pulse amplitudes
a = pskmod(b,4,pi/4);
p = rcosdesign(rolloff, 20, Ts*fs); % raised cosine pulse with 4 sps and 0.35 EBW
% Now we upsample the amplitudes by a factor fs.
a_up = upsample(a,fs*Ts);
% The transmitted signal is the convolution of a_up with p
s = conv(p,a_up);
% Let's see the spectrum of s:
S = fft(s);
L = length(s);
P2 = abs(S/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);
f = fs*(0:(L/2))/L;
plot(f,10.*log(P1));
% Plot a line at the bandwidth
bw = (1+rolloff)*Rs/2;
hold on; plot([bw, bw], [-200,0],'r'); hold off;
figure
obw(s, fs)

