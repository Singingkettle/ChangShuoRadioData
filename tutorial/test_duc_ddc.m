clc
clear
close all

M = 16;            % Modulator order
k = log2(M);       % Bits per symbol
numBits = k*7.5e4; % Bits to process
sps = 4;           % Samples per symbol (oversampling factor)
filtlen = 10;      % Filter length in symbols
rolloff = 0.25;    % Filter rolloff factor
rrcFilter = rcosdesign(rolloff,filtlen,sps);

rng default;                     % Default random number generator
dataIn = randi([0 1],numBits,1); % Generate vector of binary data
dataSymbolsIn = bit2int(dataIn,k);

dataMod = qammod(dataSymbolsIn,M);
txFiltSignal = upfirdn(dataMod,rrcFilter,sps,1);



Fs = 6e3; % Sample rate

upConv = dsp.DigitalUpConverter(...
    'InterpolationFactor', 20,...
    'SampleRate', Fs,...
    'Bandwidth', 2e3,...
    'StopbandAttenuation', 100,...
    'PassbandRipple',0.1,...
    'CarrierFrequency',50e3);
dwnConv = dsp.DigitalDownConverter(...
    'DecimationFactor',20,...
    'SampleRate', Fs*20,...
    'Bandwidth', 3e3,...
    'StopbandAttenuation', 100,...
    'PassbandRipple',0.1,...
    'CarrierFrequency',50e3);


txSignalWithC = upConv(txFiltSignal); % up convert
rxSignalWithOutC = dwnConv(txSignalWithC); % down convert
a = xcorr(txFiltSignal, rxSignalWithOutC);
[m, i] = max(a)

d = length(txFiltSignal) - i;

% rxSignalWithOutC(1:end-d) = rxSignalWithOutC(d+1:end);
rxSignalWithOutC = circshift(rxSignalWithOutC, -d);

rxFiltSignal = ...
    upfirdn(rxSignalWithOutC,rrcFilter,1,sps);       % Downsample and filter
rxFiltSignal = ...
    rxFiltSignal(filtlen + 1:end - filtlen); % Account for delay

dataSymbolsOut = qamdemod(rxFiltSignal,M);

dataOut = int2bit(dataSymbolsOut,k);

[numErrors,ber] = biterr(dataIn,dataOut);