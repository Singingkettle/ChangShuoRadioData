function modulator = MyModClassGetDeModulation(modType, sps, fs)

switch modType
  case "BPSK"
    modulator = @(x)bpskDeModulation(x,sps);
  case "QPSK"
    modulator = @(x)qpskDeModulation(x,sps);
  case "8PSK"
    modulator = @(x)psk8DeModulation(x,sps);
  case "16QAM"
    modulator = @(x)qam16DeModulation(x,sps);
  case "64QAM"
    modulator = @(x)qam64DeModulation(x,sps);
  case "GFSK"
    modulator = @(x)gfskModulation(x,sps);
  case "CPFSK"
    modulator = @(x)cpfskModulation(x,sps);
  case "PAM4"
    modulator = @(x)pam4Modulation(x,sps);
  case "B-FM"
    modulator = @(x)bfmModulation(x, fs);
  case "DSB-AM"
    modulator = @(x)dsbamModulation(x, fs);
  case "SSB-AM"
    modulator = @(x)ssbamModulation(x, fs);
end
end

function y = bpskDeModulation(x,sps)
rxfilter = comm.RaisedCosineReceiveFilter( ...
    RolloffFactor=0.35, ...
    FilterSpanInSymbols=4, ...
    InputSamplesPerSymbol=sps, ...
    DecimationFactor=sps);
% DeModulate
x = rxfilter(x);
y = pskdemod(x,2);
end

function y = qpskDeModulation(x,sps)
rxfilter = comm.RaisedCosineReceiveFilter( ...
    RolloffFactor=0.35, ...
    FilterSpanInSymbols=4, ...
    InputSamplesPerSymbol=sps, ...
    DecimationFactor=sps);
% DeModulate
x = rxfilter(x);
y = pskdemod(x,4,pi/4);
end

function y = psk8DeModulation(x,sps)
rxfilter = comm.RaisedCosineReceiveFilter( ...
    RolloffFactor=0.35, ...
    FilterSpanInSymbols=4, ...
    InputSamplesPerSymbol=sps, ...
    DecimationFactor=sps);
% DeModulate
x = rxfilter(x);
y = pskdemod(x,8);
end

function y = qam16DeModulation(x,sps)
rxfilter = comm.RaisedCosineReceiveFilter( ...
    RolloffFactor=0.35, ...
    FilterSpanInSymbols=4, ...
    InputSamplesPerSymbol=sps, ...
    DecimationFactor=sps);
% DeModulate
x = rxfilter(x);
y = qamdemod(x,16,'UnitAveragePower',true);
end

function y = qam64DeModulation(x,sps)
rxfilter = comm.RaisedCosineReceiveFilter( ...
    RolloffFactor=0.35, ...
    FilterSpanInSymbols=4, ...
    InputSamplesPerSymbol=sps, ...
    DecimationFactor=sps);
% DeModulate
x = rxfilter(x);
y = qamdemod(x,64,'UnitAveragePower',true);
end

function y = pam4Modulation(x,sps)
%pam4Modulation PAM4 modulator with pulse shaping
%   Y = pam4Modulation(X,SPS) PAM4 modulates the input X, and returns the
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

function y = gfskModulation(x,sps)
%gfskModulation GFSK modulator
%   Y = gfskModulation(X,SPS) GFSK modulates the input X and returns the
%   signal Y. X must be a column vector of values in the set [0 1]. The
%   BT product is 0.35 and the modulation index is 1. The output signal
%   Y has unit power.


M = 2;
mod = comm.CPMModulation(...
'ModulationOrder', M, ...
'FrequencyPulse', 'Gaussian', ...
'BandwidthTimeProduct', 0.35, ...
'ModulationIndex', 1, ...
'SamplesPerSymbol', sps);
meanM = mean(0:M-1);
% Modulate
y = mod(2*(x-meanM));
end

function y = cpfskModulation(x,sps)
%cpfskModulation CPFSK modulator
%   Y = cpfskModulation(X,SPS) CPFSK modulates the input X and returns
%   the signal Y. X must be a column vector of values in the set [0 1].
%   the modulation index is 0.5. The output signal Y has unit power.

M = 2;
mod = comm.CPFSKModulation(...
'ModulationOrder', M, ...
'ModulationIndex', 0.5, ...
'SamplesPerSymbol', sps);
meanM = mean(0:M-1);
% Modulate
y = mod(2*(x-meanM));
end

function y = bfmModulation(x,fs)
%bfmModulation Broadcast FM modulator
%   Y = bfmModulation(X,FS) broadcast FM modulates the input X and returns
%   the signal Y at the sample rate FS. X must be a column vector of
%   audio samples at the sample rate FS. The frequency deviation is 75 kHz
%   and the pre-emphasis filter time constant is 75 microseconds.


mod = comm.FMBroadcastModulation(...
'AudioSampleRate', fs, ...
'SampleRate', fs);
y = mod(x);
end

function y = dsbamModulation(x,fs)
%dsbamModulation Double sideband AM modulator
%   Y = dsbamModulation(X,FS) double sideband AM modulates the input X and
%   returns the signal Y at the sample rate FS. X must be a column vector of
%   audio samples at the sample rate FS. The IF frequency is 50 kHz.

y = ammod(x,50e3,fs);
end

function y = ssbamModulation(x,fs)
%ssbamModulation Single sideband AM modulator
%   Y = ssbamModulation(X,FS) single sideband AM modulates the input X and
%   returns the signal Y at the sample rate FS. X must be a column vector of
%   audio samples at the sample rate FS. The IF frequency is 50 kHz.

y = ssbmod(x,50e3,fs);
end