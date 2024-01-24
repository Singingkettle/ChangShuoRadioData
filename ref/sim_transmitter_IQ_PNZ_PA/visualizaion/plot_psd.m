function plot_psd(varargin)
%     fig = fig + 1;
%     figure(fig)
%     clf(fig)
figure;
a = varargin{1};
fs = varargin{3};
step = 1/length(a);
if(fs>1e6)
    num_fs = fs/1e6;
    str = "Frequency(MHz)\n (fs= %.2fMHz)";
    str2 = 'PSD(dB/MHz)';
%     caption = sprintf("Frequency(Hz) = \n (fs= %.2fMHz)",fs/1e6);
elseif(fs>=1e3)
    num_fs = fs/1e3;
    str = "Frequency(kHz)\n (fs= %.2fkHz)";
    str2 = 'PSD(dB/kHz)';
elseif(fs<1e3)
    num_fs = fs;
    str = "Frequency(Hz)\n (fs= %.2fHz)";
    str2 = 'PSD(dB/Hz)';
end
x = (-0.5:step:0.5-step).*num_fs';
caption = sprintf(str,num_fs);
W1=fftshift(fft(a));
plot(x,20*log10(abs(W1)/max(abs(W1))));
legend('txSig')
if nargin == 4
    hold on;
    b = varargin{2};
    W2=fftshift(fft(b));
    plot(x,20*log10(abs(W2)/max(abs(W2))));
    legend('txSig','rxSig')
end
xlabel(caption);
ylabel(str2)
title0 = varargin{end};
title(title0)
% lim = 2.5;
% xlim([-lim lim])
% ylim([-lim lim])
end