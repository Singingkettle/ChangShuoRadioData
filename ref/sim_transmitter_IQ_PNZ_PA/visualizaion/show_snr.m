% ÒÑÓÐsnrº¯Êý
function show_snr(signal, noise)
    SNR = 10*log10(mean(abs(signal.^2))./mean(abs(noise.^2)));%dB
    % SNR2 = 10*log10(power(rms(rxPA),2)/power(rms(noise),2))%dB
    % SNR3 = 10*log10(sum(abs(rxPA).^2)./sum(abs(noise).^2))
    % SNR4 = snr(rxPA,noise)
    disp('SNR is ',SNR);
end