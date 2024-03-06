function x = getSymbol(spf, fs)
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

