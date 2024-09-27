span = 4;      % Filter span in symbols
rolloff = 0.25; % Rolloff factor
sps = 10;
fs = 200e3;                  % Sample rate

filtDelay = 1*span;


txfilter = comm.RaisedCosineTransmitFilter( ...
    RolloffFactor=rolloff, ...
    FilterSpanInSymbols=span, ...
    OutputSamplesPerSymbol=sps);

rxfilter = comm.RaisedCosineReceiveFilter( ...
    RolloffFactor=rolloff, ...
    FilterSpanInSymbols=span, ...
    InputSamplesPerSymbol=sps, ...
    DecimationFactor=sps);

x = randi([0 1],2048,1);
modSig = pskmod(x,2);
% y = pskdemod(modSig, 2,OutputType="bit");

txSig = txfilter(modSig);

bw = obw(txSig, fs);


y_ = lowpass(txSig, bw/2, fs, ImpulseResponse="fir", Steepness=0.99);
tmp = fft(y_);
left = floor(bw/fs*length(txSig)/2 + 1);
right = floor(length(txSig) - bw/fs*length(txSig)/2 - 1);
tmp(left:right) = 0;
tmp = ifft(tmp);

rxSig = rxfilter(txSig);
y = pskdemod(rxSig, 2);

errorRate = comm.ErrorRate(ReceiveDelay=filtDelay);
errStat = errorRate(x,y);
fprintf('\nBER = %5.2e\nBit Errors = %d\nBits Transmitted = %d\n',...
    errStat)

rxSig = rxfilter(y_);
y = pskdemod(rxSig, 2);

errorRate = comm.ErrorRate(ReceiveDelay=filtDelay);
errStat = errorRate(x,y);
fprintf('\nBER = %5.2e\nBit Errors = %d\nBits Transmitted = %d\n',...
    errStat)

rxSig = rxfilter(tmp);
y = pskdemod(rxSig, 2);
errorRate = comm.ErrorRate(ReceiveDelay=filtDelay);
errStat = errorRate(x,y);
fprintf('\nBER = %5.2e\nBit Errors = %d\nBits Transmitted = %d\n',...
    errStat)

SNR = 10;
spses = [4, 8, 16, 32];      % Set of samples per symbol
spf = 4096;                  % Samples per frame
fs = 200e3;                  % Sample rate
modulationTypes = categorical(["BPSK", "QPSK", "8PSK", ...
  "16QAM", "64QAM"]);
addpath('C:\Users\97147\Documents\MATLAB\Examples\R2023a\deeplearning_shared\ModulatorClassificationWithDeepLearningExample');


for i=1:length(modulationTypes)
    for j=1:length(spses)
        errorRate = comm.ErrorRate(ReceiveDelay=4);
        src = helperModClassGetSource(modulationTypes(i), spses(j), 2*spf, fs);
        modulator = MyModClassGetModulator(modulationTypes(i), spses(j), fs);
        x = src();
        y = modulator(x);
        bw = obw(y, fs);
        y_ = lowpass(y, bw/2, fs, ImpulseResponse="fir", Steepness=0.99);
        tmp = fft(y_);
        left = floor(bw/fs*length(y)/2 + 1);
        right = floor(length(y) - bw/fs*length(y)/2 - 1);
        tmp(left:right) = 0;
        tmp = ifft(tmp);
        demodulator = MyModClassGetDeModulator(modulationTypes(i), spses(j), fs);
        x_ = demodulator(y);

        errStat = errorRate(x,x_);
        fprintf('\nBER = %5.2e\nBit Errors = %d\nBits Transmitted = %d\n',...
            errStat)
        
        errStat = errorRate(x,y_);
        fprintf('\nBER = %5.2e\nBit Errors = %d\nBits Transmitted = %d\n',...
            errStat)
        
        errStat = errorRate(x,tmp);
        fprintf('\nBER = %5.2e\nBit Errors = %d\nBits Transmitted = %d\n',...
            errStat)
    end
end
