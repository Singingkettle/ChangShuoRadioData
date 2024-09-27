function modulator = MyModClassGetDeModulator(modType, sps, fs)

switch modType
  case "BPSK"
    modulator = @(x)bpskDeModulator(x,sps);
  case "QPSK"
    modulator = @(x)qpskDeModulator(x,sps);
  case "8PSK"
    modulator = @(x)psk8DeModulator(x,sps);
  case "16QAM"
    modulator = @(x)qam16DeModulator(x,sps);
  case "64QAM"
    modulator = @(x)qam64DeModulator(x,sps);
  case "GFSK"
    modulator = @(x)gfskModulator(x,sps);
  case "CPFSK"
    modulator = @(x)cpfskModulator(x,sps);
  case "PAM4"
    modulator = @(x)pam4Modulator(x,sps);
  case "B-FM"
    modulator = @(x)bfmModulator(x, fs);
  case "DSB-AM"
    modulator = @(x)dsbamModulator(x, fs);
  case "SSB-AM"
    modulator = @(x)ssbamModulator(x, fs);
end
end

function y = bpskDeModulator(x,sps)
rxfilter = comm.RaisedCosineReceiveFilter( ...
    RolloffFactor=0.35, ...
    FilterSpanInSymbols=4, ...
    InputSamplesPerSymbol=sps, ...
    DecimationFactor=sps);
% DeModulate
x = rxfilter(x);
y = pskdemod(x,2);
end

function y = qpskDeModulator(x,sps)
rxfilter = comm.RaisedCosineReceiveFilter( ...
    RolloffFactor=0.35, ...
    FilterSpanInSymbols=4, ...
    InputSamplesPerSymbol=sps, ...
    DecimationFactor=sps);
% DeModulate
x = rxfilter(x);
y = pskdemod(x,4,pi/4);
end

function y = psk8DeModulator(x,sps)
rxfilter = comm.RaisedCosineReceiveFilter( ...
    RolloffFactor=0.35, ...
    FilterSpanInSymbols=4, ...
    InputSamplesPerSymbol=sps, ...
    DecimationFactor=sps);
% DeModulate
x = rxfilter(x);
y = pskdemod(x,8);
end

function y = qam16DeModulator(x,sps)
rxfilter = comm.RaisedCosineReceiveFilter( ...
    RolloffFactor=0.35, ...
    FilterSpanInSymbols=4, ...
    InputSamplesPerSymbol=sps, ...
    DecimationFactor=sps);
% DeModulate
x = rxfilter(x);
y = qamdemod(x,16,'UnitAveragePower',true);
end

function y = qam64DeModulator(x,sps)
rxfilter = comm.RaisedCosineReceiveFilter( ...
    RolloffFactor=0.35, ...
    FilterSpanInSymbols=4, ...
    InputSamplesPerSymbol=sps, ...
    DecimationFactor=sps);
% DeModulate
x = rxfilter(x);
y = qamdemod(x,64,'UnitAveragePower',true);
end

function y = pam4Modulator(x,sps)
%pam4Modulator PAM4 modulator with pulse shaping
%   Y = pam4Modulator(X,SPS) PAM4 modulates the input X, and returns the
%   root-raised cosine pulse shaped signal Y. X must be a column vector
%   of values in the set [0 3]. The root-raised cosine filter has a
%   roll-off factor of 0.35 and spans four symbols. The output signal
%   Y has unit power.

txfilter = comm.RaisedCosineTransmitFilter( ...
    RolloffFactor=0.35, ...
    FilterSpanInSymbols=4, ...
    OutputSamplesPerSymbol=sps);
amp = 1 / sqrt(mean(abs(pammod(0:3, 4)).^2));
% Modulate
syms = amp * pammod(x,4);
% Pulse shape
y = txfilter(syms);
end

function y = gfskModulator(x,sps)
%gfskModulator GFSK modulator
%   Y = gfskModulator(X,SPS) GFSK modulates the input X and returns the
%   signal Y. X must be a column vector of values in the set [0 1]. The
%   BT product is 0.35 and the modulation index is 1. The output signal
%   Y has unit power.


M = 2;
mod = comm.CPMModulator(...
'ModulatorOrder', M, ...
'FrequencyPulse', 'Gaussian', ...
'BandwidthTimeProduct', 0.35, ...
'ModulatorIndex', 1, ...
'SamplesPerSymbol', sps);
meanM = mean(0:M-1);
% Modulate
y = mod(2*(x-meanM));
end

function y = cpfskModulator(x,sps)
%cpfskModulator CPFSK modulator
%   Y = cpfskModulator(X,SPS) CPFSK modulates the input X and returns
%   the signal Y. X must be a column vector of values in the set [0 1].
%   the modulation index is 0.5. The output signal Y has unit power.

M = 2;
mod = comm.CPFSKModulator(...
'ModulatorOrder', M, ...
'ModulatorIndex', 0.5, ...
'SamplesPerSymbol', sps);
meanM = mean(0:M-1);
% Modulate
y = mod(2*(x-meanM));
end

function y = bfmModulator(x,fs)
%bfmModulator Broadcast FM modulator
%   Y = bfmModulator(X,FS) broadcast FM modulates the input X and returns
%   the signal Y at the sample rate FS. X must be a column vector of
%   audio samples at the sample rate FS. The frequency deviation is 75 kHz
%   and the pre-emphasis filter time constant is 75 microseconds.


mod = comm.FMBroadcastModulator(...
'AudioSampleRate', fs, ...
'SampleRate', fs);
y = mod(x);
end

function y = dsbamModulator(x,fs)
%dsbamModulator Double sideband AM modulator
%   Y = dsbamModulator(X,FS) double sideband AM modulates the input X and
%   returns the signal Y at the sample rate FS. X must be a column vector of
%   audio samples at the sample rate FS. The IF frequency is 50 kHz.

y = ammod(x,50e3,fs);
end

function y = ssbamModulator(x,fs)
%ssbamModulator Single sideband AM modulator
%   Y = ssbamModulator(X,FS) single sideband AM modulates the input X and
%   returns the signal Y at the sample rate FS. X must be a column vector of
%   audio samples at the sample rate FS. The IF frequency is 50 kHz.

y = ssbmod(x,50e3,fs);
end