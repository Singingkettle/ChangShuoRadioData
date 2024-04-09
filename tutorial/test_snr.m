%
clc
clear
close all

A = 0;
rolloff = 0.25; % Filter rolloff
span = 4;       % Filter span
sps = 4;        % Samples per symbol
M = 4;          % Size of the signal constellation
k = log2(M);    % Number of bits per symbolM,0);
rrcFilter = rcosdesign(rolloff,span,sps);
for i=1:1000
    data = randi([0 M-1], 640, 1);
    modData = pskmod(data,M,0);
    txSig = upfirdn(modData,rrcFilter,sps);
    EbNo = -2;
    snr = convertSNR(EbNo,'ebno','snr', ...
        SamplesPerSymbol=sps, ...
        BitsPerSymbol=k);
    rxSig = awgn(txSig,snr,'measured');
    set(0,'DefaultFigureVisible','off');
    binscatter(real(rxSig), imag(rxSig), [6, 6], XLimits=[-1, 1], YLimits=[-1, 1], ShowEmptyBins="on");
    set(gca, 'Visible', 'off');
    colorbar('off');
    set(0,'DefaultFigureVisible','on');
    Frame = getframe(gcf);
    A = (double(Frame.cdata)-A)/i + A;
    s = uint8(A);
    imwrite(s, sprintf('figure/%03d.png', i));
end

