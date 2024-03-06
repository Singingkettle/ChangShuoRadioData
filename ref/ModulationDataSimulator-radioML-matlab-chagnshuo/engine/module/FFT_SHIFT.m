function [f,sf] = FFT_SHIFT(t,st)
%This function is FFT to calculate a signal's Fourier transform
%Input: t:sampling time , st:signal data. Time length mustgreater thean 2
%output: f:sampling frequency, sf:frequen
%output is the frequency and the signal spectrum
dt = t(2)-t(1);
T = t(end);
df = 1/T;
N = length(t);
f = [-N/2:N/2-1]*df;
sf = fft(st);
sf = T/N*fftshift(sf);