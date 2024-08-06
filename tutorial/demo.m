% Lab 06
% WiCom_2
% By Kashif Shahzad 
% 01-ET-31
% 3rd July 2004
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Frequency Hopping Spread Spectrum
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clc
clear
% Generation of bit pattern
s=round(rand(1,20));    % Generating 20 bits
signal=[];  
carrier=[];
t=[0:10000];   
fc=.01;
for k=1:20
    if s(1,k)==0
        sig=-ones(1,10001);    % 10001 minus ones for bit 0
    else
        sig=ones(1,10001);     % 10001 ones for bit 1
    end
    c=cos(2*pi*fc*t);   
    carrier=[carrier c];
    signal=[signal sig];
end
subplot(2,1,1);
plot(signal);
axis([-1 200050 -1.5 1.5]);
title('\bf\it Original Bit Sequence');
% BPSK Modulator of the signal
bpsk_sig=signal.*carrier;   % Modulating the signal
subplot(2,1,2);
plot(bpsk_sig)
axis([-1 200050 -1.5 1.5]);
title('\bf\it BPSK Modulated Signal');
% FFT Plot of BPSK Modulated Signal
figure,plot([1:200020],abs(fft(bpsk_sig)))
title('\bf\it FFT of BPSK Modulated Signal');
% Preparation of Six carrier frequencies
fc1=.01;
fc2=.02;
fc3=.03;
fc4=.04;
fc5=.05;
fc6=.06;
c1=cos(2*pi*fc1*t);
c2=cos(2*pi*fc2*t);
c3=cos(2*pi*fc3*t);
c4=cos(2*pi*fc4*t);
c5=cos(2*pi*fc5*t);
c6=cos(2*pi*fc6*t);
% Random frequency hopps to form a spread signal
spread_signal=[];
for n=1:20
    c=randi([1 6]);
    switch(c)
        case(1)
            spread_signal=[spread_signal c1];
        case(2)
            spread_signal=[spread_signal c2];
        case(3)
            spread_signal=[spread_signal c3];
        case(4)
            spread_signal=[spread_signal c4];
        case(5)        
            spread_signal=[spread_signal c5];
        case(6)
            spread_signal=[spread_signal c6];
    end
end
figure,plot([1:200020],abs(fft(spread_signal)))
% Transformation of a BPSK signal into a wider band
freq_hopped_sig=bpsk_sig.*spread_signal;
figure,plot([1:200020],abs(fft(freq_hopped_sig)))