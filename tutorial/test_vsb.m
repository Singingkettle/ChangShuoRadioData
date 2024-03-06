clc
clear
close all

spf = 1024000;             % Samples per frame
fs = 200e3;
x = getAudio(spf,fs);
obw(x, fs);
figure
plot(x);
bw = obw(x, fs);
y = lowpass(x, bw*1.2/2, fs, ImpulseResponse="fir", Steepness=0.99);
AW = dsp.AudioFileWriter('audio_mix_200k.wav', ...
    'SampleRate',fs);
AW(y);

release(AW);
hold on
plot(y);

sadsb = spectrumAnalyzer( ...
    SampleRate=fs, ...
    PlotAsTwoSidedSpectrum=false);
sadsb(x)
x = vsbamModulator(x, fs);

function x = getAudio(spf,fs)
%getAudio Audio source for analog modulation types
%    A = getAudio(SPF,FS) returns the audio source A, with the
%    number of samples per frame SPF, and the sample rate FS.

audioSrc = dsp.AudioFileReader('audio_mix_441.wav',...
'SamplesPerFrame',spf,'PlayCount',inf);
audioRC = dsp.SampleRateConverter('Bandwidth',30e3,...
'InputSampleRate',audioSrc.SampleRate,...
'OutputSampleRate',fs);
[~, decimFactor] = getRateChangeFactors(audioRC);
audioSrc.SamplesPerFrame = ceil(spf / fs * audioSrc.SampleRate / ...
    decimFactor) * decimFactor;

x = audioRC(audioSrc());
x = x(1:spf,1);

end


function y = dsbamModulator(x,fs, is_sc)
%dsbamModulator Double sideband AM modulator
%   Y = dsbamModulator(X,FS) double sideband AM modulates the input X and
%   returns the signal Y at the sample rate FS. X must be a column vector of
%   audio samples at the sample rate FS. The IF frequency is 50 kHz.
%   It is common to set the value of k to the maximum absolute value of the negative part of the input signal u(t).
if is_sc
    y = ammod(x,50e3,fs);
else
    y = ammod(x,50e3,fs, 0, abs(min(x)));
end
end

function y = vsbamModulator(x,fs)
%vsbamModulator Double sideband AM modulator
bw = obw(x, fs);

f = -fs/2:fs/(length(x)-1):fs/2;
f = arrayfun(@(x) vsb_filer(x, 50e3, bw), f);

y = ammod(x,50e3,fs);

fy = fftshift(fft(y));
fy = fy.*f;
y = ifft(ifftshift(fy));

end