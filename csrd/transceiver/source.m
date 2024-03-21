function src = source(modulation, sps, spf, fs)

    switch modulation
            case {"OOK", "BPSK", "DBPSK", "CPFSK", ...
                      "2PAM", "2ASK", "MSK", "GMSK", "GFSK", "2FSK"}
            M = 2;
            src = @()randi([0 M - 1], spf / sps, 1);
        case {"QPSK", "OQPSK", "DQPSK", "Pi/4-DQPSK", "4PAM", "4ASK"}
            M = 4;
            src = @()randi([0 M - 1], spf / sps, 1);
        case {"8PSK", "8PAM", "8ASK"}
            M = 8;
            src = @()randi([0 M - 1], spf / sps, 1);
        case {"16PSK", "16PAM", "16ASK", "16QAM"}
            M = 16;
            src = @()randi([0 M - 1], spf / sps, 1);
        case {"32PSK", "32PAM", "32ASK", "32QAM"}
            M = 32;
            src = @()randi([0 M - 1], spf / sps, 1);
        case {"64PSK", "64PAM", "64ASK", "64QAM"}
            M = 64;
            src = @()randi([0 M - 1], spf / sps, 1);
        case {"128PSK", "128ASK", "128QAM"}
            M = 128;
            src = @()randi([0 M - 1], spf / sps, 1);
            case {"FM", "PM", "DSB-AM", "DSB-SC-AM", "VSB-AM", ...
                      "SSB-SC-Upper-AM", "SSB-SC-Lower-AM", ...
                      "SSB-Uper-AM", "SSB-Lower-AM"}
            src = @()getAudio(spf, fs);
    end

end

function x = getAudio(spf, fs)
    %getAudio Audio source for analog modulation types
    %    A = getAudio(SPF,FS) returns the audio source A, with the
    %    number of samples per frame SPF, and the sample rate FS.

    audioSrc = dsp.AudioFileReader('audio_mix_441.wav', ...
        'SamplesPerFrame', spf, 'PlayCount', inf);
    audioRC = dsp.SampleRateConverter('Bandwidth', 30e3, ...
        'InputSampleRate', audioSrc.SampleRate, ...
        'OutputSampleRate', fs);
    [~, decimFactor] = getRateChangeFactors(audioRC);
    audioSrc.SamplesPerFrame = ceil(spf / fs * audioSrc.SampleRate / ...
        decimFactor) * decimFactor;

    x = audioRC(audioSrc());
    x = x(1:spf, 1);

end
